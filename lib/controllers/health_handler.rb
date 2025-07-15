# frozen_string_literal: true

require_relative "../services/performance_monitor"
require_relative "../services/api_response_builder"
require_relative "../config/configuration_policy"
require_relative "../config/cache"
require_relative "../config/service_container"
require_relative "../dto/health_check_result"

# Health check handler for monitoring application status
class HealthHandler
  def initialize(app)
    @app = app
    @response_builder = ApiResponseBuilder.new(app)
  end

  def handle
    result = HealthCheckResult.new
    
    # Collect health status from all components
    result.cache_healthy = cache_healthy?
    result.tmdb_healthy = tmdb_healthy?
    result.circuit_breaker_status = circuit_breaker_status
    result.throttler_status = throttler_status()
    result.cleaner_status = cache_cleaner_status
    result.performance_summary = performance_summary

    build_response(result)
  rescue StandardError => e
    build_error_response(e)
  end

  private

  def cache_healthy?
    Cache.healthy?
  end

  def tmdb_healthy?
    @app.settings.tmdb_service.healthy?
  end

  def circuit_breaker_status
    @app.settings.tmdb_service.circuit_breaker_status
  rescue StandardError
    { state: "unknown", error: "Unable to get circuit breaker status" }
  end

  def throttler_status
    @app.settings.tmdb_service.throttler_status
  rescue StandardError => e
    { error: "Unable to get throttler status: #{e.message}" }
  end

  def cache_cleaner_status
    cleaner = ServiceContainer.get(:cache_cleaner)
    cleaner.status
  rescue StandardError => e
    { error: "Unable to get cache cleaner status: #{e.message}" }
  end

  def performance_summary
    PerformanceMonitor.performance_summary
  rescue StandardError => e
    { error: "Unable to get performance summary: #{e.message}" }
  end

  def build_response(result)
    data = create_response_data(result)

    if result.overall_healthy?
      @response_builder.success(data)
    else
      @response_builder.error("Service degraded", code: result.status_code, details: data)
    end
  end

  def create_response_data(result)
    {
      status: result.status_string,
      timestamp: Time.now.iso8601,
      version: ENV.fetch("APP_VERSION", "unknown"),
      environment: ENV.fetch("RACK_ENV", "development"),
      checks: build_checks(result),
      configuration: configuration_summary,
      performance: result.performance_summary
    }
  end

  def build_checks(result)
    cache_type = production_env? ? "redis" : "memory"

    {
      cache: {
        status: result.cache_healthy ? "healthy" : "unhealthy",
        type: cache_type,
        cleaner: result.cleaner_status
      },
      tmdb_api: {
        status: result.tmdb_healthy ? "healthy" : "unhealthy",
        circuit_breaker: result.circuit_breaker_status,
        throttler: result.throttler_status
      }
    }
  end

  def production_env?
    env = ENV.fetch("RACK_ENV", "development")
    %w[production deployment].include?(env)
  end

  def configuration_summary
    {
      cache: {
        ttl: ConfigurationPolicy.get(:cache, :ttl),
        cleanup_interval: ConfigurationPolicy.get(:cache, :cleanup_interval),
        batch_size: ConfigurationPolicy.get(:cache, :batch_size)
      },
      rate_limiting: {
        max_requests: ConfigurationPolicy.get(:rate_limiting, :max_requests),
        window_size: ConfigurationPolicy.get(:rate_limiting, :window_size)
      },
      api: {
        timeout: ConfigurationPolicy.get(:api, :timeout),
        max_retries: ConfigurationPolicy.get(:api, :max_retries),
        circuit_breaker_threshold: ConfigurationPolicy.get(:api, :circuit_breaker_threshold)
      }
    }
  rescue StandardError => e
    { error: "Unable to get configuration: #{e.message}" }
  end

  def build_error_response(error)
    @response_builder.error("Health check failed: #{error.message}", code: 500)
  end
end
