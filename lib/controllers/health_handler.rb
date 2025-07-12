# frozen_string_literal: true

# Health check handler for monitoring application status
class HealthHandler
  def initialize(app)
    @app = app
  end

  def handle
    cache_healthy = cache_healthy?
    tmdb_healthy = check_tmdb_health

    build_response(cache_healthy, tmdb_healthy)
  rescue StandardError => e
    build_error_response(e)
  end

  private

  def cache_healthy?
    Cache.healthy?
  end

  def check_tmdb_health
    @app.settings.tmdb_service.search_actors("test")
    true
  rescue StandardError
    false
  end

  def build_response(cache_healthy, tmdb_healthy)
    overall_healthy = cache_healthy && tmdb_healthy
    status_code = overall_healthy ? 200 : 503

    @app.status status_code
    create_response_data(cache_healthy, tmdb_healthy, overall_healthy).to_json
  end

  def create_response_data(cache_healthy, tmdb_healthy, overall_healthy)
    {
      status: overall_healthy ? "healthy" : "degraded",
      timestamp: Time.now.iso8601,
      version: ENV.fetch("APP_VERSION", "unknown"),
      environment: ENV.fetch("RACK_ENV", "development"),
      checks: build_checks(cache_healthy, tmdb_healthy)
    }
  end

  def build_checks(cache_healthy, tmdb_healthy)
    cache_type = production_env? ? "redis" : "memory"

    {
      cache: {
        status: cache_healthy ? "healthy" : "unhealthy",
        type: cache_type
      },
      tmdb_api: {
        status: tmdb_healthy ? "healthy" : "unhealthy"
      }
    }
  end

  def production_env?
    env = ENV.fetch("RACK_ENV", "development")
    env == "production" || env == "deployment"
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
