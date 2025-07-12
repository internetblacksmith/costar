# frozen_string_literal: true

# Error handling controller for application-wide error management
module ErrorHandler
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def setup_error_handlers
      setup_api_error_handler
      setup_validation_error_handler
      setup_tmdb_error_handler
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

    def setup_not_found_handler
      not_found do
        handle_not_found_error_response
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
        user_agent: request.user_agent
      )
      
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
        send_error_page('500.html')
      end
    end

    def handle_not_found_error_response
      StructuredLogger.warn("Page Not Found", 
        type: "not_found",
        request_path: request.path,
        request_method: request.request_method,
        user_agent: request.user_agent,
        referrer: request.referrer
      )
      
      if request.xhr? || request.content_type&.include?("application/json")
        status 404
        content_type :json
        { error: "Not found" }.to_json
      else
        status 404
        send_error_page('404.html')
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
        user_agent: request.user_agent
      )
      
      # Send to Sentry if available
      Sentry.capture_exception(error) if defined?(Sentry)
      
      if request.xhr? || request.content_type&.include?("application/json")
        status 500
        content_type :json
        { error: "Internal server error" }.to_json
      else
        status 500
        send_error_page('500.html')
      end
    end

    def send_error_page(filename)
      error_file = File.join(settings.public_folder, 'errors', filename)
      if File.exist?(error_file)
        send_file error_file, type: 'text/html'
      else
        "An error occurred"
      end
    end
  end
end
