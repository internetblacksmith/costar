# frozen_string_literal: true

require_relative "../config/logger"

# Simple request throttler without background threads
# Tracks request times and enforces rate limits synchronously
class SimpleRequestThrottler
  # TMDB rate limits: 40 requests per 10 seconds
  # We'll be conservative and limit to 30 requests per 10 seconds
  DEFAULT_MAX_REQUESTS = 30
  DEFAULT_WINDOW_SIZE = 10 # seconds

  def initialize(max_requests: nil, window_size: nil)
    # Use configuration policy or defaults
    if defined?(ConfigurationPolicy) && ConfigurationPolicy.get(:rate_limiting, :max_requests)
      @max_requests = max_requests || ConfigurationPolicy.get(:rate_limiting, :max_requests)
      @window_size = window_size || ConfigurationPolicy.get(:rate_limiting, :window_size)
    else
      @max_requests = max_requests || DEFAULT_MAX_REQUESTS
      @window_size = window_size || DEFAULT_WINDOW_SIZE
    end
    @requests = []
    @mutex = Mutex.new
  end

  # Execute a request with throttling (synchronous)
  def throttle(priority: nil, &block)
    @mutex.synchronize do
      # Clean old requests
      clean_old_requests
      
      # Wait if we're at rate limit
      wait_for_rate_limit if @requests.size >= @max_requests
      
      # Record this request
      @requests << Time.now
    end
    
    # Execute the block immediately
    start_time = Time.now
    begin
      result = yield
      StructuredLogger.debug("Throttled request completed",
                           priority: priority,
                           duration: Time.now - start_time)
      result
    rescue StandardError => e
      StructuredLogger.error("Throttled request failed",
                           priority: priority,
                           error: e.message)
      raise
    end
  end

  # Convenience methods for priority (but they don't affect execution order)
  def throttle_high_priority(&block)
    throttle(priority: "high", &block)
  end

  def throttle_medium_priority(&block)
    throttle(priority: "medium", &block)
  end

  def throttle_low_priority(&block)
    throttle(priority: "low", &block)
  end

  # Get current throttle status
  def status
    @mutex.synchronize do
      clean_old_requests
      {
        queue_size: 0, # No queue in simple version
        recent_requests: @requests.size,
        window_size: @window_size,
        max_requests: @max_requests,
        current_rate: calculate_current_rate
      }
    end
  end

  # Shutdown method for compatibility (no-op in simple version)
  def shutdown
    # Nothing to shutdown in simple version
  end

  private

  def clean_old_requests
    cutoff = Time.now - @window_size
    @requests.reject! { |time| time < cutoff }
  end

  def wait_for_rate_limit
    # Simple sleep until the oldest request expires
    return if @requests.empty?
    
    oldest_request = @requests.first
    time_elapsed = Time.now - oldest_request
    
    if time_elapsed < @window_size
      sleep_time = @window_size - time_elapsed + 0.1 # Add small buffer
      StructuredLogger.debug("Rate limit reached, sleeping for #{sleep_time.round(2)}s")
      sleep(sleep_time)
      clean_old_requests
    end
  end

  def calculate_current_rate
    @requests.size.to_f / @window_size
  end
end