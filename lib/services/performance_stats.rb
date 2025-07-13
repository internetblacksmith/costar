# frozen_string_literal: true

# Performance statistics calculations and storage
module PerformanceStats
  def request_stats
    return default_request_stats unless cache_available?

    Cache.get("perf_stats:requests") || default_request_stats
  rescue StandardError
    default_request_stats
  end

  def cache_stats
    return default_cache_stats unless cache_available?

    Cache.get("perf_stats:cache") || default_cache_stats
  rescue StandardError
    default_cache_stats
  end

  def api_stats
    return default_api_stats unless cache_available?

    Cache.get("perf_stats:apis") || default_api_stats
  rescue StandardError
    default_api_stats
  end

  def update_performance_stats(metrics)
    stats = request_stats

    # Update counters
    stats[:total_requests] += 1
    stats[:requests_by_status][metrics[:status_code].to_s] =
      (stats[:requests_by_status][metrics[:status_code].to_s] || 0) + 1

    # Update timing statistics
    update_timing_stats(stats[:response_times], metrics[:duration_ms])

    # Track by endpoint
    endpoint_key = "#{metrics[:request_method]} #{metrics[:request_path]}"
    stats[:endpoints][endpoint_key] = (stats[:endpoints][endpoint_key] || 0) + 1

    # Cache updated stats
    Cache.set("perf_stats:requests", stats, 3600) if cache_available? # 1 hour
  end

  def update_cache_stats(metrics)
    stats = cache_stats

    stats[:total_operations] += 1

    if metrics[:cache_hit]
      stats[:hits] += 1
    else
      stats[:misses] += 1
    end

    stats[:hit_rate] = (stats[:hits].to_f / stats[:total_operations] * 100).round(2)

    update_timing_stats(stats[:response_times], metrics[:duration_ms])

    Cache.set("perf_stats:cache", stats, 3600) if cache_available?
  end

  def update_api_stats(metrics)
    stats = api_stats

    service_key = metrics[:service]
    stats[:services][service_key] ||= default_service_stats

    service_stats = stats[:services][service_key]
    service_stats[:total_calls] += 1

    if metrics[:success]
      service_stats[:successful_calls] += 1
    else
      service_stats[:failed_calls] += 1
    end

    service_stats[:success_rate] =
      (service_stats[:successful_calls].to_f / service_stats[:total_calls] * 100).round(2)

    update_timing_stats(service_stats[:response_times], metrics[:duration_ms])

    Cache.set("perf_stats:apis", stats, 3600) if cache_available?
  end

  def assess_performance_health
    req_stats = request_stats
    c_stats = cache_stats
    a_stats = api_stats

    health_score = 100
    issues = []

    # Check average response time
    avg_response = req_stats[:response_times][:average]
    if avg_response && avg_response > 1000
      health_score -= 20
      issues << "High average response time: #{avg_response}ms"
    end

    # Check cache hit rate
    if c_stats[:hit_rate] < 70
      health_score -= 15
      issues << "Low cache hit rate: #{c_stats[:hit_rate]}%"
    end

    # Check API success rates
    a_stats[:services].each do |service, stats|
      if stats[:success_rate] < 95
        health_score -= 10
        issues << "Low #{service} API success rate: #{stats[:success_rate]}%"
      end
    end

    {
      score: [health_score, 0].max,
      status: health_status(health_score),
      issues: issues
    }
  end

  private

  def update_timing_stats(timing_stats, duration_ms)
    timing_stats[:count] += 1
    timing_stats[:total] += duration_ms
    timing_stats[:average] = (timing_stats[:total] / timing_stats[:count]).round(2)

    # Update min/max
    timing_stats[:min] = [timing_stats[:min], duration_ms].compact.min
    timing_stats[:max] = [timing_stats[:max], duration_ms].compact.max
  end

  def health_status(score)
    case score
    when 90..100 then "excellent"
    when 75..89 then "good"
    when 60..74 then "fair"
    when 40..59 then "poor"
    else "critical"
    end
  end

  def default_request_stats
    {
      total_requests: 0,
      requests_by_status: {},
      response_times: default_timing_stats,
      endpoints: {}
    }
  end

  def default_cache_stats
    {
      total_operations: 0,
      hits: 0,
      misses: 0,
      hit_rate: 0.0,
      response_times: default_timing_stats
    }
  end

  def default_api_stats
    {
      services: {}
    }
  end

  def default_service_stats
    {
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      success_rate: 0.0,
      response_times: default_timing_stats
    }
  end

  def default_timing_stats
    {
      count: 0,
      total: 0.0,
      average: 0.0,
      min: nil,
      max: nil
    }
  end
end
