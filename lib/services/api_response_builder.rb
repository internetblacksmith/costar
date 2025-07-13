# frozen_string_literal: true

require "erb"
require_relative "../config/logger"

# Centralized response builder for consistent API responses
class ApiResponseBuilder
  def initialize(app)
    @app = app
  end

  # Build a successful JSON response
  #
  # @param data [Object] The response data
  # @param meta [Hash] Optional metadata (pagination, etc.)
  # @return [String] JSON response
  def success(data, meta: {})
    response = {
      status: "success",
      data: data,
      timestamp: Time.now.iso8601
    }

    response[:meta] = meta unless meta.empty?

    @app.content_type :json
    response.to_json
  end

  # Build an error JSON response
  #
  # @param message [String] Error message
  # @param code [Integer] HTTP status code
  # @param details [Hash] Additional error details
  # @return [String] JSON response
  def error(message, code: 400, details: {})
    response = {
      status: "error",
      message: message,
      code: code,
      timestamp: Time.now.iso8601
    }

    response[:details] = details unless details.empty?

    @app.status code
    @app.content_type :json
    response.to_json
  end

  # Build a validation error response
  #
  # @param errors [Array<String>] List of validation errors
  # @param code [Integer] HTTP status code (default: 400)
  # @return [String] JSON response
  def validation_error(errors, code: 400)
    error("Validation failed", code: code, details: { errors: errors })
  end

  # Render an ERB template with error handling
  #
  # @param template [Symbol] Template name
  # @param locals [Hash] Local variables for template
  # @return [String] Rendered HTML
  def render_erb(template, locals = {})
    @app.erb template, locals: locals
  rescue StandardError => e
    StructuredLogger.error("Template rendering failed",
                           template: template,
                           error: e.message,
                           error_class: e.class.name)

    # Return error response if JSON request
    if @app.request.xhr? || @app.request.content_type&.include?("application/json")
      error("Template rendering failed", code: 500)
    else
      @app.status 500
      "An error occurred while rendering the page"
    end
  end

  # Render HTML or JSON based on request type
  #
  # @param html_template [Symbol] Template for HTML response
  # @param json_data [Object] Data for JSON response
  # @param locals [Hash] Local variables for HTML template
  # @return [String] Rendered response
  def render_format(html_template:, json_data:, locals: {})
    if @app.request.xhr? || @app.request.content_type&.include?("application/json")
      success(json_data)
    else
      render_erb(html_template, locals)
    end
  end

  # Handle API errors with consistent formatting
  #
  # @param error [StandardError] The error to handle
  # @return [String] JSON error response
  def handle_api_error(error)
    case error
    when ValidationError
      validation_error(error.message.split(", "))
    when TMDBError
      handle_tmdb_error(error)
    when CacheError
      # Log cache errors but don't fail the request
      StructuredLogger.error("Cache error", error: error.message, error_class: error.class.name)
      nil
    else
      StructuredLogger.error("Unexpected API error",
                             error: error.message,
                             error_class: error.class.name,
                             backtrace: error.backtrace&.first(5))
      error("Internal server error", code: 500)
    end
  end

  private

  def handle_tmdb_error(error)
    code = error.respond_to?(:code) ? error.code : 500

    case error
    when TMDBNotFoundError
      error("Resource not found", code: code)
    when TMDBAuthError
      error("Authentication failed", code: code)
    when TMDBRateLimitError
      error("Rate limit exceeded", code: code, details: { retry_after: 60 })
    when TMDBTimeoutError
      error("Request timed out", code: code, details: { message: "Please try again" })
    when TMDBServiceError
      error("Service temporarily unavailable", code: code, details: { message: "Please try again later" })
    else
      error("External service error", code: code)
    end
  end
end
