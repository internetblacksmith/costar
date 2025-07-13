# frozen_string_literal: true

require "retries"
require "net/http"
require "uri"
require "json"
require "timeout"
require_relative "simple_circuit_breaker"
require_relative "../config/logger"
require_relative "../config/errors"
require_relative "performance_monitor"

# Resilient TMDB API client with circuit breaker and retry mechanisms
class ResilientTMDBClient
  # Circuit breaker configuration
  CIRCUIT_BREAKER_THRESHOLD = 5      # Number of failures before opening
  CIRCUIT_BREAKER_TIMEOUT = 60       # Seconds before trying again
  CIRCUIT_BREAKER_EXPECTED_ERRORS = [Net::OpenTimeout, Net::HTTPError, TMDBError].freeze

  # Retry configuration
  MAX_RETRIES = 3
  BASE_DELAY = 0.5  # Base delay in seconds
  MAX_DELAY = 10    # Maximum delay in seconds
  BACKOFF_FACTOR = 2

  def initialize(api_key = nil)
    @api_key = api_key || ENV.fetch("TMDB_API_KEY", "")
    @base_url = "https://api.themoviedb.org/3"
    @test_mode = ENV["RACK_ENV"] == "test"
    @circuit_breaker = SimpleCircuitBreaker.new(
      failure_threshold: CIRCUIT_BREAKER_THRESHOLD,
      recovery_timeout: CIRCUIT_BREAKER_TIMEOUT,
      expected_errors: CIRCUIT_BREAKER_EXPECTED_ERRORS
    )

    configure_timeouts
  end

  def request(endpoint, params = {})
    validate_api_key!

    if @test_mode
      # In test mode, bypass circuit breaker and retries for simpler testing
      make_http_request(endpoint, params)
    else
      @circuit_breaker.call do
        with_retries do
          make_http_request(endpoint, params)
        end
      end
    end
  rescue SimpleCircuitBreaker::CircuitOpenError => e
    handle_circuit_open_error(endpoint, e)
  rescue TMDBError => e
    # TMDBError is expected and should be handled by circuit breaker
    # If we get here, circuit breaker has already recorded the failure and re-raised
    raise e
  rescue StandardError => e
    # Only handle truly unexpected errors (not timeout/HTTP errors which become TMDBError)
    handle_unexpected_error(endpoint, e) unless @test_mode
    raise e if @test_mode
  end

  def healthy?
    @circuit_breaker.state != :open
  end

  def circuit_breaker_status
    {
      state: @circuit_breaker.state.to_s,
      failure_count: @circuit_breaker.failure_count,
      last_failure_time: @circuit_breaker.last_failure_time,
      next_attempt_time: @circuit_breaker.next_attempt_time
    }
  end

  private

  def configure_timeouts
    @timeout_config = {
      open_timeout: 5,     # Connection timeout
      read_timeout: 10,    # Read timeout
      write_timeout: 5     # Write timeout
    }
  end

  def validate_api_key!
    return unless @api_key.nil? || @api_key.empty? || @api_key == "changeme"

    raise TMDBAuthError, "TMDB API key not configured"
  end

  def with_retries
    retries = 0
    begin
      yield
    rescue Net::OpenTimeout, Net::HTTPError, TMDBError => e
      retries += 1
      raise e unless retries < MAX_RETRIES

      sleep_time = [BASE_DELAY * (BACKOFF_FACTOR**(retries - 1)), MAX_DELAY].min
      sleep(sleep_time)
      retry
    end
  end

  def make_http_request(endpoint, params)
    start_time = Time.now
    url = build_url(endpoint, params)

    StructuredLogger.debug("TMDB API Request",
                           type: "api_request",
                           endpoint: endpoint,
                           url: url,
                           circuit_state: @circuit_breaker.state.to_s)

    response = perform_http_request(url)
    duration = (Time.now - start_time) * 1000

    log_successful_request(endpoint, duration, response)
    parse_response(response)
  rescue Net::OpenTimeout => e
    duration = (Time.now - start_time) * 1000
    log_request_error(endpoint, e, duration, "timeout")
    raise TMDBTimeoutError, "Request timeout: #{e.message}"
  rescue Net::HTTPError => e
    duration = (Time.now - start_time) * 1000
    log_request_error(endpoint, e, duration, "http_error")
    handle_http_error(e.response)
  end

  def build_url(endpoint, params)
    query_params = params.merge(api_key: @api_key)
    query_string = URI.encode_www_form(query_params)
    "#{@base_url}/#{endpoint}?#{query_string}"
  end

  def perform_http_request(url)
    uri = URI(url)

    Net::HTTP.start(uri.host, uri.port,
                    use_ssl: uri.scheme == "https",
                    **@timeout_config) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "ActorSync/1.0"
      request["Accept"] = "application/json"

      response = http.request(request)

      # Check for HTTP error status codes
      raise Net::HTTPError.new("HTTP #{response.code}: #{response.message}", response) unless response.is_a?(Net::HTTPSuccess)

      response
    end
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    StructuredLogger.error("TMDB JSON Parse Error",
                           type: "api_error",
                           error: e.message,
                           response_body: response.body[0..500]) # Log first 500 chars
    raise TMDBServiceError, "Invalid JSON response from TMDB"
  end

  def handle_http_error(response)
    case response.code.to_i
    when 401
      raise TMDBAuthError, "API key invalid or expired"
    when 404
      raise TMDBNotFoundError, "Resource not found"
    when 429
      raise TMDBRateLimitError, "Rate limit exceeded"
    when 500, 502, 503, 504
      raise TMDBServiceError, "TMDB service error: #{response.code}"
    else
      raise TMDBError.new(response.code.to_i, "HTTP error: #{response.code} #{response.message}")
    end
  end

  def log_successful_request(endpoint, duration, response)
    StructuredLogger.info("TMDB API Success",
                          type: "api_success",
                          endpoint: endpoint,
                          duration_ms: duration.round(2),
                          response_size: response.body.length,
                          circuit_state: @circuit_breaker.state.to_s)

    # Track API performance
    PerformanceMonitor.track_api_performance("tmdb", endpoint, duration, success: true)
  end

  def log_request_error(endpoint, error, duration, error_type)
    StructuredLogger.error("TMDB API Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error_type: error_type,
                           error: error.message,
                           duration_ms: duration.round(2),
                           circuit_state: @circuit_breaker.state.to_s,
                           failure_count: @circuit_breaker.failure_count)

    # Track API performance for errors
    PerformanceMonitor.track_api_performance("tmdb", endpoint, duration, success: false, error: error)
  end

  def handle_circuit_open_error(endpoint, _error)
    StructuredLogger.warn("TMDB Circuit Breaker Open",
                          type: "circuit_breaker",
                          endpoint: endpoint,
                          state: "open",
                          failure_count: @circuit_breaker.failure_count)

    # Return cached data if available, otherwise return graceful degradation
    provide_fallback_response(endpoint)
  end

  def handle_unexpected_error(endpoint, error)
    StructuredLogger.error("TMDB Unexpected Error",
                           type: "api_error",
                           endpoint: endpoint,
                           error: error.message,
                           error_class: error.class.name,
                           backtrace: error.backtrace.first(3))

    Sentry.capture_exception(error) if defined?(Sentry)

    # Return fallback response for unexpected errors
    provide_fallback_response(endpoint)
  end

  def provide_fallback_response(endpoint)
    # Try to get cached data first
    cache_key = "fallback_#{endpoint.gsub("/", "_")}"
    cached_data = Cache.get(cache_key)

    if cached_data
      StructuredLogger.info("TMDB Fallback Cache Hit",
                            type: "fallback",
                            endpoint: endpoint,
                            source: "cache")
      return cached_data
    end

    # Return appropriate empty response based on endpoint
    fallback_data = generate_fallback_data(endpoint)

    StructuredLogger.info("TMDB Fallback Generated",
                          type: "fallback",
                          endpoint: endpoint,
                          source: "generated")

    fallback_data
  end

  def generate_fallback_data(endpoint)
    case endpoint
    when %r{search/person}
      {
        "results" => [],
        "total_results" => 0,
        "total_pages" => 0,
        "page" => 1
      }
    when %r{person/\d+/movie_credits}
      {
        "cast" => [],
        "crew" => [],
        "id" => 0
      }
    when %r{person/\d+$}
      {
        "id" => 0,
        "name" => "Unknown Actor",
        "biography" => "",
        "profile_path" => nil,
        "known_for_department" => "Acting"
      }
    else
      {
        "error" => "Service temporarily unavailable",
        "fallback" => true
      }
    end
  end
end
