# frozen_string_literal: true

require_relative "../config/request_context"
require_relative "../config/logger"

##
# Middleware for managing request context lifecycle
#
# Automatically creates and manages RequestContext for each incoming request:
# - Creates new RequestContext at request start
# - Sets it in thread-local storage
# - Ensures cleanup after request completion
# - Adds request context to response headers (in development)
#
class RequestContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    context = RequestContext.new(request)

    # Log request start
    context.log_event("Request started",
                      type: "request_start",
                      url: request.url,
                      query_string: request.query_string)

    # Execute request with context
    status, headers, body = context.with_context do
      @app.call(env)
    end

    # Add request ID to response headers for debugging (non-production)
    if development_or_test?
      headers["X-Request-ID"] = context.request_id
      headers["X-Request-Duration"] = "#{context.duration_ms}ms"
    end

    [status, headers, body]
  rescue StandardError => e
    # Ensure we have a context for error logging
    context ||= RequestContext.new(request)

    context.log_error("Request failed with unhandled exception", e,
                      type: "request_error",
                      status: 500)

    # Re-raise the error to let other error handlers deal with it
    raise e
  ensure
    # Clean up thread-local storage
    RequestContext.current = nil
  end

  private

  def development_or_test?
    ENV.fetch("RACK_ENV", "development") != "production"
  end
end
