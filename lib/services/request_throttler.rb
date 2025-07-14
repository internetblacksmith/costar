# frozen_string_literal: true

require_relative "../config/logger"

# Request throttler with priority queuing for TMDB API calls
# Ensures we don't exceed rate limits while prioritizing important requests
class RequestThrottler
  # TMDB rate limits: 40 requests per 10 seconds
  # We'll be conservative and limit to 30 requests per 10 seconds
  DEFAULT_MAX_REQUESTS = 30
  DEFAULT_WINDOW_SIZE = 10 # seconds

  # Priority levels
  PRIORITY_HIGH = 0    # User-initiated searches
  PRIORITY_MEDIUM = 1  # Actor details/profiles
  PRIORITY_LOW = 2     # Movie credits, background loads

  def initialize(max_requests: DEFAULT_MAX_REQUESTS, window_size: DEFAULT_WINDOW_SIZE)
    @max_requests = max_requests
    @window_size = window_size
    @requests = []
    @mutex = Mutex.new
    @condition = ConditionVariable.new
    @queue = PriorityQueue.new
    @processing = false

    # Start background processor
    start_processor
  end

  # Execute a request with throttling
  def throttle(priority: PRIORITY_MEDIUM, &block)
    request = ThrottledRequest.new(priority, block)

    @mutex.synchronize do
      @queue.push(request)
      @condition.signal
    end

    # Wait for request to complete
    request.wait_for_completion

    # Raise any error that occurred
    raise request.error if request.error

    request.result
  end

  # Execute high-priority request (user searches)
  def throttle_high_priority(&block)
    throttle(priority: PRIORITY_HIGH, &block)
  end

  # Execute medium-priority request (actor details)
  def throttle_medium_priority(&block)
    throttle(priority: PRIORITY_MEDIUM, &block)
  end

  # Execute low-priority request (movie credits)
  def throttle_low_priority(&block)
    throttle(priority: PRIORITY_LOW, &block)
  end

  # Get current throttle status
  def status
    @mutex.synchronize do
      {
        queue_size: @queue.size,
        recent_requests: @requests.size,
        window_size: @window_size,
        max_requests: @max_requests,
        current_rate: calculate_current_rate
      }
    end
  end

  private

  def start_processor
    @processing = true
    Thread.new do
      process_next_request while @processing
    rescue StandardError => e
      StructuredLogger.error("RequestThrottler processor error", error: e.message)
      retry
    end
  end

  def process_next_request
    request = nil

    @mutex.synchronize do
      # Wait for requests
      @condition.wait(@mutex) while @queue.empty? && @processing
      return unless @processing

      # Clean old requests
      clean_old_requests

      # Wait if we're at rate limit
      while @requests.size >= @max_requests
        sleep_time = time_until_next_slot
        @condition.wait(@mutex, sleep_time)
        clean_old_requests
      end

      # Get next request
      request = @queue.pop
      @requests << Time.now if request
    end

    # Execute request outside of mutex
    execute_request(request) if request
  end

  def execute_request(request)
    start_time = Time.now

    begin
      request.result = request.block.call
      StructuredLogger.info("Throttled request completed",
                            priority: request.priority,
                            duration: Time.now - start_time)
    rescue StandardError => e
      request.error = e
      StructuredLogger.error("Throttled request failed",
                             priority: request.priority,
                             error: e.message)
    ensure
      request.complete!
    end
  end

  def clean_old_requests
    cutoff = Time.now - @window_size
    @requests.reject! { |time| time < cutoff }
  end

  def time_until_next_slot
    return 0 if @requests.empty?

    oldest_request = @requests.first
    time_elapsed = Time.now - oldest_request

    if time_elapsed >= @window_size
      0
    else
      @window_size - time_elapsed + 0.1 # Add small buffer
    end
  end

  def calculate_current_rate
    clean_old_requests
    @requests.size.to_f / @window_size
  end

  # Shutdown the throttler
  def shutdown
    @mutex.synchronize do
      @processing = false
      @condition.broadcast
    end
  end
end

# Priority queue implementation
class PriorityQueue
  def initialize
    @queue = []
    @mutex = Mutex.new
  end

  def push(item)
    @mutex.synchronize do
      @queue.push(item)
      @queue.sort_by!(&:priority)
    end
  end

  def pop
    @mutex.synchronize do
      @queue.shift
    end
  end

  def size
    @mutex.synchronize do
      @queue.size
    end
  end

  def empty?
    @mutex.synchronize do
      @queue.empty?
    end
  end
end

# Represents a throttled request
class ThrottledRequest
  attr_reader :priority, :block
  attr_accessor :result, :error

  def initialize(priority, block)
    @priority = priority
    @block = block
    @mutex = Mutex.new
    @condition = ConditionVariable.new
    @completed = false
  end

  def wait_for_completion
    @mutex.synchronize do
      @condition.wait(@mutex) until @completed
    end
  end

  def complete!
    @mutex.synchronize do
      @completed = true
      @condition.signal
    end
  end
end

