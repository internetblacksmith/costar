# frozen_string_literal: true

require "singleton"

# Configuration management for the application
class Configuration
  include Singleton

  def initialize
    setup_environment
    @validation_result = validate_required_env_vars

    # Fail fast in development if critical vars are missing
    return unless development? && !@validation_result[:valid]

    puts "\n🛑 STOPPING: Critical environment variables are missing."
    puts "   Please configure your environment before starting the application."
    exit(1)
  end

  def tmdb_api_key
    ENV.fetch("TMDB_API_KEY")
  end

  def posthog_api_key
    ENV.fetch("POSTHOG_API_KEY", nil)
  end

  def posthog_host
    ENV.fetch("POSTHOG_HOST", "https://app.posthog.com")
  end

  def development?
    ENV.fetch("RACK_ENV", "development") == "development"
  end

  def production?
    env = ENV.fetch("RACK_ENV", "development")
    %w[production deployment].include?(env)
  end

  private

  def setup_environment
    # Only setup environment loading if not in production (where env vars are set by platform)
    return if production?

    # Load from .env file in development
    load_from_dotenv
  end

  def load_from_dotenv
    # Try Doppler first (preferred for local development)
    if doppler_available?
      puts "🔐 Using Doppler for environment variables"
      return
    end

    # Fallback to .env file
    if File.exist?(".env")
      require "dotenv"
      Dotenv.load
      puts "✅ Environment loaded from .env file (consider switching to Doppler)"
    else
      puts "⚠️  No .env file found and Doppler not available."
      puts "   Install Doppler CLI: https://docs.doppler.com/docs/install-cli"
      puts "   Or create a .env file with required variables."
    end
  end

  def doppler_available?
    # Check if doppler command is available and configured for this project
    system("doppler secrets --silent > /dev/null 2>&1")
  end

  def validate_required_env_vars
    errors = validate_critical_vars
    warnings = validate_optional_vars + validate_critical_var_warnings

    print_validation_results(errors, warnings)
    { errors: errors, warnings: warnings, valid: errors.empty? }
  end

  def validate_critical_vars
    errors = []
    %w[TMDB_API_KEY].each do |var|
      value = ENV.fetch(var, nil)
      # Allow test environment to skip required variables
      next if ENV["RACK_ENV"] == "test" && var == "TMDB_API_KEY" && missing_or_invalid?(value)

      errors << "❌ #{var} is missing or not properly configured" if missing_or_invalid?(value)
    end
    errors
  end

  def validate_critical_var_warnings
    warnings = []
    %w[TMDB_API_KEY].each do |var|
      value = ENV.fetch(var, nil)
      next if missing_or_invalid?(value)

      warnings << "⚠️  #{var} seems too short (#{value.length} chars) - verify it's correct" if value.length < 10
    end
    warnings
  end

  def missing_or_invalid?(value)
    value.nil? || value.empty? || value == "changeme"
  end

  def validate_optional_vars
    warnings = []
    optional_vars_config.each do |var, consequence|
      value = ENV.fetch(var, nil)
      warnings << "⚠️  #{var} not set - #{consequence}" if value.nil? || value.empty?
    end
    warnings
  end

  def optional_vars_config
    {
      "POSTHOG_API_KEY" => "Analytics tracking will be disabled",
      "SENTRY_DSN" => "Error tracking will be disabled",
      "REDIS_URL" => "Will use memory cache instead of Redis"
    }
  end

  def print_validation_results(errors, warnings)
    print_errors(errors) unless errors.empty?
    print_warnings(warnings) unless warnings.empty?
    print_success_message if errors.empty? && warnings.empty?
  end

  def print_errors(errors)
    puts "\n🚨 CRITICAL CONFIGURATION ERRORS:"
    errors.each { |error| puts "   #{error}" }
    puts "\n   The application may not work correctly!"
    puts "   Please check your environment configuration.\n"
  end

  def print_warnings(warnings)
    puts "\n⚠️  CONFIGURATION WARNINGS:"
    warnings.each { |warning| puts "   #{warning}" }
    puts ""
  end

  def print_success_message
    puts "✅ All required environment variables are configured"
  end
end
