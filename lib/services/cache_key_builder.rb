# frozen_string_literal: true

require "digest"

##
# Centralized cache key generation for consistent naming and collision prevention
#
# Provides standardized cache key generation across all services to ensure
# consistency and prevent key collisions. Uses MD5 hashing for complex queries
# and structured naming for predictable keys.
#
# @example
#   builder = CacheKeyBuilder.new
#   key = builder.actor_profile(12345)
#   # => "actor:profile:12345"
#
class CacheKeyBuilder
  # Cache key version for invalidating all keys when structure changes
  VERSION = "v1"

  ##
  # Generate cache key for actor profile data
  #
  # @param actor_id [Integer, String] The TMDB actor ID
  # @return [String] Formatted cache key
  #
  def actor_profile(actor_id)
    "#{VERSION}:actor:profile:#{actor_id}"
  end

  ##
  # Generate cache key for actor movie credits
  #
  # @param actor_id [Integer, String] The TMDB actor ID
  # @return [String] Formatted cache key
  #
  def actor_movies(actor_id)
    "#{VERSION}:actor:movies:#{actor_id}"
  end

  ##
  # Generate cache key for actor search results
  #
  # @param query [String] The search query
  # @return [String] Formatted cache key with hashed query
  #
  def search_results(query)
    query_hash = Digest::MD5.hexdigest(query.to_s.downcase.strip)
    "#{VERSION}:search:#{query_hash}"
  end

  ##
  # Generate cache key for actor comparison data
  #
  # @param actor1_id [Integer, String] First actor ID
  # @param actor2_id [Integer, String] Second actor ID
  # @return [String] Formatted cache key with normalized order
  #
  def actor_comparison(actor1_id, actor2_id)
    # Normalize order to ensure same comparison gets same key regardless of order
    ids = [actor1_id.to_i, actor2_id.to_i].sort
    "#{VERSION}:comparison:#{ids[0]}:#{ids[1]}"
  end

  ##
  # Generate cache key for actor name
  #
  # @param actor_id [Integer, String] The TMDB actor ID
  # @return [String] Formatted cache key
  #
  def actor_name(actor_id)
    "#{VERSION}:actor:name:#{actor_id}"
  end

  ##
  # Generate cache key for health check status
  #
  # @return [String] Formatted cache key
  #
  def health_check
    "#{VERSION}:health:tmdb_api"
  end

  ##
  # Generate cache key for movie details
  #
  # @param movie_id [Integer, String] The TMDB movie ID
  # @return [String] Formatted cache key
  #
  def movie_details(movie_id)
    "#{VERSION}:movie:details:#{movie_id}"
  end

  ##
  # Generate cache key for movie search results
  #
  # @param query [String] The search query
  # @return [String] Formatted cache key with hashed query
  #
  def movie_search_results(query)
    query_hash = Digest::MD5.hexdigest(query.to_s.downcase.strip)
    "#{VERSION}:movie:search:#{query_hash}"
  end

  ##
  # Generate cache key for movie cast (actors in a movie)
  #
  # @param movie_id [Integer, String] The TMDB movie ID
  # @return [String] Formatted cache key
  #
  def movie_cast(movie_id)
    "#{VERSION}:movie:cast:#{movie_id}"
  end

  ##
  # Generate cache key for movie comparison data
  #
  # @param movie1_id [Integer, String] First movie ID
  # @param movie2_id [Integer, String] Second movie ID
  # @return [String] Formatted cache key with normalized order
  #
  def movie_comparison(movie1_id, movie2_id)
    # Normalize order to ensure same comparison gets same key regardless of order
    ids = [movie1_id.to_i, movie2_id.to_i].sort
    "#{VERSION}:movie:comparison:#{ids[0]}:#{ids[1]}"
  end

  ##
  # Generate pattern for cache invalidation
  #
  # @param pattern [String] The pattern type (actor, search, comparison, etc.)
  # @param identifier [String, Integer, nil] Optional identifier for specific invalidation
  # @return [String] Pattern for cache invalidation
  #
  def invalidation_pattern(pattern, identifier = nil)
    base_pattern = "#{VERSION}:#{pattern}"
    identifier ? "#{base_pattern}:#{identifier}*" : "#{base_pattern}*"
  end
end
