# frozen_string_literal: true

##
# Parameter object for health check results
#
# Encapsulates all the health check data to avoid passing
# multiple parameters between methods.
#
class HealthCheckResult
  attr_accessor :cache_healthy, :tmdb_healthy, :circuit_breaker_status,
                :throttler_status, :cleaner_status, :performance_summary

  def initialize
    @cache_healthy = false
    @tmdb_healthy = false
    @circuit_breaker_status = {}
    @throttler_status = {}
    @cleaner_status = {}
    @performance_summary = {}
  end

  ##
  # Check if all services are healthy
  #
  # @return [Boolean] True if all critical services are healthy
  #
  def overall_healthy?
    cache_healthy && tmdb_healthy
  end

  ##
  # Get the appropriate HTTP status code
  #
  # @return [Integer] 200 if healthy, 503 if degraded
  #
  def status_code
    overall_healthy? ? 200 : 503
  end

  ##
  # Get the status string
  #
  # @return [String] "healthy" or "degraded"
  #
  def status_string
    overall_healthy? ? "healthy" : "degraded"
  end

  ##
  # Convert to a hash for response building
  #
  # @return [Hash] Health check data as a hash
  #
  def to_h
    {
      cache_healthy: cache_healthy,
      tmdb_healthy: tmdb_healthy,
      circuit_breaker_status: circuit_breaker_status,
      throttler_status: throttler_status,
      cleaner_status: cleaner_status,
      performance_summary: performance_summary,
      overall_healthy: overall_healthy?
    }
  end
end