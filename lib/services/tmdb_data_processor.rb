# frozen_string_literal: true

require "date"

# Data processing utilities for TMDB API responses
class TMDBDataProcessor
  def self.process_actor_search_results(data)
    return [] unless data&.dig("results")

    data["results"].map { |actor| normalize_actor(actor) }
  end

  def self.process_movie_credits(data)
    return [] unless data&.dig("cast")

    movies = data["cast"].map { |movie| normalize_movie(movie) }
    movies.reject { |movie| movie[:release_date].nil? }
          .sort_by { |movie| movie[:release_date] }
          .reverse
  end

  def self.normalize_actor_profile(actor_data)
    return {} unless actor_data

    {
      id: actor_data["id"],
      name: actor_data["name"],
      biography: actor_data["biography"],
      birthday: actor_data["birthday"],
      place_of_birth: actor_data["place_of_birth"],
      profile_path: actor_data["profile_path"]
    }
  end

  def self.normalize_actor(actor)
    {
      id: actor["id"],
      name: actor["name"],
      popularity: actor["popularity"],
      profile_path: actor["profile_path"],
      known_for_department: actor["known_for_department"],
      known_for: extract_known_for(actor["known_for"])
    }
  end

  def self.normalize_movie(movie)
    release_date = parse_release_date(movie["release_date"])
    {
      id: movie["id"],
      title: movie["title"],
      character: movie["character"],
      release_date: release_date,
      year: release_date&.year,
      poster_path: movie["poster_path"]
    }
  end

  def self.extract_known_for(known_for_data)
    return [] unless known_for_data

    known_for_data.map { |item| { title: item["title"] || item["name"] } }
  end

  def self.parse_release_date(date_string)
    return nil if date_string.nil? || date_string.empty?

    Date.parse(date_string)
  rescue Date::Error
    nil
  end

  private_class_method :normalize_actor, :normalize_movie, :extract_known_for, :parse_release_date
end
