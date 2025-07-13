# frozen_string_literal: true

require_relative "../services/performance_monitor"

# Health check handler for monitoring application status
class HealthHandler
  def initialize(app)
    @app = app
  end

  def handle
    cache_healthy = cache_healthy?
    tmdb_healthy = tmdb_healthy?
    cb_status = circuit_breaker_status
    perf_summary = performance_summary

    build_response(cache_healthy, tmdb_healthy, cb_status, perf_summary)
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

  def performance_summary
    PerformanceMonitor.performance_summary
  rescue StandardError => e
    { error: "Unable to get performance summary: #{e.message}" }
  end

  def build_response(cache_healthy, tmdb_healthy, circuit_breaker_status, performance_summary)
    overall_healthy = cache_healthy && tmdb_healthy
    status_code = overall_healthy ? 200 : 503

    @app.status status_code
    create_response_data(cache_healthy, tmdb_healthy, circuit_breaker_status, performance_summary,
                         overall_healthy).to_json
  end

  def create_response_data(cache_healthy, tmdb_healthy, circuit_breaker_status, performance_summary, overall_healthy)
    {
      status: overall_healthy ? "healthy" : "degraded",
      timestamp: Time.now.iso8601,
      version: ENV.fetch("APP_VERSION", "unknown"),
      environment: ENV.fetch("RACK_ENV", "development"),
      checks: build_checks(cache_healthy, tmdb_healthy, circuit_breaker_status),
      performance: performance_summary
    }
  end

  def build_checks(cache_healthy, tmdb_healthy, circuit_breaker_status)
    cache_type = production_env? ? "redis" : "memory"

    {
      cache: {
        status: cache_healthy ? "healthy" : "unhealthy",
        type: cache_type
      },
      tmdb_api: {
        status: tmdb_healthy ? "healthy" : "unhealthy",
        circuit_breaker: circuit_breaker_status
      }
    }
  end

  def production_env?
    env = ENV.fetch("RACK_ENV", "development")
    %w[production deployment].include?(env)
  end

  def build_error_response(error)
    @app.status 500
    {
      status: "error",
      timestamp: Time.now.iso8601,
      error: "Health check failed: #{error.message}"
    }.to_json
  end
end
