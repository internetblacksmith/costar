# frozen_string_literal: true

# Use raw seconds for TTL values to avoid ActiveSupport dependency issues
require_relative "cache_key_builder"
require_relative "../config/cache"

##
# Centralized cache management with consistent patterns and batch operations
#
# Provides a unified interface for caching operations across all services,
# eliminating code duplication and ensuring consistent cache behavior.
# Supports batch operations to reduce N+1 cache queries.
#
# @example Basic usage
#   cache_manager = CacheManager.new
#   result = cache_manager.fetch('my_key', ttl: 300) { expensive_operation() }
#
# @example Batch operations
#   keys = ['key1', 'key2', 'key3']
#   results = cache_manager.fetch_multi(keys) { |missing_keys| fetch_missing_data(missing_keys) }
#
class CacheManager
  # Default TTL values for different data types (in seconds)
  TTL_POLICIES = {
    actor_profile: 1800,    # 30 minutes
    actor_movies: 600,      # 10 minutes
    search_results: 300,    # 5 minutes
    actor_comparison: 900,  # 15 minutes
    actor_name: 1800,       # 30 minutes
    health_check: 60,       # 1 minute
    movie_details: 3600     # 1 hour
  }.freeze

  attr_reader :key_builder

  def initialize
    @key_builder = CacheKeyBuilder.new
  end

  ##
  # Fetch data from cache or execute block if not found
  #
  # @param key [String] Cache key
  # @param ttl [Integer] Time to live in seconds
  # @param policy [Symbol] TTL policy name (overrides ttl parameter)
  # @yield Block to execute if cache miss
  # @return [Object] Cached or computed result
  #
  def fetch(key, ttl: 300, policy: nil)
    effective_ttl = policy ? TTL_POLICIES[policy] || ttl : ttl

    # Try to get from cache first
    cached_value = Cache.get(key)
    return cached_value unless cached_value.nil?

    # Cache miss - execute block if provided
    return nil unless block_given?

    computed_value = yield
    Cache.set(key, computed_value, effective_ttl)
    computed_value
  rescue StandardError => e
    StructuredLogger.error(
      "Cache operation failed",
      type: "cache_error",
      key: key,
      ttl: effective_ttl,
      error: e.message
    )

    # Execute block directly if cache fails
    block_given? ? yield : nil
  end

  ##
  # Fetch multiple keys from cache, executing block for missing keys
  #
  # @param keys [Array<String>] Array of cache keys
  # @param ttl [Integer] Time to live in seconds
  # @param policy [Symbol] TTL policy name
  # @yield [Array<String>] Block receives array of missing keys
  # @return [Hash] Hash of key => value pairs
  #
  def fetch_multi(keys, ttl: 300, policy: nil)
    effective_ttl = policy ? TTL_POLICIES[policy] || ttl : ttl
    results = {}

    # Get existing cached values
    cached_values = get_multi(keys)
    results.merge!(cached_values)

    # Find missing keys
    missing_keys = keys - cached_values.keys

    # Fetch missing values if any
    if missing_keys.any? && block_given?
      missing_values = yield(missing_keys)

      # Store missing values and add to results
      if missing_values.is_a?(Hash)
        missing_values.each do |key, value|
          set(key, value, ttl: effective_ttl)
          results[key] = value
        end
      end
    end

    results
  rescue StandardError => e
    StructuredLogger.error(
      "Cache multi-fetch failed",
      type: "cache_error",
      keys: keys,
      ttl: effective_ttl,
      error: e.message
    )

    # Execute block with all keys if cache fails
    block_given? ? yield(keys) : {}
  end

  ##
  # Set a value in cache
  #
  # @param key [String] Cache key
  # @param value [Object] Value to cache
  # @param ttl [Integer] Time to live in seconds
  # @param policy [Symbol] TTL policy name
  # @return [Object] The cached value
  #
  def set(key, value, ttl: 300, policy: nil)
    effective_ttl = policy ? TTL_POLICIES[policy] || ttl : ttl
    Cache.set(key, value, effective_ttl)
  end

  ##
  # Get a value from cache without fallback
  #
  # @param key [String] Cache key
  # @return [Object, nil] Cached value or nil if not found
  #
  def get(key)
    Cache.get(key)
  end

  ##
  # Get multiple values from cache
  #
  # @param keys [Array<String>] Array of cache keys
  # @return [Hash] Hash of key => value pairs for found keys
  #
  def get_multi(keys)
    result = {}

    keys.each do |key|
      value = get(key)
      result[key] = value unless value.nil?
    end

    result
  end

  ##
  # Delete a key from cache
  #
  # @param key [String] Cache key to delete
  # @return [Boolean] True if key was deleted
  #
  def delete(key)
    # The existing Cache interface doesn't have a delete method
    # Set with TTL of 0 to effectively delete immediately
    Cache.set(key, nil, 0)
    true
  rescue StandardError => e
    StructuredLogger.error(
      "Cache delete failed",
      type: "cache_error",
      key: key,
      error: e.message
    )
    false
  end

  ##
  # Invalidate cache entries matching a pattern
  #
  # @param pattern [String] Pattern to match keys
  # @return [Integer] Number of keys invalidated
  #
  def invalidate(pattern)
    if Cache.respond_to?(:delete_matched)
      Cache.delete_matched(pattern)
    else
      # Fallback for cache implementations without pattern matching
      StructuredLogger.warn(
        "Cache invalidation by pattern not supported",
        type: "cache_warning",
        pattern: pattern
      )
      0
    end
  end

  ##
  # Clear all cache entries (use with caution)
  #
  # @return [Boolean] True if cache was cleared
  #
  def clear_all
    Cache.clear
  end

  ##
  # Get cache statistics if available
  #
  # @return [Hash] Cache statistics
  #
  def stats
    if Cache.respond_to?(:stats)
      Cache.stats
    else
      { supported: false }
    end
  end

  ##
  # Check if cache is healthy
  #
  # @return [Boolean] True if cache is responsive
  #
  def healthy?
    test_key = "health_check_#{Time.now.to_i}"
    set(test_key, true, ttl: 10)
    get(test_key) == true
  rescue StandardError
    false
  ensure
    begin
      delete(test_key)
    rescue StandardError
      nil
    end
  end

  ##
  # Convenience methods for common cache operations with appropriate TTLs
  ##

  def cache_actor_profile(actor_id, &block)
    key = key_builder.actor_profile(actor_id)
    fetch(key, policy: :actor_profile, &block)
  end

  def cache_actor_movies(actor_id, &block)
    key = key_builder.actor_movies(actor_id)
    fetch(key, policy: :actor_movies, &block)
  end

  def cache_search_results(query, &block)
    key = key_builder.search_results(query)
    fetch(key, policy: :search_results, &block)
  end

  def cache_actor_comparison(actor1_id, actor2_id, &block)
    key = key_builder.actor_comparison(actor1_id, actor2_id)
    fetch(key, policy: :actor_comparison, &block)
  end

  def cache_actor_name(actor_id, &block)
    key = key_builder.actor_name(actor_id)
    fetch(key, policy: :actor_name, &block)
  end

  def cache_health_check(&block)
    key = key_builder.health_check
    fetch(key, policy: :health_check, &block)
  end

  ##
  # Batch operations for common patterns
  ##

  def batch_actor_profiles(actor_ids)
    keys = actor_ids.map { |id| key_builder.actor_profile(id) }
    key_to_id = keys.zip(actor_ids).to_h { |key, id| [key, id] }

    fetch_multi(keys, policy: :actor_profile) do |missing_keys|
      missing_ids = missing_keys.map { |key| key_to_id[key] }
      yield(missing_ids)
    end
  end

  def batch_actor_names(actor_ids)
    keys = actor_ids.map { |id| key_builder.actor_name(id) }
    key_to_id = keys.zip(actor_ids).to_h { |key, id| [key, id] }

    fetch_multi(keys, policy: :actor_name) do |missing_keys|
      missing_ids = missing_keys.map { |key| key_to_id[key] }
      yield(missing_ids)
    end
  end
end
