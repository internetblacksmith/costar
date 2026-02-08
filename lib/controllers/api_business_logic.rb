# frozen_string_literal: true

require_relative "../config/logger"

##
# Pure business logic for API operations
#
# Handles business operations without coupling to HTTP concerns,
# input validation, or rendering. Focuses on coordinating service
# calls and data processing.
#
# @example Basic usage
#   business_logic = ApiBusinessLogic.new(tmdb_service, comparison_service)
#   result = business_logic.search_actors("Leonardo DiCaprio")
#
class ApiBusinessLogic
  def initialize(tmdb_service, comparison_service, movie_comparison_service = nil)
    @tmdb_service = tmdb_service
    @comparison_service = comparison_service
    @movie_comparison_service = movie_comparison_service
  end

  ##
  # Searches for actors using the TMDB service
  #
  # @param query [String] Search query
  # @return [Array<Hash>] Array of actor data
  #
  def search_actors(query)
    @tmdb_service.search_actors(query)
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Actor search failed",
                           type: "business_logic_error",
                           operation: "search_actors",
                           query: query,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error in actor search",
                           type: "business_logic_error",
                           operation: "search_actors",
                           query: query,
                           error: e.message,
                           error_class: e.class.name)
    raise e
  end

  ##
  # Fetches movies for a specific actor
  #
  # @param actor_id [Integer] Actor ID
  # @return [Array<Hash>] Array of movie data
  #
  def fetch_actor_movies(actor_id)
    @tmdb_service.get_actor_movies(actor_id)
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Actor movies fetch failed",
                           type: "business_logic_error",
                           operation: "fetch_actor_movies",
                           actor_id: actor_id,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error fetching actor movies",
                           type: "business_logic_error",
                           operation: "fetch_actor_movies",
                           actor_id: actor_id,
                           error: e.message,
                           error_class: e.class.name)
    raise e
  end

  ##
  # Compares two actors and generates timeline data
  #
  # @param actor1_id [Integer] First actor ID
  # @param actor2_id [Integer] Second actor ID
  # @param actor1_name [String, nil] Optional first actor name
  # @param actor2_name [String, nil] Optional second actor name
  # @return [Hash] Comparison data with timeline information
  #
  def compare_actors(actor1_id, actor2_id, actor1_name = nil, actor2_name = nil)
    @comparison_service.compare(actor1_id, actor2_id, actor1_name, actor2_name)
  rescue ValidationError => e
    StructuredLogger.error("Business Logic: Actor comparison validation failed",
                           type: "business_logic_error",
                           operation: "compare_actors",
                           actor1_id: actor1_id,
                           actor2_id: actor2_id,
                           error: e.message)
    raise e
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Actor comparison API failed",
                           type: "business_logic_error",
                           operation: "compare_actors",
                           actor1_id: actor1_id,
                           actor2_id: actor2_id,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error in actor comparison",
                           type: "business_logic_error",
                           operation: "compare_actors",
                           actor1_id: actor1_id,
                           actor2_id: actor2_id,
                           error: e.message,
                           error_class: e.class.name,
                           backtrace: e.backtrace.first(3))
    raise e
  end

  ##
  # Searches for movies using the TMDB service
  #
  # @param query [String] Search query
  # @return [Array<Hash>] Array of movie data
  #
  def search_movies(query)
    @tmdb_service.search_movies(query)
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Movie search failed",
                           type: "business_logic_error",
                           operation: "search_movies",
                           query: query,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error in movie search",
                           type: "business_logic_error",
                           operation: "search_movies",
                           query: query,
                           error: e.message,
                           error_class: e.class.name)
    raise e
  end

  ##
  # Fetches cast for a specific movie
  #
  # @param movie_id [Integer] Movie ID
  # @return [Array<Hash>] Array of actor data
  #
  def fetch_movie_cast(movie_id)
    @tmdb_service.get_movie_cast(movie_id)
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Movie cast fetch failed",
                           type: "business_logic_error",
                           operation: "fetch_movie_cast",
                           movie_id: movie_id,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error fetching movie cast",
                           type: "business_logic_error",
                           operation: "fetch_movie_cast",
                           movie_id: movie_id,
                           error: e.message,
                           error_class: e.class.name)
    raise e
  end

  ##
  # Compares two movies and finds shared actors
  #
  # @param movie1_id [Integer] First movie ID
  # @param movie2_id [Integer] Second movie ID
  # @param movie1_title [String, nil] Optional first movie title
  # @param movie2_title [String, nil] Optional second movie title
  # @return [Hash] Comparison data with shared actors
  #
  def compare_movies(movie1_id, movie2_id, movie1_title = nil, movie2_title = nil)
    @movie_comparison_service.compare(movie1_id, movie2_id, movie1_title, movie2_title)
  rescue ValidationError => e
    StructuredLogger.error("Business Logic: Movie comparison validation failed",
                           type: "business_logic_error",
                           operation: "compare_movies",
                           movie1_id: movie1_id,
                           movie2_id: movie2_id,
                           error: e.message)
    raise e
  rescue TMDBError => e
    StructuredLogger.error("Business Logic: Movie comparison API failed",
                           type: "business_logic_error",
                           operation: "compare_movies",
                           movie1_id: movie1_id,
                           movie2_id: movie2_id,
                           error: e.message)
    raise e
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Unexpected error in movie comparison",
                           type: "business_logic_error",
                           operation: "compare_movies",
                           movie1_id: movie1_id,
                           movie2_id: movie2_id,
                           error: e.message,
                           error_class: e.class.name,
                           backtrace: e.backtrace.first(3))
    raise e
  end

  ##
  # Health check for business logic dependencies
  #
  # @return [Hash] Health status of dependent services
  #
  def health_check
    {
      tmdb_service: @tmdb_service.healthy?,
      comparison_service: true, # ActorComparisonService doesn't have health check
      movie_comparison_service: true # MovieComparisonService doesn't have health check
    }
  rescue StandardError => e
    StructuredLogger.error("Business Logic: Health check failed",
                           type: "business_logic_error",
                           operation: "health_check",
                           error: e.message)
    {
      tmdb_service: false,
      comparison_service: false,
      movie_comparison_service: false,
      error: e.message
    }
  end
end
