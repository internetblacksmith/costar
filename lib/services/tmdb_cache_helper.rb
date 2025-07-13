# frozen_string_literal: true

require_relative "../config/cache"
require_relative "../config/logger"

# Helper module for TMDB service caching operations
module TMDBCacheHelper
  private

  def get_cached_result(cache_key)
    start_time = Time.now
    cached_result = Cache.get(cache_key)

    if cached_result
      duration_ms = (Time.now - start_time) * 1000
      StructuredLogger.log_cache_operation("hit", cache_key, hit: true, duration_ms: duration_ms)
      return cached_result
    end

    nil
  end

  def cache_result(cache_key, result, ttl)
    Cache.set(cache_key, result, ttl)
  end

  def log_cache_miss_and_api_success(cache_key, start_time, endpoint, api_duration)
    total_duration = (Time.now - start_time) * 1000
    StructuredLogger.log_cache_operation("miss", cache_key, hit: false, duration_ms: total_duration)
    StructuredLogger.log_api_call("tmdb", endpoint, api_duration, success: true)
  end
end
