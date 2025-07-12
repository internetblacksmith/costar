# frozen_string_literal: true

require "redis"
require "connection_pool"
require "json"

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
      initialize_cache.get(key)
    end

    def set(key, value, ttl = 300)
      initialize_cache.set(key, value, ttl)
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

    private

    def production?
      ENV.fetch("RACK_ENV", "development") == "production"
    end
  end

  # Redis-based cache for production
  class RedisCache
    def initialize
      @pool = ConnectionPool.new(size: 5, timeout: 5) do
        Redis.new(
          url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
          reconnect_attempts: 3,
          reconnect_delay: 1,
          timeout: 5
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
      puts "[CACHE] Error getting key #{key}: #{e.message}"
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
      puts "[CACHE] Error setting key #{key}: #{e.message}"
      false
    end

    def clear
      @pool.with do |redis|
        keys = redis.keys("#{cache_prefix}:*")
        redis.del(*keys) if keys.any?
      end
    rescue Redis::BaseError => e
      puts "[CACHE] Error clearing cache: #{e.message}"
      false
    end

    def size
      @pool.with do |redis|
        redis.keys("#{cache_prefix}:*").size
      end
    rescue Redis::BaseError => e
      puts "[CACHE] Error getting cache size: #{e.message}"
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
      ENV.fetch("CACHE_PREFIX", "actorsync")
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
