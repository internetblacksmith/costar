# frozen_string_literal: true

require "redis"
require "connection_pool"
require "json"
require_relative "logger"

# Cache abstraction supporting both Redis (production) and memory (development)
class Cache
  class << self
    def initialize_cache
      @initialize_cache ||= if production?
                              RedisCache.new
                            else
                              MemoryCache.new
                            end
    end

    def get(key)
      start_time = Time.now
      result = initialize_cache.get(key)
      duration_ms = (Time.now - start_time) * 1000

      # Track cache performance if monitor is available
      track_cache_performance("get", key, !result.nil?, duration_ms)

      result
    end

    def set(key, value, ttl = 300)
      start_time = Time.now
      result = initialize_cache.set(key, value, ttl)
      duration_ms = (Time.now - start_time) * 1000

      # Track cache performance if monitor is available (set is always a "miss" since we're writing)
      track_cache_performance("set", key, false, duration_ms)

      result
    end

    def clear
      initialize_cache.clear
    end

    def size
      initialize_cache.size
    end

    def healthy?
      initialize_cache.healthy?
    end

    def cleanup_expired(batch_size = 100)
      initialize_cache.cleanup_expired(batch_size)
    end

    private

    def production?
      env = ENV.fetch("RACK_ENV", "development")
      %w[production deployment].include?(env)
    end

    def track_cache_performance(operation, key, hit, duration_ms)
      return unless defined?(PerformanceMonitor)
      return unless PerformanceMonitor.respond_to?(:track_cache_performance)

      PerformanceMonitor.track_cache_performance(operation, key, hit, duration_ms)
    rescue StandardError => e
      # Silently fail in development to avoid breaking the application
      warn("Cache performance tracking error: #{e.message}") if ENV["RACK_ENV"] == "development"
    end
  end

  # Redis-based cache for production
  class RedisCache
    def initialize
      # Optimize connection pool size based on expected concurrency
      pool_size = ENV.fetch("REDIS_POOL_SIZE", "10").to_i
      pool_timeout = ENV.fetch("REDIS_POOL_TIMEOUT", "5").to_i

      @pool = ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
        Redis.new(
          url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
          reconnect_attempts: 3,
          connect_timeout: 3,      # Reduced for faster failures
          read_timeout: 3,         # Reduced for better performance
          write_timeout: 3,        # Reduced for better performance
          driver: :ruby            # Use fastest available driver
        )
      end
    end

    def get(key)
      @pool.with do |redis|
        data = redis.get(cache_key(key))
        return nil unless data

        entry = JSON.parse(data, symbolize_names: true)
        return nil if entry[:expires_at] < Time.now.to_f

        entry[:value]
      end
    rescue Redis::BaseError, JSON::ParserError => e
      StructuredLogger.error("Cache Get Error", type: "cache_error", operation: "get", key: key, error: e.message)
      nil
    end

    def set(key, value, ttl = 300)
      @pool.with do |redis|
        entry = {
          value: value,
          expires_at: Time.now.to_f + ttl
        }

        redis.setex(cache_key(key), ttl + 60, entry.to_json) # Extra 60s buffer
      end
    rescue Redis::BaseError => e
      StructuredLogger.error("Cache Set Error", type: "cache_error", operation: "set", key: key, error: e.message)
      false
    end

    def clear
      @pool.with do |redis|
        keys = redis.keys("#{cache_prefix}:*")
        redis.del(*keys) if keys.any?
      end
    rescue Redis::BaseError => e
      StructuredLogger.error("Cache Clear Error", type: "cache_error", operation: "clear", error: e.message)
      false
    end

    def size
      @pool.with do |redis|
        redis.keys("#{cache_prefix}:*").size
      end
    rescue Redis::BaseError => e
      StructuredLogger.error("Cache Size Error", type: "cache_error", operation: "size", error: e.message)
      0
    end

    def healthy?
      @pool.with do |redis|
        redis.ping == "PONG"
      end
    rescue Redis::BaseError
      false
    end

    private

    def cache_key(key)
      "#{cache_prefix}:#{key}"
    end

    def cache_prefix
      ENV.fetch("CACHE_PREFIX", "costar")
    end
  end

  # Memory-based cache for development
  class MemoryCache
    def initialize
      @store = {}
      @mutex = Mutex.new
    end

    def get(key)
      @mutex.synchronize do
        entry = @store[key]
        return nil unless entry
        return nil if entry[:expires_at] < Time.now.to_f

        entry[:value]
      end
    end

    def set(key, value, ttl = 300)
      @mutex.synchronize do
        @store[key] = {
          value: value,
          expires_at: Time.now.to_f + ttl
        }
      end
      value
    end

    def clear
      @mutex.synchronize do
        @store.clear
      end
      nil
    end

    def size
      @mutex.synchronize do
        @store.size
      end
    end

    def healthy?
      true
    end
  end
end
