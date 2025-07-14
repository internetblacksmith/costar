# frozen_string_literal: true

require_relative "../services/performance_monitor"
require_relative "../services/api_response_builder"

# Health check handler for monitoring application status
class HealthHandler
  def initialize(app)
    @app = app
    @response_builder = ApiResponseBuilder.new(app)
  end

  def handle
    cache_healthy = cache_healthy?
    tmdb_healthy = tmdb_healthy?
    cb_status = circuit_breaker_status
    throttler_status = throttler_status()
    perf_summary = performance_summary

    build_response(cache_healthy, tmdb_healthy, cb_status, throttler_status, perf_summary)
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

  def performance_summary
    PerformanceMonitor.performance_summary
  rescue StandardError => e
    { error: "Unable to get performance summary: #{e.message}" }
  end

  def build_response(cache_healthy, tmdb_healthy, circuit_breaker_status, throttler_status, performance_summary)
    overall_healthy = cache_healthy && tmdb_healthy
    status_code = overall_healthy ? 200 : 503

    data = create_response_data(cache_healthy, tmdb_healthy, circuit_breaker_status, throttler_status, performance_summary,
                                overall_healthy)

    if overall_healthy
      @response_builder.success(data)
    else
      @response_builder.error("Service degraded", code: status_code, details: data)
    end
  end

  def create_response_data(cache_healthy, tmdb_healthy, circuit_breaker_status, throttler_status, performance_summary, overall_healthy)
    {
      status: overall_healthy ? "healthy" : "degraded",
      timestamp: Time.now.iso8601,
      version: ENV.fetch("APP_VERSION", "unknown"),
      environment: ENV.fetch("RACK_ENV", "development"),
      checks: build_checks(cache_healthy, tmdb_healthy, circuit_breaker_status, throttler_status),
      performance: performance_summary
    }
  end

  def build_checks(cache_healthy, tmdb_healthy, circuit_breaker_status, throttler_status)
    cache_type = production_env? ? "redis" : "memory"

    {
      cache: {
        status: cache_healthy ? "healthy" : "unhealthy",
        type: cache_type
      },
      tmdb_api: {
        status: tmdb_healthy ? "healthy" : "unhealthy",
        circuit_breaker: circuit_breaker_status,
        throttler: throttler_status
      }
    }
  end

  def production_env?
    env = ENV.fetch("RACK_ENV", "development")
    %w[production deployment].include?(env)
  end

  def build_error_response(error)
    @response_builder.error("Health check failed: #{error.message}", code: 500)
  end
end
