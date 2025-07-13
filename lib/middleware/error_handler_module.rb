# frozen_string_literal: true

require "net/http"
require_relative "../config/errors"
require_relative "../config/logger"

# Module for wrapping service methods with standardized error handling
module ErrorHandlerModule
  def with_error_handling(context: {})
    yield
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    handle_timeout_error(e, context)
  rescue Net::HTTPError => e
    handle_http_error(e, context)
  rescue StandardError => e
    handle_unexpected_error(e, context)
  end

  def with_tmdb_error_handling(operation_name, context: {}, &block)
    context[:operation] = operation_name
    with_error_handling(context: context, &block)
  rescue TMDBError
    # Let TMDB errors bubble up - they're already properly typed
    raise
  rescue StandardError => e
    # Wrap unexpected errors in TMDBError for consistency
    raise TMDBError.new(500, "TMDB operation failed: #{e.message}")
  end

  def with_cache_error_handling
    yield
  rescue Redis::BaseError => e
    StructuredLogger.error("Redis error", error: e.message, error_class: e.class.name)
    raise CacheConnectionError, "Cache connection failed: #{e.message}"
  rescue JSON::ParserError => e
    StructuredLogger.error("Cache serialization error", error: e.message)
    raise CacheSerializationError, "Failed to serialize cache data: #{e.message}"
  rescue CacheError
    # Let specific cache errors bubble up
    raise
  rescue StandardError => e
    StructuredLogger.error("Unknown cache error", error: e.message, error_class: e.class.name)
    # Don't fail the request on cache errors - degrade gracefully
    nil
  end

  private

  def handle_timeout_error(error, context)
    StructuredLogger.error("Network timeout", error: error.message, context: context)
    raise TMDBTimeoutError, "Request timed out: #{error.message}"
  end

  def handle_http_error(error, context)
    if error.response
      handle_http_error_with_response(error, context)
    else
      StructuredLogger.error("HTTP error without response", error: error.message, context: context)
      raise TMDBError.new(500, "HTTP error: #{error.message}")
    end
  end

  def handle_http_error_with_response(error, context)
    case error.response.code.to_i
    when 401
      StructuredLogger.error("Authentication failed", error: error.message, context: context)
      raise TMDBAuthError, "Authentication failed: #{error.message}"
    when 404
      StructuredLogger.info("Resource not found", error: error.message, context: context)
      raise TMDBNotFoundError, "Resource not found: #{error.message}"
    when 429
      StructuredLogger.warn("Rate limit exceeded", error: error.message, context: context)
      raise TMDBRateLimitError, "Rate limit exceeded: #{error.message}"
    when 503
      StructuredLogger.error("Service unavailable", error: error.message, context: context)
      raise TMDBServiceError, "Service unavailable: #{error.message}"
    else
      StructuredLogger.error("HTTP error", error: error.message, code: error.response.code, context: context)
      raise TMDBError.new(error.response.code.to_i, "HTTP error: #{error.message}")
    end
  end

  def handle_unexpected_error(error, context)
    StructuredLogger.error("Unexpected error", error: error.message, error_class: error.class.name, context: context)
    raise
  end
end
