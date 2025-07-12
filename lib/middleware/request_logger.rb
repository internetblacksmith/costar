# frozen_string_literal: true

require_relative "../config/logger"

# Middleware for structured request/response logging
class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.now

    # Skip logging for health checks and static assets
    return @app.call(env) if skip_logging?(env)

    status, headers, body = @app.call(env)
    
    duration_ms = (Time.now - start_time) * 1000
    
    StructuredLogger.log_request(env, status, duration_ms)
    
    [status, headers, body]
  rescue => e
    duration_ms = (Time.now - start_time) * 1000
    
    StructuredLogger.error("Request Error", 
      type: "request_error",
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      error: e.message,
      error_class: e.class.name,
      duration_ms: duration_ms.round(2),
      timestamp: Time.now.iso8601
    )
    
    raise
  end

  private

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