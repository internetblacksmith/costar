# frozen_string_literal: true

require_relative "../config/configuration_policy"
require_relative "../config/logger"

# Service for validating configuration at startup and runtime
class ConfigurationValidator
  class ValidationError < StandardError; end

  REQUIRED_ENV_VARS = %w[TMDB_API_KEY].freeze

  OPTIONAL_ENV_VARS = {
    # Redis configuration
    "REDIS_URL" => "Using memory cache instead of Redis",
    "REDIS_POOL_SIZE" => "Using default pool size (10)",
    "REDIS_POOL_TIMEOUT" => "Using default timeout (5s)",

    # Monitoring
    "SENTRY_DSN" => "Error tracking will be disabled",
    "POSTHOG_API_KEY" => "Analytics tracking will be disabled",

    # Security
    "ALLOWED_ORIGINS" => "CORS will allow all origins in development",

    # Performance
    "CDN_BASE_URL" => "Using default asset URLs"
  }.freeze

  class << self
    def validate!
      results = {
        errors: [],
        warnings: [],
        info: []
      }

      # Check required environment variables
      validate_required_vars(results)

      # Check optional environment variables
      validate_optional_vars(results)

      # Validate configuration policies
      validate_policies(results)

      # Check system requirements
      validate_system_requirements(results)

      # Log results
      log_validation_results(results)

      # Fail fast in development if critical errors
      raise ValidationError, "Configuration validation failed:\n#{results[:errors].join("\n")}" if results[:errors].any? && development?

      results
    end

    def validate_runtime_config(config)
      errors = []

      # Validate API configuration
      validate_api_config(config[:api], errors) if config[:api]

      # Validate cache configuration
      validate_cache_config(config[:cache], errors) if config[:cache]

      # Validate security configuration
      validate_security_config(config[:security], errors) if config[:security]

      errors
    end

    private

    def validate_required_vars(results)
      REQUIRED_ENV_VARS.each do |var|
        value = ENV.fetch(var, nil)

        if value.nil? || value.empty?
          results[:errors] << "❌ Required: #{var} is not set"
        elsif var == "TMDB_API_KEY" && value == "changeme"
          results[:errors] << "❌ Required: #{var} is still set to default value"
        else
          results[:info] << "✅ #{var} is configured"
        end
      end
    end

    def validate_optional_vars(results)
      OPTIONAL_ENV_VARS.each do |var, message|
        if ENV[var].nil? || ENV[var].empty?
          results[:warnings] << "⚠️  #{var} not set - #{message}"
        else
          results[:info] << "✅ #{var} is configured"
        end
      end
    end

    def validate_policies(results)
      # Validate cache policies
      cache_ttl = ConfigurationPolicy.get(:cache, :ttl)
      results[:warnings] << "⚠️  Cache TTL (#{cache_ttl}s) is very short, may impact performance" if cache_ttl < 120

      # Validate rate limiting policies
      max_requests = ConfigurationPolicy.get(:rate_limiting, :max_requests)
      window_size = ConfigurationPolicy.get(:rate_limiting, :window_size)
      rate = max_requests.to_f / window_size

      results[:warnings] << "⚠️  Rate limit (#{rate} req/s) may be too high for TMDB API" if rate > 10

      # Validate API policies
      timeout = ConfigurationPolicy.get(:api, :timeout)
      return unless timeout < 5

      results[:warnings] << "⚠️  API timeout (#{timeout}s) may be too short for slow connections"
    end

    def validate_system_requirements(results)
      # Check Ruby version
      ruby_version = RUBY_VERSION
      if Gem::Version.new(ruby_version) < Gem::Version.new("3.0.0")
        results[:warnings] << "⚠️  Ruby #{ruby_version} is older than recommended (3.0+)"
      else
        results[:info] << "✅ Ruby #{ruby_version}"
      end

      # Check for production readiness
      return unless production?

      validate_production_requirements(results)
    end

    def validate_production_requirements(results)
      # Redis is required in production
      results[:errors] << "❌ REDIS_URL is required in production" if ENV["REDIS_URL"].nil?

      # Error tracking is strongly recommended
      results[:warnings] << "⚠️  SENTRY_DSN not set - Error tracking disabled in production" if ENV["SENTRY_DSN"].nil?

      # CORS should be configured
      allowed_origins = ConfigurationPolicy.get(:security, :allowed_origins)
      return unless allowed_origins.empty?

      results[:errors] << "❌ ALLOWED_ORIGINS must be configured in production"
    end

    def validate_api_config(api_config, errors)
      # Validate timeout
      errors << "API timeout cannot exceed 30 seconds" if api_config[:timeout] && api_config[:timeout] > 30

      # Validate retry configuration
      return unless api_config[:max_retries] && api_config[:max_retries] > 5

      errors << "API max retries cannot exceed 5"
    end

    def validate_cache_config(cache_config, errors)
      # Validate TTL ranges
      errors << "Cache TTL cannot exceed 24 hours" if cache_config[:ttl] && cache_config[:ttl] > 86_400

      # Validate cleanup configuration
      return unless cache_config[:cleanup_interval] && cache_config[:cleanup_interval] < 60

      errors << "Cache cleanup interval must be at least 60 seconds"
    end

    def validate_security_config(security_config, errors)
      # Validate input length limits
      max_length = security_config[:max_input_length]
      errors << "Max input length must be between 50 and 500 characters" if max_length && (max_length < 50 || max_length > 500)

      # Validate allowed origins
      return unless security_config[:allowed_origins]

      validate_origins(security_config[:allowed_origins], errors)
    end

    def validate_origins(origins, errors)
      origins.each do |origin|
        errors << "Invalid origin format: #{origin}" unless origin =~ %r{\Ahttps?://[\w\-.]+(:\d+)?\z}
      end
    end

    def log_validation_results(results)
      # Log errors
      if results[:errors].any?
        StructuredLogger.error("Configuration validation errors",
                               errors: results[:errors])
      end

      # Log warnings
      if results[:warnings].any?
        StructuredLogger.warn("Configuration warnings",
                              warnings: results[:warnings])
      end

      # Log info in development
      if development? && results[:info].any?
        StructuredLogger.info("Configuration status",
                              info: results[:info])
      end

      # Print to console in development
      return unless development?

      print_validation_results(results)
    end

    def print_validation_results(results)
      puts "\n🔐 Configuration Validation Results:\n"

      if results[:errors].any?
        puts "\n❌ ERRORS:"
        results[:errors].each { |error| puts "   #{error}" }
      end

      if results[:warnings].any?
        puts "\n⚠️  WARNINGS:"
        results[:warnings].each { |warning| puts "   #{warning}" }
      end

      if development? && results[:info].any?
        puts "\n✅ CONFIGURED:"
        results[:info].each { |info| puts "   #{info}" }
      end

      puts "\n"
    end

    def development?
      ENV.fetch("RACK_ENV", "development") == "development"
    end

    def production?
      ENV.fetch("RACK_ENV", "development") == "production"
    end
  end
end
