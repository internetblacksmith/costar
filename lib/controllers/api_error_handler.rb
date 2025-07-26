# frozen_string_literal: true

require_relative "../config/logger"

# Error handling utilities for API controllers
module ApiErrorHandler
  def handle_api_error(error, endpoint)
    StructuredLogger.error("API TMDB Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error: error.message,
                           error_class: error.class.name)
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def handle_unexpected_error(error, endpoint)
    StructuredLogger.error("API Unexpected Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error: error.message,
                           error_class: error.class.name,
                           backtrace: error.backtrace.first(3))
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def handle_api_error_with_context(error, endpoint, context = {})
    StructuredLogger.error("API TMDB Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error: error.message,
                           error_class: error.class.name,
                           **context)
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def handle_unexpected_error_with_context(error, endpoint, context = {})
    StructuredLogger.error("API Unexpected Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error: error.message,
                           error_class: error.class.name,
                           **context)
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def handle_validation_error_with_context(error, endpoint, context = {})
    StructuredLogger.warn("API Validation Error",
                          type: "validation_error",
                          endpoint: endpoint,
                          error: error.message,
                          error_class: error.class.name,
                          **context)
  end
end
