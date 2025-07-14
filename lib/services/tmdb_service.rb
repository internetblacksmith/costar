# frozen_string_literal: true

require_relative "resilient_tmdb_client"
require_relative "tmdb_data_processor"
require_relative "cache_manager"
require_relative "request_throttler"
require_relative "../config/logger"
require_relative "../middleware/error_handler_module"
require_relative "../dto/dto_factory"
require_relative "../dto/search_results_dto"

# High-level service for interacting with The Movie Database API
class TMDBService
  include ErrorHandlerModule
  def initialize(client: nil, cache: nil, throttler: nil)
    @client = client || ResilientTMDBClient.new
    @cache_manager = cache || CacheManager.new
    @throttler = throttler || RequestThrottler.new
  end

  def healthy?
    @client.healthy?
  end

  def circuit_breaker_status
    @client.circuit_breaker_status
  end

  def throttler_status
    @throttler.status
  end

  def search_actors(query)
    return SearchResultsDTO.new(actors: []) if query.nil? || query.empty?

    cached_data = @cache_manager.cache_search_results(query) do
      fetch_actors_from_api(query)
    end

    # Convert to DTO if not already
    return cached_data if cached_data.is_a?(SearchResultsDTO)

    DTOFactory.search_results_from_api(cached_data)
  end

  def get_actor_movies(actor_id)
    cached_data = @cache_manager.cache_actor_movies(actor_id) do
      fetch_movies_from_api(actor_id)
    end

    # Convert array of movie hashes to MovieDTOs
    return cached_data if cached_data.is_a?(Array) && cached_data.first.is_a?(MovieDTO)

    (cached_data || []).map { |movie_data| DTOFactory.movie_from_api(movie_data) }.compact
  end

  def get_actor_profile(actor_id)
    cached_data = @cache_manager.cache_actor_profile(actor_id) do
      fetch_profile_from_api(actor_id)
    end

    # Convert to ActorDTO
    return cached_data if cached_data.is_a?(ActorDTO)

    DTOFactory.actor_from_api(cached_data)
  end

  def get_actor_details(actor_id)
    # Actor details is the same as profile, so reuse the profile cache
    get_actor_profile(actor_id)
  end

  private

  def fetch_actors_from_api(query)
    with_tmdb_error_handling("search_actors", context: { query: query }) do
      api_start_time = Time.now

      # High priority for user-initiated searches
      data = @throttler.throttle_high_priority do
        @client.request("search/person", query: query)
      end
      api_duration = (Time.now - api_start_time) * 1000

      log_api_call("search/person", api_duration)

      # Return raw API response for DTO conversion
      data
    end
  rescue TMDBError => e
    handle_service_error(e, "search_actors")
    { "results" => [] }
  end

  def handle_service_error(error, method_name)
    StructuredLogger.error("TMDBService Error",
                           type: "service_error",
                           service: "tmdb",
                           method: method_name,
                           error: error.message,
                           error_class: error.class.name,
                           circuit_breaker_status: circuit_breaker_status)

    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def fetch_movies_from_api(actor_id)
    with_tmdb_error_handling("get_actor_movies", context: { actor_id: actor_id }) do
      api_start_time = Time.now

      endpoint = "person/#{actor_id}/movie_credits"
      # Low priority for movie credits
      data = @throttler.throttle_low_priority do
        @client.request(endpoint)
      end
      api_duration = (Time.now - api_start_time) * 1000

      log_api_call(endpoint, api_duration)

      # Process and return movie data
      TMDBDataProcessor.process_movie_credits(data)
    end
  rescue TMDBError => e
    handle_service_error(e, "get_actor_movies")
    []
  end

  def fetch_profile_from_api(actor_id)
    with_tmdb_error_handling("get_actor_profile", context: { actor_id: actor_id }) do
      api_start_time = Time.now

      endpoint = "person/#{actor_id}"
      # Medium priority for actor profiles
      data = @throttler.throttle_medium_priority do
        @client.request(endpoint)
      end
      api_duration = (Time.now - api_start_time) * 1000

      log_api_call(endpoint, api_duration)

      # Return raw API response for DTO conversion
      data
    end
  rescue TMDBError => e
    handle_service_error(e, "get_actor_profile")
    nil
  end

  def default_actor_profile(actor_id)
    {
      id: actor_id.to_i,
      name: "Unknown Actor",
      biography: "",
      profile_path: nil
    }
  end

  def log_api_call(endpoint, duration)
    StructuredLogger.log_api_call("tmdb", endpoint, duration, success: true)
  end
end
