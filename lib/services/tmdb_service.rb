# frozen_string_literal: true

require_relative "tmdb_client"
require_relative "tmdb_data_processor"
require_relative "../config/logger"

# High-level service for interacting with The Movie Database API
class TMDBService
  def initialize(api_key = nil)
    @client = TMDBClient.new(api_key)
  end

  def search_actors(query)
    return [] if query.nil? || query.empty?

    cache_key = "search_actors_#{query}"
    cached_result = get_cached_result(cache_key)
    return cached_result if cached_result

    fetch_and_cache_actors(query, cache_key)
  end

  def get_actor_movies(actor_id)
    cache_key = "actor_movies_#{actor_id}"
    cached_result = get_cached_result(cache_key)
    return cached_result if cached_result

    fetch_and_cache_movies(actor_id, cache_key)
  end

  def get_actor_profile(actor_id)
    cache_key = "actor_profile_#{actor_id}"
    cached_result = get_cached_result(cache_key)
    return cached_result if cached_result

    fetch_and_cache_profile(actor_id, cache_key)
  end

  private

  def get_cached_result(cache_key)
    start_time = Time.now
    cached_result = Cache.get(cache_key)

    if cached_result
      duration_ms = (Time.now - start_time) * 1000
      StructuredLogger.log_cache_operation("hit", cache_key, hit: true, duration_ms: duration_ms)
      return cached_result
    end

    nil
  end

  def fetch_and_cache_actors(query, cache_key)
    start_time = Time.now
    api_start_time = Time.now

    data = @client.request("search/person", query: query)
    api_duration = (Time.now - api_start_time) * 1000

    actors = TMDBDataProcessor.process_actor_search_results(data)

    Cache.set(cache_key, actors, 300) # 5 minute cache
    log_cache_miss_and_api_success(cache_key, start_time, "search/person", api_duration)

    actors
  rescue TMDBError => e
    handle_tmdb_error(e, "search/person", api_start_time)
    []
  end

  def handle_tmdb_error(error, endpoint, api_start_time)
    api_duration = defined?(api_start_time) ? (Time.now - api_start_time) * 1000 : 0
    StructuredLogger.log_api_call("tmdb", endpoint, api_duration, success: false, error: error)
    StructuredLogger.error("TMDB API Error", service: "tmdb", endpoint: endpoint, error: error.message)
  end

  def fetch_and_cache_movies(actor_id, cache_key)
    start_time = Time.now
    api_start_time = Time.now

    endpoint = "person/#{actor_id}/movie_credits"
    data = @client.request(endpoint)
    api_duration = (Time.now - api_start_time) * 1000
    movies = TMDBDataProcessor.process_movie_credits(data)

    Cache.set(cache_key, movies, 600) # 10 minute cache
    log_cache_miss_and_api_success(cache_key, start_time, endpoint, api_duration)
    movies
  rescue TMDBError => e
    handle_tmdb_error(e, endpoint, api_start_time)
    []
  end

  def fetch_and_cache_profile(actor_id, cache_key)
    start_time = Time.now
    api_start_time = Time.now

    endpoint = "person/#{actor_id}"
    data = @client.request(endpoint)
    api_duration = (Time.now - api_start_time) * 1000
    profile = TMDBDataProcessor.normalize_actor_profile(data)

    Cache.set(cache_key, profile, 600) # 10 minute cache
    log_cache_miss_and_api_success(cache_key, start_time, endpoint, api_duration)
    profile
  rescue TMDBError => e
    handle_tmdb_error(e, endpoint, api_start_time)
    default_actor_profile(actor_id)
  end

  def log_cache_miss_and_api_success(cache_key, start_time, endpoint, api_duration)
    total_duration = (Time.now - start_time) * 1000
    StructuredLogger.log_cache_operation("miss", cache_key, hit: false, duration_ms: total_duration)
    StructuredLogger.log_api_call("tmdb", endpoint, api_duration, success: true)
  end

  def default_actor_profile(actor_id)
    {
      id: actor_id.to_i,
      name: "Unknown Actor",
      biography: "",
      profile_path: nil
    }
  end
end
