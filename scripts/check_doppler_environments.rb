#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "shellwords"

# Comprehensive Doppler Environment Validation Script for ActorSync
# Checks all Doppler configurations and provides detailed analysis

class DopplerEnvironmentChecker
  ENVIRONMENTS = %w[dev stg prd].freeze

  # Required variables for deployment
  REQUIRED_VARS = {
    "TMDB_API_KEY" => {
      description: "The Movie Database API key for fetching actor and movie data",
      required: true,
      validation: ->(value) { value.length >= 20 && value.match?(/\A[a-f0-9]+\z/) },
      environments: %w[dev stg prd]
    },
    "SESSION_SECRET" => {
      description: "Secret key for session encryption (minimum 64 characters)",
      required: true,
      validation: ->(value) { value.length >= 64 },
      environments: %w[dev stg prd]
    },
    "REDIS_URL" => {
      description: "Redis connection URL for caching",
      required: true,
      validation: ->(value) { value.start_with?("redis://") },
      environments: %w[dev stg prd]
    },
    "RACK_ENV" => {
      description: "Application environment",
      required: true,
      validation: lambda { |value, env|
        case env
        when "dev" then value == "development"
        when "stg" then value == "staging"
        when "prd" then value == "production"
        else false
        end
      },
      environments: %w[dev stg prd]
    },
    "ALLOWED_ORIGINS" => {
      description: "Comma-separated list of allowed CORS origins",
      required: true,
      validation: lambda { |value, env|
        case env
        when "dev" then value.include?("localhost")
        when "stg", "prd" then value.include?("internetblacksmith.dev")
        else false
        end
      },
      environments: %w[dev stg prd]
    },
    "PORT" => {
      description: "Port number for the web server",
      required: true,
      validation: lambda { |value, env|
        case env
        when "dev" then value == "4567"
        when "stg", "prd" then value == "10000"
        else false
        end
      },
      environments: %w[dev stg prd]
    }
  }.freeze

  # Optional but recommended variables
  OPTIONAL_VARS = {
    "SENTRY_DSN" => {
      description: "Sentry error tracking DSN",
      validation: ->(value) { value.start_with?("https://") && value.include?("sentry.io") },
      environments: %w[dev stg prd]
    },
    "POSTHOG_API_KEY" => {
      description: "PostHog analytics API key",
      validation: ->(value) { value.start_with?("phc_") },
      environments: %w[dev stg prd]
    },
    "POSTHOG_HOST" => {
      description: "PostHog host URL",
      validation: ->(value) { value.start_with?("https://") },
      environments: %w[dev stg prd]
    },
    "APP_VERSION" => {
      description: "Application version for tracking",
      validation: ->(value) { value.match?(/^\d+\.\d+\.\d+$/) },
      environments: %w[dev stg prd]
    },
    "SENTRY_TRACES_SAMPLE_RATE" => {
      description: "Sentry performance monitoring sample rate",
      validation: ->(value) { value.to_f.between?(0.0, 1.0) },
      environments: %w[stg prd]
    },
    "CACHE_PREFIX" => {
      description: "Cache key prefix for Redis",
      validation: ->(value) { value.length.positive? },
      environments: %w[dev stg prd]
    },
    "CDN_DOMAIN" => {
      description: "CDN domain for static assets",
      validation: ->(value) { value.include?(".") },
      environments: %w[prd]
    },
    "CDN_PROVIDER" => {
      description: "CDN provider configuration",
      validation: ->(value) { %w[cloudflare aws none].include?(value.downcase) },
      environments: %w[prd]
    }
  }.freeze

  # Production-specific performance optimization variables
  PRODUCTION_VARS = {
    "REDIS_POOL_SIZE" => {
      description: "Redis connection pool size",
      validation: ->(value) { value.to_i.between?(10, 20) },
      environments: %w[prd]
    },
    "REDIS_POOL_TIMEOUT" => {
      description: "Redis connection timeout",
      validation: ->(value) { value.to_i.between?(3, 10) },
      environments: %w[prd]
    },
    "PUMA_THREADS" => {
      description: "Puma thread count",
      validation: ->(value) { value.to_i.between?(3, 10) },
      environments: %w[prd]
    },
    "WEB_CONCURRENCY" => {
      description: "Number of Puma worker processes",
      validation: ->(value) { value.to_i.between?(1, 4) },
      environments: %w[prd]
    }
  }.freeze

  def initialize
    @results = {}
    @overall_status = true
  end

  def check_all_environments
    puts "🔍 Doppler ActorSync Environment Validation"
    puts "=" * 60
    puts

    check_doppler_availability

    ENVIRONMENTS.each do |env|
      puts "#{environment_emoji(env)} #{env.upcase} ENVIRONMENT"
      puts "-" * 40

      secrets = fetch_doppler_secrets(env)
      if secrets
        @results[env] = analyze_environment(env, secrets)
        print_environment_summary(env, @results[env])
      else
        @results[env] = { status: :error, errors: ["Failed to fetch secrets"] }
        puts "❌ Failed to fetch secrets from Doppler"
        @overall_status = false
      end

      puts
    end

    print_overall_summary
    suggest_improvements if @results.any? { |_, result| result[:status] != :success }
  end

  private

  def check_doppler_availability
    stdout, _, status = Open3.capture3("doppler --version")

    unless status.success?
      puts "❌ Doppler CLI not available. Please install it first:"
      puts "   https://docs.doppler.com/docs/install-cli"
      exit 1
    end

    puts "✅ Doppler CLI available (#{stdout.strip})"
    puts
  end

  def fetch_doppler_secrets(env)
    stdout, stderr, status = Open3.capture3("doppler secrets --config #{Shellwords.escape(env)} --json")

    if status.success?
      # Parse the JSON response which contains secrets in Doppler format
      response = JSON.parse(stdout)

      # Extract computed values from Doppler response format
      # Each key has format: {"computed": "value", "computedValueType": {...}, ...}
      secrets = {}
      response.each do |key, data|
        secrets[key] = data["computed"] if data.is_a?(Hash) && data["computed"]
      end

      secrets
    else
      puts "❌ Error fetching secrets for #{env}: #{stderr}"
      nil
    end
  rescue JSON::ParserError => e
    puts "❌ Error parsing Doppler response for #{env}: #{e.message}"
    nil
  end

  def analyze_environment(env, secrets)
    result = {
      status: :success,
      errors: [],
      warnings: [],
      suggestions: [],
      variables: secrets
    }

    # Check required variables
    check_variable_group(REQUIRED_VARS, secrets, env, result, required: true)

    # Check optional variables
    check_variable_group(OPTIONAL_VARS, secrets, env, result, required: false)

    # Check production-specific variables
    check_variable_group(PRODUCTION_VARS, secrets, env, result, required: false) if env == "prd"

    # Check for common issues
    check_common_issues(secrets, env, result)

    # Determine overall status
    result[:status] = :error if result[:errors].any?
    result[:status] = :warning if result[:status] == :success && result[:warnings].any?

    @overall_status = false if result[:status] == :error

    result
  end

  def check_variable_group(var_group, secrets, env, result, required:)
    var_group.each do |var_name, config|
      next unless config[:environments].include?(env)

      value = secrets[var_name]

      if value.nil? || value.empty?
        if required
          result[:errors] << "#{var_name}: MISSING (#{config[:description]})"
          puts "❌ #{var_name}: MISSING"
        else
          result[:warnings] << "#{var_name}: Optional but recommended (#{config[:description]})"
          puts "⚠️  #{var_name}: Not set"
        end
      elsif config[:validation]
        # Handle validation functions that take environment parameter
        validation_result = if config[:validation].arity == 2
                              config[:validation].call(value, env)
                            else
                              config[:validation].call(value)
                            end

        if validation_result
          puts "✅ #{var_name}: OK"
        else
          result[:errors] << "#{var_name}: INVALID (#{config[:description]})"
          puts "❌ #{var_name}: INVALID FORMAT"
        end
      else
        puts "✅ #{var_name}: Set"
      end
    end
  end

  def check_common_issues(secrets, env, result)
    # Check for typos
    if secrets["ALLOWE_ORIGIN"]
      result[:errors] << "ALLOWE_ORIGIN: Typo detected, should be ALLOWED_ORIGINS"
      puts "❌ ALLOWE_ORIGIN: Typo detected"
    end

    # Check PostHog consistency
    posthog_key = secrets["POSTHOG_API_KEY"]
    posthog_host = secrets["POSTHOG_HOST"]

    if posthog_key && !posthog_host
      result[:warnings] << "POSTHOG_API_KEY set but POSTHOG_HOST missing"
      puts "⚠️  PostHog incomplete: missing POSTHOG_HOST"
    elsif posthog_key && posthog_host
      puts "✅ PostHog: Complete configuration"
    else
      puts "➖ PostHog: Not configured (optional)"
    end

    # Environment-specific checks
    case env
    when "dev"
      check_development_config(secrets, result)
    when "prd"
      check_production_config(secrets, result)
    end
  end

  def check_development_config(secrets, result)
    redis_url = secrets["REDIS_URL"]
    return unless redis_url && !redis_url.include?("localhost")

    result[:warnings] << "Development should use local Redis (localhost)"
  end

  def check_production_config(secrets, result)
    redis_url = secrets["REDIS_URL"]
    result[:errors] << "Production should not use localhost Redis" if redis_url&.include?("localhost")

    # Check for performance optimizations
    perf_vars = %w[REDIS_POOL_SIZE REDIS_POOL_TIMEOUT PUMA_THREADS WEB_CONCURRENCY]
    missing_perf = perf_vars.select { |var| secrets[var].nil? || secrets[var].empty? }

    return unless missing_perf.any?

    result[:suggestions] << "Consider adding performance variables: #{missing_perf.join(", ")}"
  end

  def print_environment_summary(_env, result)
    case result[:status]
    when :success
      puts "✅ Status: All configured correctly"
    when :warning
      puts "⚠️  Status: Configured with warnings"
    when :error
      puts "❌ Status: Issues need attention"
    end

    puts "📊 Variables: #{result[:variables].keys.length} total"

    if result[:errors].any?
      puts "🚨 Errors: #{result[:errors].length}"
      result[:errors].each { |error| puts "   • #{error}" }
    end

    if result[:warnings].any?
      puts "⚠️  Warnings: #{result[:warnings].length}"
      result[:warnings].each { |warning| puts "   • #{warning}" }
    end

    return unless result[:suggestions].any?

    puts "💡 Suggestions: #{result[:suggestions].length}"
    result[:suggestions].each { |suggestion| puts "   • #{suggestion}" }
  end

  def print_overall_summary
    puts "🎯 OVERALL SUMMARY"
    puts "=" * 60

    if @overall_status
      puts "🎉 All environments are properly configured!"
      puts "   Your application is ready for deployment across all environments."
    else
      puts "⚠️  Some environments need attention:"

      ENVIRONMENTS.each do |env|
        result = @results[env]
        status_emoji = case result[:status]
                       when :success then "✅"
                       when :warning then "⚠️ "
                       when :error then "❌"
                       else "❓"
                       end

        puts "   #{status_emoji} #{env.upcase}: #{result[:status]}"
      end
    end
    puts
  end

  def suggest_improvements
    puts "🔧 RECOMMENDED ACTIONS"
    puts "=" * 60

    error_envs = @results.select { |_, result| result[:status] == :error }.keys

    if error_envs.any?
      puts "1. Fix critical errors in: #{error_envs.map(&:upcase).join(", ")}"

      error_envs.each do |env|
        puts "\n   #{env.upcase}:"
        @results[env][:errors].each do |error|
          var_name = error.split(":").first

          case var_name
          when "SESSION_SECRET"
            puts "   doppler secrets set SESSION_SECRET=$(openssl rand -hex 32) --config #{env}"
          when "TMDB_API_KEY"
            puts "   doppler secrets set TMDB_API_KEY=your_api_key_here --config #{env}"
          when "REDIS_URL"
            default_redis = env == "dev" ? "redis://localhost:6379" : "redis://your-redis-url"
            puts "   doppler secrets set REDIS_URL=#{default_redis} --config #{env}"
          when "RACK_ENV"
            rack_env = case env
                       when "dev" then "development"
                       when "stg" then "staging"
                       when "prd" then "production"
                       end
            puts "   doppler secrets set RACK_ENV=#{rack_env} --config #{env}"
          when "ALLOWED_ORIGINS"
            origins = env == "dev" ? "localhost:4567,127.0.0.1:4567" : "as.internetblacksmith.dev"
            puts "   doppler secrets set ALLOWED_ORIGINS=#{origins} --config #{env}"
          when "PORT"
            port = env == "dev" ? "4567" : "10000"
            puts "   doppler secrets set PORT=#{port} --config #{env}"
          else
            puts "   # Fix: #{error}"
          end
        end
      end
    end

    puts "\n2. After making changes, verify with:"
    puts "   ruby scripts/check_doppler_environments.rb"
    puts
    puts "3. Deploy to updated environments as needed"
  end

  def environment_emoji(env)
    case env
    when "dev" then "🟢"
    when "stg" then "🟡"
    when "prd" then "🔴"
    else "⚪"
    end
  end
end

# Run the comprehensive check
if __FILE__ == $PROGRAM_NAME
  checker = DopplerEnvironmentChecker.new
  checker.check_all_environments
end
