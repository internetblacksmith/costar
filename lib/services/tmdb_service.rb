# frozen_string_literal: true

require "net/http"
require "json"
require "date"

# Service for interacting with The Movie Database API
class TMDBService
  BASE_URL = "https://api.themoviedb.org/3"

  def initialize(api_key = nil)
    @api_key = api_key || Configuration.instance.tmdb_api_key
  end

  def search_actors(query)
    return [] if query.nil? || query.empty?

    cache_key = "search_actors_#{query}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    data = tmdb_request("search/person", query: query)
    actors = process_actor_search_results(data)
    
    Cache.set(cache_key, actors, 300) # 5 minute cache
    actors
  rescue TMDBError => e
    puts "TMDB Error: #{e.message}" if Configuration.instance.development?
    []
  end

  def get_actor_movies(actor_id)
    cache_key = "actor_movies_#{actor_id}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    data = tmdb_request("person/#{actor_id}/movie_credits")
    movies = process_movie_credits(data)
    
    Cache.set(cache_key, movies, 1800) # 30 minute cache
    movies
  rescue TMDBError => e
    puts "TMDB Error: #{e.message}" if Configuration.instance.development?
    []
  end

  def get_actor_profile(actor_id)
    cache_key = "actor_profile_#{actor_id}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    data = tmdb_request("person/#{actor_id}")
    profile = normalize_actor_profile(data)
    
    Cache.set(cache_key, profile, 3600) # 1 hour cache
    profile
  rescue TMDBError => e
    puts "TMDB Error: #{e.message}" if Configuration.instance.development?
    { profile_path: nil }
  end

  private

  def tmdb_request(endpoint, params = {})
    uri = URI("#{BASE_URL}/#{endpoint}")
    uri.query = URI.encode_www_form({ api_key: @api_key }.merge(params))

    response = Net::HTTP.get_response(uri)

    case response.code
    when "200"
      JSON.parse(response.body)
    when "401"
      raise TMDBError.new(401, "Invalid API key")
    when "404"
      raise TMDBError.new(404, "Resource not found")
    else
      raise TMDBError.new(response.code.to_i, "TMDB API error: #{response.code}")
    end
  end

  def process_actor_search_results(data)
    data["results"]
      .select { |person| person["known_for_department"] == "Acting" }
      .first(5)
      .map { |actor| normalize_actor(actor) }
  end

  def normalize_actor(actor)
    {
      id: actor["id"],
      name: actor["name"],
      profile_path: actor["profile_path"],
      known_for: extract_known_for(actor["known_for"])
    }
  end

  def extract_known_for(known_for_data)
    return [] unless known_for_data

    known_for_data
      .map { |work| work["title"] || work["name"] }
      .compact
      .take(3)
  end

  def process_movie_credits(data)
    data["cast"]
      .reject { |movie| movie["release_date"].nil? || movie["release_date"].empty? }
      .map { |movie| normalize_movie(movie) }
      .select { |movie| movie[:year] && movie[:year] >= 1900 }
      .sort_by { |movie| movie[:release_date] || "0000-00-00" }
      .reverse
  end

  def normalize_movie(movie)
    {
      id: movie["id"],
      title: movie["title"],
      character: movie["character"],
      release_date: movie["release_date"],
      year: movie["release_date"] ? Date.parse(movie["release_date"]).year : nil,
      poster_path: movie["poster_path"]
    }
  end

  def normalize_actor_profile(actor_data)
    {
      id: actor_data["id"],
      name: actor_data["name"],
      profile_path: actor_data["profile_path"],
      biography: actor_data["biography"],
      birthday: actor_data["birthday"],
      place_of_birth: actor_data["place_of_birth"],
      known_for_department: actor_data["known_for_department"]
    }
  end
end