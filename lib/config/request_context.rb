# frozen_string_literal: true

require "securerandom"
require_relative "logger"

##
# Request Context Pattern for managing request lifecycle and state
#
# Provides centralized access to request-specific data including:
# - Request ID for tracing
# - Request timing
# - User information
# - Request metadata
# - Structured logging context
#
class RequestContext
  # Thread-local storage for request context
  THREAD_KEY = :current_request_context

  attr_reader :request_id, :start_time, :user_ip, :user_agent, :method, :path, :params

  def initialize(request)
    @request_id = SecureRandom.uuid
    @start_time = Time.now
    @user_ip = extract_user_ip(request)
    @user_agent = request.env["HTTP_USER_AGENT"]
    @method = request.request_method
    @path = request.path_info
    @params = request.params.dup.freeze
    @metadata = {}
  end

  # Get the current request context from thread-local storage
  def self.current
    Thread.current[THREAD_KEY]
  end

  # Set the current request context in thread-local storage
  def self.current=(context)
    Thread.current[THREAD_KEY] = context
  end

  # Execute a block with this request context active
  def with_context(&block)
    previous_context = RequestContext.current
    RequestContext.current = self

    begin
      result = block.call(self)
      log_request_completion
      result
    ensure
      RequestContext.current = previous_context
    end
  end

  # Add metadata to the request context
  def add_metadata(key, value)
    @metadata[key.to_sym] = value
  end

  # Get metadata from the request context
  def get_metadata(key)
    @metadata[key.to_sym]
  end

  # Get request duration in milliseconds
  def duration_ms
    ((Time.now - @start_time) * 1000).round(2)
  end

  # Generate structured log context
  def log_context
    {
      request_id: @request_id,
      method: @method,
      path: @path,
      user_ip: @user_ip,
      duration_ms: duration_ms,
      metadata: @metadata
    }
  end

  # Log request completion with timing
  def log_request_completion
    StructuredLogger.info("Request completed",
                          **log_context, type: "request_completion",
                                         total_duration_ms: duration_ms)
  end

  # Log an event within this request context
  def log_event(message, additional_data = {})
    StructuredLogger.info(message, **log_context, **additional_data)
  end

  # Log an error within this request context
  def log_error(message, error = nil, additional_data = {})
    error_data = log_context.merge(additional_data)

    if error
      error_data.merge!(
        error_class: error.class.name,
        error_message: error.message,
        error_backtrace: error.backtrace&.first(5)
      )
    end

    StructuredLogger.error(message, **error_data)
  end

  # Get a string representation for debugging
  def to_s
    "#<RequestContext id=#{@request_id} method=#{@method} path=#{@path} duration=#{duration_ms}ms>"
  end

  private

  def extract_user_ip(request)
    # Check for various headers that might contain the real IP
    # when behind proxies/load balancers
    forwarded_for = request.env["HTTP_X_FORWARDED_FOR"]
    real_ip = request.env["HTTP_X_REAL_IP"]
    client_ip = request.env["HTTP_CLIENT_IP"]

    if forwarded_for
      # X-Forwarded-For can contain multiple IPs, take the first one
      forwarded_for.split(",").first.strip
    elsif real_ip
      real_ip
    elsif client_ip
      client_ip
    else
      request.env["REMOTE_ADDR"]
    end
  end
end
