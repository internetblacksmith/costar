#!/usr/bin/env ruby
# frozen_string_literal: true

# Environment Variable Validation Script for ActorSync
# Checks if all required environment variables are properly configured

class EnvironmentChecker
  # Required variables for production deployment
  REQUIRED_VARS = {
    "TMDB_API_KEY" => {
      description: "The Movie Database API key for fetching actor and movie data",
      required: true,
      validation: ->(value) { value.length >= 20 && value.match?(/\A[a-f0-9]+\z/) }
    },
    "SESSION_SECRET" => {
      description: "Secret key for session encryption (minimum 64 characters)",
      required: true,
      validation: ->(value) { value.length >= 64 }
    },
    "REDIS_URL" => {
      description: "Redis connection URL for caching",
      required: true,
      validation: ->(value) { value.start_with?("redis://") }
    },
    "RACK_ENV" => {
      description: "Application environment (should be 'production')",
      required: true,
      validation: ->(value) { value == "production" }
    },
    "SENTRY_DSN" => {
      description: "Sentry error tracking DSN",
      required: false,
      validation: ->(value) { value.start_with?("https://") && value.include?("sentry.io") }
    },
    "POSTHOG_API_KEY" => {
      description: "PostHog analytics API key",
      required: false,
      validation: ->(value) { value.start_with?("phc_") }
    },
    "POSTHOG_HOST" => {
      description: "PostHog host URL",
      required: false,
      validation: ->(value) { value.start_with?("https://") }
    },
    "ALLOWED_ORIGINS" => {
      description: "Comma-separated list of allowed CORS origins",
      required: false,
      validation: ->(value) { value.include?("internetblacksmith.dev") }
    }
  }.freeze

  # Optional variables that enhance functionality
  OPTIONAL_VARS = {
    "APP_VERSION" => "Application version for tracking",
    "PORT" => "Port number for the web server",
    "REDIS_POOL_SIZE" => "Redis connection pool size",
    "REDIS_POOL_TIMEOUT" => "Redis connection timeout",
    "CDN_DOMAIN" => "CDN domain for static assets",
    "WEB_CONCURRENCY" => "Number of Puma worker processes"
  }.freeze

  def initialize(env_source = "current")
    @env_source = env_source
    @errors = []
    @warnings = []
    @suggestions = []
  end

  def check_environment
    puts "🔍 Checking ActorSync Environment Variables"
    puts "=" * 50
    puts

    check_required_variables
    check_optional_variables
    check_for_common_issues

    print_summary
  end

  private

  def check_required_variables
    puts "📋 Required Variables:"
    puts

    REQUIRED_VARS.each do |var_name, config|
      value = get_env_value(var_name)

      if value.nil? || value.empty?
        if config[:required]
          @errors << "❌ #{var_name}: MISSING (#{config[:description]})"
          puts "❌ #{var_name}: MISSING"
        else
          @warnings << "⚠️  #{var_name}: Optional but recommended (#{config[:description]})"
          puts "⚠️  #{var_name}: Optional"
        end
      elsif config[:validation] && !config[:validation].call(value)
        @errors << "❌ #{var_name}: INVALID FORMAT (#{config[:description]})"
        puts "❌ #{var_name}: INVALID FORMAT"
      else
        puts "✅ #{var_name}: OK"
      end
    end
    puts
  end

  def check_optional_variables
    puts "🔧 Optional Variables:"
    puts

    OPTIONAL_VARS.each do |var_name, description|
      value = get_env_value(var_name)

      if value.nil? || value.empty?
        puts "➖ #{var_name}: Not set (#{description})"
      else
        puts "✅ #{var_name}: Set"
      end
    end
    puts
  end

  def check_for_common_issues
    puts "🔍 Common Issues Check:"
    puts

    # Check for typos in variable names
    typo_check = get_env_value("ALLOWE_ORIGIN")
    if typo_check
      @errors << "❌ ALLOWE_ORIGIN: Should be ALLOWED_ORIGINS (typo detected)"
      puts "❌ Found ALLOWE_ORIGIN - should be ALLOWED_ORIGINS (typo)"
    end

    # Check Redis connectivity (basic URL validation)
    redis_url = get_env_value("REDIS_URL")
    if redis_url && !redis_url.include?("redis://")
      @errors << "❌ REDIS_URL: Invalid format, should start with redis://"
      puts "❌ REDIS_URL: Invalid format"
    else
      puts "✅ REDIS_URL: Format looks correct"
    end

    # Check PostHog configuration consistency
    posthog_key = get_env_value("POSTHOG_API_KEY")
    posthog_host = get_env_value("POSTHOG_HOST")

    if posthog_key && !posthog_host
      @warnings << "⚠️  POSTHOG_API_KEY set but POSTHOG_HOST missing"
      puts "⚠️  POSTHOG_API_KEY set but POSTHOG_HOST missing"
    elsif posthog_key && posthog_host
      puts "✅ PostHog: Complete configuration"
    else
      puts "➖ PostHog: Not configured (optional)"
    end

    puts
  end

  def print_summary
    puts "📊 SUMMARY"
    puts "=" * 50

    if @errors.empty? && @warnings.empty?
      puts "🎉 All environment variables are properly configured!"
      puts "   Your application should deploy successfully."
    else
      puts "Issues found:"
      puts

      if @errors.any?
        puts "🚨 CRITICAL ERRORS (must fix):"
        @errors.each { |error| puts "   #{error}" }
        puts
      end

      if @warnings.any?
        puts "⚠️  WARNINGS (should fix):"
        @warnings.each { |warning| puts "   #{warning}" }
        puts
      end
    end

    print_fixes_needed if @errors.any?
  end

  def print_fixes_needed
    puts "🔧 FIXES NEEDED:"
    puts

    if @errors.any? { |e| e.include?("SESSION_SECRET") }
      puts "1. Add SESSION_SECRET to Doppler:"
      puts "   doppler secrets set SESSION_SECRET=$(openssl rand -hex 32) --config prd"
      puts
    end

    if @errors.any? { |e| e.include?("ALLOWE_ORIGIN") }
      puts "2. Fix ALLOWED_ORIGINS typo in Doppler:"
      puts "   doppler secrets set ALLOWED_ORIGINS=as.internetblacksmith.dev --config prd"
      puts "   doppler secrets delete ALLOWE_ORIGIN --config prd"
      puts
    end

    puts "3. After making changes, restart your Render deployment"
    puts "   to pick up the new environment variables."
  end

  def get_env_value(var_name)
    ENV.fetch(var_name, nil)
  end
end

# Run the check
if __FILE__ == $PROGRAM_NAME
  checker = EnvironmentChecker.new
  checker.check_environment
end
