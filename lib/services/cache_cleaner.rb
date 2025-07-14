# frozen_string_literal: true

require_relative "../config/logger"

# Background service for cleaning expired cache entries
class CacheCleaner
  def initialize(cache: nil, cleanup_interval: nil, batch_size: nil)
    @cache = cache || Cache

    configure_intervals(cleanup_interval, batch_size)
    initialize_state
  end

  private

  def configure_intervals(cleanup_interval, batch_size)
    if defined?(ConfigurationPolicy) && ConfigurationPolicy.get(:cache, :cleanup_interval)
      @cleanup_interval = cleanup_interval || ConfigurationPolicy.get(:cache, :cleanup_interval)
      @batch_size = batch_size || ConfigurationPolicy.get(:cache, :batch_size)
    else
      @cleanup_interval = cleanup_interval || 300
      @batch_size = batch_size || 100
    end
  end

  def initialize_state
    @running = false
    @thread = nil
    @mutex = Mutex.new
    @last_cleanup = Time.now
  end

  public

  def start
    @mutex.synchronize do
      return if @running

      @running = true
      @thread = Thread.new do
        run_cleanup_loop
      rescue StandardError => e
        StructuredLogger.error("CacheCleaner crashed", error: e.message, backtrace: e.backtrace.first(3))
        retry
      end
    end

    StructuredLogger.info("CacheCleaner started", interval: @cleanup_interval)
  end

  def stop
    @mutex.synchronize do
      return unless @running

      @running = false
      @thread&.kill
      @thread = nil
    end

    StructuredLogger.info("CacheCleaner stopped")
  end

  def status
    @mutex.synchronize do
      {
        running: @running,
        last_cleanup: @last_cleanup,
        next_cleanup: @last_cleanup + @cleanup_interval,
        cleanup_interval: @cleanup_interval
      }
    end
  end

  def cleanup_now
    # Get the underlying cache instance
    cache_instance = if @cache.respond_to?(:initialize_cache)
                       @cache.initialize_cache
                     else
                       @cache
                     end

    if cache_instance.respond_to?(:cleanup_expired)
      result = cache_instance.cleanup_expired(@batch_size)
      @last_cleanup = Time.now
      result
    else
      # For caches that don't support cleanup
      { removed: 0, message: "Cache doesn't support TTL cleanup" }
    end
  end

  private

  def run_cleanup_loop
    while @running
      sleep_time = calculate_sleep_time
      sleep(sleep_time) if sleep_time.positive?

      next unless @running

      perform_cleanup
    end
  end

  def calculate_sleep_time
    elapsed = Time.now - @last_cleanup
    @cleanup_interval - elapsed
  end

  def perform_cleanup
    start_time = Time.now
    result = cleanup_now
    duration = Time.now - start_time

    StructuredLogger.info("Cache cleanup completed",
                          duration_ms: (duration * 1000).round(2),
                          removed: result[:removed],
                          message: result[:message])
  rescue StandardError => e
    StructuredLogger.error("Cache cleanup failed", error: e.message)
  end
end

# Extension for MemoryCache to support TTL cleanup
class Cache
  class MemoryCache
    def cleanup_expired(batch_size = 100)
      removed = 0
      current_time = Time.now.to_f

      @mutex.synchronize do
        expired_keys = []

        # Find expired keys (limited by batch_size)
        @store.each do |key, entry|
          if entry[:expires_at] < current_time
            expired_keys << key
            break if expired_keys.size >= batch_size
          end
        end

        # Remove expired entries
        expired_keys.each do |key|
          @store.delete(key)
          removed += 1
        end
      end

      { removed: removed, message: "Cleaned #{removed} expired entries" }
    end

    def expired_count
      current_time = Time.now.to_f

      @mutex.synchronize do
        @store.count { |_, entry| entry[:expires_at] < current_time }
      end
    end
  end
end

# Extension for RedisCache to support TTL cleanup
class Cache
  class RedisCache
    def cleanup_expired(_batch_size = 100)
      # Redis handles TTL cleanup automatically
      { removed: 0, message: "Redis handles TTL cleanup automatically" }
    end

    def expired_count
      # Redis doesn't expose expired but not yet evicted keys
      0
    end
  end
end
