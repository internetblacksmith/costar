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
    start_time = Time.now
    
    cached_result = Cache.get(cache_key)
    if cached_result
      StructuredLogger.log_cache_operation("hit", cache_key, hit: true, duration_ms: (Time.now - start_time) * 1000)
      return cached_result
    end

    api_start_time = Time.now
    data = @client.request("search/person", query: query)
    api_duration = (Time.now - api_start_time) * 1000
    
    actors = TMDBDataProcessor.process_actor_search_results(data)

    Cache.set(cache_key, actors, 300) # 5 minute cache
    StructuredLogger.log_cache_operation("miss", cache_key, hit: false, duration_ms: (Time.now - start_time) * 1000)
    StructuredLogger.log_api_call("tmdb", "search/person", api_duration, success: true)
    
    actors
  rescue TMDBError => e
    api_duration = (Time.now - api_start_time) * 1000 if defined?(api_start_time)
    StructuredLogger.log_api_call("tmdb", "search/person", api_duration || 0, success: false, error: e)
    StructuredLogger.error("TMDB API Error", service: "tmdb", endpoint: "search/person", error: e.message)
    []
  end

  def get_actor_movies(actor_id)
    cache_key = "actor_movies_#{actor_id}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    data = @client.request("person/#{actor_id}/movie_credits")
    movies = TMDBDataProcessor.process_movie_credits(data)

    Cache.set(cache_key, movies, 600) # 10 minute cache
    movies
  rescue TMDBError => e
    puts "TMDB Error: #{e.message}" if Configuration.instance.development?
    []
  end

  def get_actor_profile(actor_id)
    cache_key = "actor_profile_#{actor_id}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    data = @client.request("person/#{actor_id}")
    profile = TMDBDataProcessor.normalize_actor_profile(data)

    Cache.set(cache_key, profile, 600) # 10 minute cache
    profile
  rescue TMDBError => e
    puts "TMDB Error: #{e.message}" if Configuration.instance.development?
    default_actor_profile(actor_id)
  end

  private

  def default_actor_profile(actor_id)
    {
      id: actor_id.to_i,
      name: "Unknown Actor",
      biography: "",
      profile_path: nil
    }
  end
end
