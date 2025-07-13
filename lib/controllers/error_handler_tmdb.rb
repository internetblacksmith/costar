# frozen_string_literal: true

# TMDB-specific error handlers
module ErrorHandlerTMDB
  private

  def handle_tmdb_timeout_error(error)
    StructuredLogger.warn("TMDB Timeout",
                          type: "tmdb_timeout",
                          error: error.message,
                          request_path: request.path)

    status 504
    if request.xhr? || request.content_type&.include?("application/json")
      content_type :json
      { error: "Request timed out", message: "Please try again" }.to_json
    else
      send_error_page("504.html", fallback: "Please try again later")
    end
  end

  def handle_tmdb_auth_error(error)
    StructuredLogger.error("TMDB Auth Failed",
                           type: "tmdb_auth_error",
                           error: error.message)

    Sentry.capture_exception(error) if defined?(Sentry)

    status 401
    if request.xhr? || request.content_type&.include?("application/json")
      content_type :json
      { error: "Authentication failed" }.to_json
    else
      send_error_page("401.html", fallback: "Authentication error")
    end
  end

  def handle_tmdb_rate_limit_error(error)
    StructuredLogger.warn("TMDB Rate Limit",
                          type: "tmdb_rate_limit",
                          error: error.message,
                          request_path: request.path)

    status 429
    if request.xhr? || request.content_type&.include?("application/json")
      content_type :json
      { error: "Rate limit exceeded", retry_after: 60 }.to_json
    else
      send_error_page("429.html", fallback: "Too many requests. Please wait a moment.")
    end
  end

  def handle_tmdb_not_found_error(error)
    StructuredLogger.info("TMDB Not Found",
                          type: "tmdb_not_found",
                          error: error.message,
                          request_path: request.path)

    status 404
    if request.xhr? || request.content_type&.include?("application/json")
      content_type :json
      { error: "Resource not found" }.to_json
    else
      send_error_page("404.html")
    end
  end

  def handle_tmdb_service_error(error)
    StructuredLogger.error("TMDB Service Error",
                           type: "tmdb_service_error",
                           error: error.message,
                           request_path: request.path)

    status 503
    if request.xhr? || request.content_type&.include?("application/json")
      content_type :json
      { error: "Service unavailable", message: "Please try again later" }.to_json
    else
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
