# frozen_string_literal: true

require_relative "../services/api_response_builder"

# TMDB-specific error handlers
module ErrorHandlerTMDB
  private

  def handle_tmdb_timeout_error(error)
    StructuredLogger.warn("TMDB Timeout",
                          type: "tmdb_timeout",
                          error: error.message,
                          request_path: request.path)

    if request.xhr? || request.content_type&.include?("application/json")
      response_builder = ApiResponseBuilder.new(self)
      halt response_builder.error("Request timed out", code: 504, details: { message: "Please try again" })
    else
      status 504
      send_error_page("504.html", fallback: "Please try again later")
    end
  end

  def handle_tmdb_auth_error(error)
    StructuredLogger.error("TMDB Auth Failed",
                           type: "tmdb_auth_error",
                           error: error.message)

    Sentry.capture_exception(error) if defined?(Sentry)

    if request.xhr? || request.content_type&.include?("application/json")
      response_builder = ApiResponseBuilder.new(self)
      halt response_builder.error("Authentication failed", code: 401)
    else
      status 401
      send_error_page("401.html", fallback: "Authentication error")
    end
  end

  def handle_tmdb_rate_limit_error(error)
    StructuredLogger.warn("TMDB Rate Limit",
                          type: "tmdb_rate_limit",
                          error: error.message,
                          request_path: request.path)

    if request.xhr? || request.content_type&.include?("application/json")
      response_builder = ApiResponseBuilder.new(self)
      halt response_builder.error("Rate limit exceeded", code: 429, details: { retry_after: 60 })
    else
      status 429
      send_error_page("429.html", fallback: "Too many requests. Please wait a moment.")
    end
  end

  def handle_tmdb_not_found_error(error)
    StructuredLogger.info("TMDB Not Found",
                          type: "tmdb_not_found",
                          error: error.message,
                          request_path: request.path)

    if request.xhr? || request.content_type&.include?("application/json")
      response_builder = ApiResponseBuilder.new(self)
      halt response_builder.error("Resource not found", code: 404)
    else
      status 404
      send_error_page("404.html")
    end
  end

  def handle_tmdb_service_error(error)
    StructuredLogger.error("TMDB Service Error",
                           type: "tmdb_service_error",
                           error: error.message,
                           request_path: request.path)

    if request.xhr? || request.content_type&.include?("application/json")
      response_builder = ApiResponseBuilder.new(self)
      halt response_builder.error("Service unavailable", code: 503, details: { message: "Please try again later" })
    else
      status 503
      send_error_page("503.html", fallback: "Service temporarily unavailable")
    end
  end

  def handle_cache_error(error)
    StructuredLogger.error("Cache Error",
                           type: "cache_error",
                           error: error.message,
                           error_class: error.class.name)

    # Don't fail the request on cache errors - gracefully degrade
    # The error is logged but the request continues
  end

  def send_error_page(filename, fallback: nil)
    error_file = File.join(settings.public_folder, "errors", filename)
    if File.exist?(error_file)
      send_file error_file, type: "text/html"
    else
      fallback || "An error occurred"
    end
  end
end
