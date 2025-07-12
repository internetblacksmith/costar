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

    def setup_standard_error_handler
      error StandardError do
        error = env["sinatra.error"]
        Sentry.capture_exception(error) if ENV["SENTRY_DSN"]
        status 500
        content_type :json
        { error: "Internal server error" }.to_json
      end
    end
  end
end
