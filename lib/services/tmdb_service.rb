# frozen_string_literal: true

require_relative "resilient_tmdb_client"
require_relative "tmdb_data_processor"
require_relative "cache_manager"
require_relative "../config/logger"
require_relative "../middleware/error_handler_module"

# High-level service for interacting with The Movie Database API
class TMDBService
  include ErrorHandlerModule
  def initialize(api_key = nil)
    @client = ResilientTMDBClient.new(api_key)
    @cache_manager = CacheManager.new
  end

  def healthy?
    @client.healthy?
  end

  def circuit_breaker_status
    @client.circuit_breaker_status
  end

  def search_actors(query)
    return [] if query.nil? || query.empty?

    @cache_manager.cache_search_results(query) do
      fetch_actors_from_api(query)
    end
  end

  def get_actor_movies(actor_id)
    @cache_manager.cache_actor_movies(actor_id) do
      fetch_movies_from_api(actor_id)
    end
  end

  def get_actor_profile(actor_id)
    @cache_manager.cache_actor_profile(actor_id) do
      fetch_profile_from_api(actor_id)
    end
  end

  def get_actor_details(actor_id)
    # Actor details is the same as profile, so reuse the profile cache
    get_actor_profile(actor_id)
  end

  private

  def fetch_actors_from_api(query)
    with_tmdb_error_handling("search_actors", context: { query: query }) do
      api_start_time = Time.now

      data = @client.request("search/person", query: query)
      api_duration = (Time.now - api_start_time) * 1000

      actors = TMDBDataProcessor.process_actor_search_results(data)
      log_api_call("search/person", api_duration)

      actors
    end
  rescue TMDBError => e
    handle_service_error(e, "search_actors")
    []
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
      data = @client.request(endpoint)
      api_duration = (Time.now - api_start_time) * 1000

      movies = TMDBDataProcessor.process_movie_credits(data)
      log_api_call(endpoint, api_duration)

      movies
    end
  rescue TMDBError => e
    handle_service_error(e, "get_actor_movies")
    []
  end

  def fetch_profile_from_api(actor_id)
    with_tmdb_error_handling("get_actor_profile", context: { actor_id: actor_id }) do
      api_start_time = Time.now

      endpoint = "person/#{actor_id}"
      data = @client.request(endpoint)
      api_duration = (Time.now - api_start_time) * 1000

      profile = TMDBDataProcessor.normalize_actor_profile(data)
      log_api_call(endpoint, api_duration)

      profile
    end
  rescue TMDBError => e
    handle_service_error(e, "get_actor_profile")
    default_actor_profile(actor_id)
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
