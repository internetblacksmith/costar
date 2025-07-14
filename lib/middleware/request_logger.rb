# frozen_string_literal: true

require_relative "../config/logger"
require_relative "../config/request_context"
require_relative "../services/performance_monitor"

# Middleware for structured request/response logging
class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if skip_logging?(env)

    process_request_with_logging(env)
  end

  private

  def process_request_with_logging(env)
    start_time = Time.now
    status, headers, body = @app.call(env)

    log_successful_request(env, status, start_time)
    [status, headers, body]
  rescue StandardError => e
    log_request_error(env, e, start_time)
    raise
  end

  def log_successful_request(env, status, start_time)
    duration_ms = (Time.now - start_time) * 1000

    # Use RequestContext if available for enhanced logging
    if RequestContext.current
      RequestContext.current.add_metadata(:status, status)
      RequestContext.current.add_metadata(:response_time_ms, duration_ms)
      RequestContext.current.log_event("Request completed",
                                       type: "http_request",
                                       status: status)
    else
      StructuredLogger.log_request(env, status, duration_ms)
    end

    # Track performance with error handling
    track_request_performance(env, status, duration_ms)
  end

  def log_request_error(env, error, start_time)
    duration_ms = (Time.now - start_time) * 1000

    # Use RequestContext if available for enhanced error logging
    if RequestContext.current
      RequestContext.current.add_metadata(:status, 500)
      RequestContext.current.add_metadata(:response_time_ms, duration_ms)
      RequestContext.current.log_error("Request Error", error,
                                       type: "http_request_error",
                                       status: 500)
    else
      StructuredLogger.error("Request Error",
                             type: "request_error",
                             method: env["REQUEST_METHOD"],
                             path: env["PATH_INFO"],
                             error: error.message,
                             error_class: error.class.name,
                             duration_ms: duration_ms.round(2),
                             timestamp: Time.now.iso8601)
    end

    # Track performance for error requests as 500 status
    track_request_performance(env, 500, duration_ms)
  end

  def track_request_performance(env, status, duration_ms)
    return unless defined?(PerformanceMonitor)
    return unless PerformanceMonitor.respond_to?(:track_request)

    PerformanceMonitor.track_request(env, status, duration_ms)
  rescue StandardError => e
    # Silently fail in development to avoid breaking the application
    warn("Request performance tracking error: #{e.message}") if ENV["RACK_ENV"] == "development"
  end

  def skip_logging?(env)
    path = env["PATH_INFO"]

    # Skip health checks and static assets
    path == "/health/simple" ||
      path == "/favicon.ico" ||
      path.start_with?("/css/") ||
      path.start_with?("/js/") ||
      path.start_with?("/images/")
  end
end
