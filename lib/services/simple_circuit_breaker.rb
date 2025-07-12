# frozen_string_literal: true

# Simple circuit breaker implementation for API resilience
class SimpleCircuitBreaker
  attr_reader :failure_count, :last_failure_time, :state

  def initialize(failure_threshold: 5, recovery_timeout: 60, expected_errors: [])
    @failure_threshold = failure_threshold
    @recovery_timeout = recovery_timeout
    @expected_errors = expected_errors
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
  end

  def call(&block)
    case @state
    when :closed
      call_with_failure_tracking(&block)
    when :open
      if time_to_retry?
        @state = :half_open
        call_with_recovery_tracking(&block)
      else
        raise CircuitOpenError, "Circuit breaker is open"
      end
    when :half_open
      call_with_recovery_tracking(&block)
    end
  end

  def reset!
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
  end

  private

  def call_with_failure_tracking(&block)
    result = yield
    reset_on_success
    result
  rescue => error
    record_failure(error)
    raise
  end

  def call_with_recovery_tracking(&block)
    result = yield
    @state = :closed
    @failure_count = 0
    result
  rescue => error
    @state = :open
    record_failure(error)
    raise
  end

  def record_failure(error)
    return unless expected_error?(error)

    @failure_count += 1
    @last_failure_time = Time.now

    @state = :open if @failure_count >= @failure_threshold
  end

  def reset_on_success
    @failure_count = 0 if @failure_count > 0
  end

  def expected_error?(error)
    return true if @expected_errors.empty?

    @expected_errors.any? { |expected| error.is_a?(expected) }
  end

  def time_to_retry?
    return false unless @last_failure_time

    Time.now - @last_failure_time > @recovery_timeout
  end

  class CircuitOpenError < StandardError; end
end