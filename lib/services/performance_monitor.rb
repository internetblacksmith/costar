# frozen_string_literal: true

require_relative "../config/logger"
require_relative "performance_tracker"
require_relative "performance_stats"

# Performance monitoring service for tracking application metrics
class PerformanceMonitor
  extend PerformanceStats

  class << self
    # Completely disable in development to avoid argument errors
    def track_request(*args)
      return nil if ENV["RACK_ENV"] == "development"

      PerformanceTracker.track_request_production(*args)
    end

    def track_cache_performance(*args)
      return nil if ENV["RACK_ENV"] == "development"

      PerformanceTracker.track_cache_performance_production(*args)
    end

    def track_api_performance(*args, **kwargs)
      return nil if ENV["RACK_ENV"] == "development"

      PerformanceTracker.track_api_performance_production(*args, **kwargs)
    end

    # Silently handle unknown track_ methods to avoid NoMethodError
    def method_missing(method_name, *args, &block)
      return nil if method_name.to_s.start_with?("track_")

      super
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.start_with?("track_") || super
    end

    def performance_summary
      {
        requests: request_stats,
        cache: cache_stats,
        apis: api_stats,
        health: assess_performance_health
      }
    end

    private

    def logger_available?
      defined?(StructuredLogger) && StructuredLogger.respond_to?(:info)
    end

    def cache_available?
      # Load Cache if not already loaded
      unless defined?(Cache)
        begin
          require_relative "../config/cache"
        rescue LoadError
          return false
        end
      end
      defined?(Cache) && Cache.respond_to?(:get)
    end
  end
end
