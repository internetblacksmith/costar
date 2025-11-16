# frozen_string_literal: true

require_relative "error_handler_tmdb"
require_relative "../services/api_response_builder"
require_relative "../config/request_context"

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
        response_builder = ApiResponseBuilder.new(self)
        halt response_builder.error(error.message, code: error.code)
      end
    end

    def setup_validation_error_handler
      error ValidationError do
        error = env["sinatra.error"]
        Sentry.capture_exception(error) if ENV["SENTRY_DSN"]
        response_builder = ApiResponseBuilder.new(self)
        halt response_builder.validation_error(error.message.split(", "))
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
        # Use RequestContext if available
        if RequestContext.current
          RequestContext.current.add_metadata(:error_type, "not_found")
          RequestContext.current.log_event("Page Not Found",
                                           type: "not_found",
                                           referrer: request.referrer)
        else
          StructuredLogger.warn("Page Not Found",
                                type: "not_found",
                                request_path: request.path,
                                request_method: request.request_method,
                                user_agent: request.user_agent,
                                referrer: request.referrer)
        end

        if request.xhr? || request.content_type&.include?("application/json")
          response_builder = ApiResponseBuilder.new(self)
          halt response_builder.error("Not found", code: 404)
        else
          status 404
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
      if RequestContext.current
        RequestContext.current.add_metadata(:error_type, "tmdb_error")
        RequestContext.current.add_metadata(:error_code, error.respond_to?(:code) ? error.code : 500)
        RequestContext.current.log_error("TMDB API Error", error,
                                         type: "tmdb_error",
                                         code: error.respond_to?(:code) ? error.code : 500)
      else
        StructuredLogger.error("TMDB API Error",
                               type: "tmdb_error",
                               error: error.message,
                               error_class: error.class.name,
                               code: error.respond_to?(:code) ? error.code : 500,
                               request_path: request.path,
                               user_agent: request.user_agent)
      end

      Sentry.capture_exception(error) if defined?(Sentry)

      if request.xhr? || request.content_type&.include?("application/json")
        response_builder = ApiResponseBuilder.new(self)
        code = error.respond_to?(:code) ? error.code : 500
        halt response_builder.error("Service temporarily unavailable",
                                    code: code,
                                    details: { message: "Please try again later", fallback: true })
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

      if request.xhr? || request.content_type&.include?("application/json")
        response_builder = ApiResponseBuilder.new(self)
        halt response_builder.error("Not found", code: 404)
      else
        status 404
        send_error_page("404.html")
      end
    end

    def handle_server_error(error)
      # Log the error with structured logging
      if RequestContext.current
        RequestContext.current.add_metadata(:error_type, "server_error")
        RequestContext.current.add_metadata(:status, 500)
        RequestContext.current.log_error("Server Error", error,
                                         type: "server_error")
      else
        StructuredLogger.error("Server Error",
                               type: "server_error",
                               error: error.message,
                               error_class: error.class.name,
                               backtrace: error.backtrace.first(5),
                               request_path: request.path,
                               request_method: request.request_method,
                               user_agent: request.user_agent)
      end

      # Send to Sentry if available
      Sentry.capture_exception(error) if defined?(Sentry)

      if request.xhr? || request.content_type&.include?("application/json")
        response_builder = ApiResponseBuilder.new(self)
        halt response_builder.error("Internal server error", code: 500)
      else
        status 500
        send_error_page("500.html")
      end
    end
  end
end
