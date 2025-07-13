# frozen_string_literal: true

require_relative "../config/logger"

# Production performance tracking functionality
class PerformanceTracker
  class << self
    def track_request_production(env, status, duration_ms)
      return unless logger_available? && cache_available?

      # Track request performance metrics
      metrics = {
        type: "request_performance",
        method: env["REQUEST_METHOD"],
        path: env["PATH_INFO"],
        status: status,
        duration_ms: duration_ms,
        timestamp: Time.now.iso8601
      }

      # Add additional context
      metrics[:user_agent] = env["HTTP_USER_AGENT"]&.slice(0, 100)
      metrics[:remote_ip] = env["REMOTE_ADDR"]
      metrics[:query_string] = env["QUERY_STRING"] unless env["QUERY_STRING"].empty?

      StructuredLogger.info("Request performance", **metrics)

      # Cache performance data for analytics
      cache_performance_data("request", metrics)
    rescue StandardError => e
      StructuredLogger.error("Performance tracking failed",
                             type: "performance_error",
                             operation: "track_request",
                             error: e.message)
    end

    def track_cache_performance_production(operation, key, hit, duration_ms = nil)
      return unless logger_available?

      metrics = {
        type: "cache_performance",
        operation: operation,
        key: key&.slice(0, 100), # Truncate long keys
        hit: hit,
        timestamp: Time.now.iso8601
      }

      metrics[:duration_ms] = duration_ms if duration_ms

      StructuredLogger.info("Cache performance", **metrics)
    rescue StandardError => e
      StructuredLogger.error("Cache performance tracking failed",
                             type: "performance_error",
                             operation: "track_cache",
                             error: e.message)
    end

    def track_api_performance_production(endpoint, duration_ms, status = nil, cache_hit = nil)
      return unless logger_available?

      metrics = {
        type: "api_performance",
        endpoint: endpoint,
        duration_ms: duration_ms,
        timestamp: Time.now.iso8601
      }

      metrics[:status] = status if status
      metrics[:cache_hit] = cache_hit unless cache_hit.nil?

      StructuredLogger.info("API performance", **metrics)
    rescue StandardError => e
      StructuredLogger.error("API performance tracking failed",
                             type: "performance_error",
                             operation: "track_api",
                             error: e.message)
    end

    private

    def logger_available?
      defined?(StructuredLogger)
    end

    def cache_available?
      defined?(Cache) && Cache.respond_to?(:set)
    end

    def cache_performance_data(type, data)
      return unless cache_available?

      key = "performance:#{type}:#{Time.now.strftime("%Y%m%d%H")}"
      existing = Cache.get(key) || []
      existing << data

      # Keep last 100 entries per hour
      existing = existing.last(100) if existing.length > 100

      Cache.set(key, existing, ttl: 3600) # 1 hour
    rescue StandardError
      # Fail silently for caching issues
    end
  end
end
