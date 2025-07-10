# frozen_string_literal: true

# Simple in-memory cache for API responses
class Cache
  @store = {}
  @mutex = Mutex.new

  class << self
    def get(key)
      @mutex.synchronize do
        entry = @store[key]
        return nil unless entry
        return nil if entry[:expires_at] < Time.now

        entry[:value]
      end
    end

    def set(key, value, ttl = 300)
      @mutex.synchronize do
        @store[key] = {
          value: value,
          expires_at: Time.now + ttl
        }
      end
    end

    def clear
      @mutex.synchronize do
        @store.clear
      end
    end

    def size
      @mutex.synchronize do
        @store.size
      end
    end
  end
end