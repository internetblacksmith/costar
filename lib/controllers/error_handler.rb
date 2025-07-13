# frozen_string_literal: true

require_relative "error_handler_tmdb"

# Error handling controller for application-wide error management
module ErrorHandler
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    include ErrorHandlerTMDB
    def setup_error_handlers
      setup_api_error_handler
      setup_validation_error_handler
      setup_tmdb_error_handler
      setup_specific_tmdb_error_handlers
      setup_cache_error_handlers
      setup_not_found_handler
      setup_standard_error_handler
    end

    def setup_api_error_handler
      error APIError do
        error = env["sinatra.error"]
        Sentry.capture_exception(error) if ENV["SENTRY_DSN"]
        status error.code
        content_type :json
        { error: error.message }.to_json
      end
    end

    def setup_validation_error_handler
      error ValidationError do
        error = env["sinatra.error"]
        Sentry.capture_exception(error) if ENV["SENTRY_DSN"]
        status 400
        content_type :json
        { error: error.message }.to_json
      end
    end

    def setup_tmdb_error_handler
      error TMDBError do
        error = env["sinatra.error"]
        handle_tmdb_error(error)
      end
    end

    def setup_specific_tmdb_error_handlers
      error TMDBTimeoutError do
        error = env["sinatra.error"]
        handle_tmdb_timeout_error(error)
      end

      error TMDBAuthError do
        error = env["sinatra.error"]
        handle_tmdb_auth_error(error)
      end

      error TMDBRateLimitError do
        error = env["sinatra.error"]
        handle_tmdb_rate_limit_error(error)
      end

      error TMDBNotFoundError do
        error = env["sinatra.error"]
        handle_tmdb_not_found_error(error)
      end

      error TMDBServiceError do
        error = env["sinatra.error"]
        handle_tmdb_service_error(error)
      end
    end

    def setup_cache_error_handlers
      error CacheError do
        error = env["sinatra.error"]
        handle_cache_error(error)
      end
    end

    def setup_not_found_handler
      not_found do
        StructuredLogger.warn("Page Not Found",
                              type: "not_found",
                              request_path: request.path,
                              request_method: request.request_method,
                              user_agent: request.user_agent,
                              referrer: request.referrer)

        status 404
        if request.xhr? || request.content_type&.include?("application/json")
          content_type :json
          { error: "Not found" }.to_json
        else
          send_file File.join(settings.public_folder, "errors", "404.html")
        end
      end
    end

    def setup_standard_error_handler
      error StandardError do
        error = env["sinatra.error"]
        handle_server_error(error)
      end
    end

    private

    def handle_tmdb_error(error)
      # Log TMDB-specific error with circuit breaker context
      StructuredLogger.error("TMDB API Error",
                             type: "tmdb_error",
                             error: error.message,
                             error_class: error.class.name,
                             code: error.respond_to?(:code) ? error.code : 500,
                             request_path: request.path,
                             user_agent: request.user_agent)

      Sentry.capture_exception(error) if defined?(Sentry)

      if request.xhr? || request.content_type&.include?("application/json")
        status error.respond_to?(:code) ? error.code : 500
        content_type :json
        {
          error: "Service temporarily unavailable",
          message: "Please try again later",
          fallback: true
        }.to_json
      else
        status 500
        send_error_page("500.html")
      end
    end

    def handle_not_found_error_response
      StructuredLogger.warn("Page Not Found",
                            type: "not_found",
                            request_path: request.path,
                            request_method: request.request_method,
                            user_agent: request.user_agent,
                            referrer: request.referrer)

      status 404
      if request.xhr? || request.content_type&.include?("application/json")
        content_type :json
        { error: "Not found" }.to_json
      else
        send_error_page("404.html")
      end
    end

    def handle_server_error(error)
      # Log the error with structured logging
      StructuredLogger.error("Server Error",
                             type: "server_error",
                             error: error.message,
                             error_class: error.class.name,
                             backtrace: error.backtrace.first(5),
                             request_path: request.path,
                             request_method: request.request_method,
                             user_agent: request.user_agent)

      # Send to Sentry if available
      Sentry.capture_exception(error) if defined?(Sentry)

      status 500
      if request.xhr? || request.content_type&.include?("application/json")
        content_type :json
        { error: "Internal server error" }.to_json
      else
        send_error_page("500.html")
      end
    end
  end
end
