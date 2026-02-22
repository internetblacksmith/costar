# frozen_string_literal: true

require_relative "cache_manager"
require_relative "../middleware/error_handler_module"
require_relative "../dto/dto_factory"
require_relative "../dto/movie_comparison_result_dto"

# Service for comparing movies and finding shared actors
class MovieComparisonService
  include ErrorHandlerModule

  def initialize(tmdb_service: nil, cache: nil)
    @tmdb_service = tmdb_service || TMDBService.new
    @cache_manager = cache || CacheManager.new
  end

  def compare(movie1_id, movie2_id, movie1_title, movie2_title)
    validate_movie_ids(movie1_id, movie2_id)

    # Cache the entire comparison result to avoid redundant processing
    cached_data = @cache_manager.cache_movie_comparison(movie1_id, movie2_id) do
      perform_comparison(movie1_id, movie2_id, movie1_title, movie2_title)
    end

    # Convert to DTO if not already
    return cached_data if cached_data.is_a?(MovieComparisonResultDTO)

    DTOFactory.movie_comparison_result_from_service(cached_data)
  end

  private

  def perform_comparison(movie1_id, movie2_id, movie1_title, movie2_title)
    # Fetch movie casts
    cast_data = fetch_movie_casts(movie1_id, movie2_id)

    # Get movie details
    movie_data = fetch_movie_details(movie1_id, movie2_id, movie1_title, movie2_title)

    # Find shared actors
    shared_actors = find_shared_actors(cast_data[:movie1], cast_data[:movie2])

    build_comparison_result(movie_data, cast_data, shared_actors)
  end

  def validate_movie_ids(movie1_id, movie2_id)
    raise ValidationError, "Movie IDs cannot be nil" if movie1_id.nil? || movie2_id.nil?
  end

  def fetch_movie_casts(movie1_id, movie2_id)
    {
      movie1: @tmdb_service.get_movie_cast(movie1_id),
      movie2: @tmdb_service.get_movie_cast(movie2_id)
    }
  end

  def fetch_movie_details(movie1_id, movie2_id, provided_title1, provided_title2)
    movie1_details = fetch_movie_details_with_fallback(movie1_id, provided_title1)
    movie2_details = fetch_movie_details_with_fallback(movie2_id, provided_title2)

    {
      movie1: movie1_details,
      movie2: movie2_details
    }
  end

  def fetch_movie_details_with_fallback(movie_id, provided_title)
    details = @tmdb_service.get_movie_details(movie_id)

    if details
      {
        id: details.id,
        title: details.title || provided_title,
        poster_path: details.poster_path,
        release_date: details.release_date,
        year: details.year
      }
    else
      {
        id: movie_id,
        title: provided_title || "Unknown Movie",
        poster_path: nil,
        release_date: nil,
        year: nil
      }
    end
  rescue TMDBError => e
    handle_tmdb_error(e, "getting movie details")
    {
      id: movie_id,
      title: provided_title || "Unknown Movie",
      poster_path: nil,
      release_date: nil,
      year: nil
    }
  end

  def find_shared_actors(movie1_cast, movie2_cast)
    return [] if movie1_cast.empty? || movie2_cast.empty?

    # Create a map of actor IDs from the first movie
    movie1_actor_ids = movie1_cast.each_with_object({}) do |actor, hash|
      actor_id = actor.respond_to?(:id) ? actor.id : actor[:id] || actor["id"]
      hash[actor_id] = actor
    end

    # Find actors that appear in both movies
    shared = []
    movie2_cast.each do |actor|
      actor_id = actor.respond_to?(:id) ? actor.id : actor[:id] || actor["id"]
      next unless movie1_actor_ids.key?(actor_id)

      # Merge character info from both movies
      movie1_actor = movie1_actor_ids[actor_id]
      shared << build_shared_actor_data(movie1_actor, actor)
    end

    # Sort by prominence (most popular actors first)
    shared.sort_by { |actor| -(actor[:popularity] || 0.0) }
  end

  def build_shared_actor_data(movie1_actor, movie2_actor)
    {
      id: extract_actor_field(movie1_actor, :id),
      name: extract_actor_field(movie1_actor, :name),
      profile_path: extract_actor_field(movie1_actor, :profile_path),
      popularity: extract_actor_field(movie1_actor, :popularity) || 0.0,
      character_in_movie1: extract_actor_field(movie1_actor, :character),
      character_in_movie2: extract_actor_field(movie2_actor, :character)
    }
  end

  def extract_actor_field(actor, field)
    if actor.respond_to?(field)
      actor.send(field)
    elsif actor.is_a?(Hash)
      actor[field] || actor[field.to_s]
    end
  end

  def build_comparison_result(movie_data, cast_data, shared_actors)
    {
      movie1_id: movie_data[:movie1][:id],
      movie1_title: movie_data[:movie1][:title],
      movie1_poster_path: movie_data[:movie1][:poster_path],
      movie1_release_date: movie_data[:movie1][:release_date],
      movie1_year: movie_data[:movie1][:year],
      movie2_id: movie_data[:movie2][:id],
      movie2_title: movie_data[:movie2][:title],
      movie2_poster_path: movie_data[:movie2][:poster_path],
      movie2_release_date: movie_data[:movie2][:release_date],
      movie2_year: movie_data[:movie2][:year],
      movie1_cast: cast_data[:movie1],
      movie2_cast: cast_data[:movie2],
      shared_actors: shared_actors
    }
  end

  def handle_tmdb_error(error, operation)
    StructuredLogger.error("MovieComparisonService Error",
                           type: "service_error",
                           service: "movie_comparison",
                           operation: operation,
                           error: error.message,
                           error_class: error.class.name)
  end
end
