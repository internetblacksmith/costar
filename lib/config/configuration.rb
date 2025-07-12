# frozen_string_literal: true

require "singleton"

# Configuration management for the application
class Configuration
  include Singleton

  def initialize
    setup_environment
    validate_required_env_vars
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
    env == "production" || env == "deployment"
  end

  private

  def setup_environment
    # Only setup environment loading if not in production (where env vars are set by platform)
    return if production?

    # Load from .env file in development
    load_from_dotenv
  end

  def load_from_dotenv
    if File.exist?(".env")
      require "dotenv"
      Dotenv.load
      puts "✅ Environment loaded from .env file"
    else
      puts "⚠️  No .env file found. Make sure environment variables are set."
    end
  end

  def validate_required_env_vars
    required_vars = %w[TMDB_API_KEY]
    missing = required_vars.reject { |var| ENV.fetch(var, nil) }
    raise "Missing required environment variables: #{missing.join(", ")}" if missing.any?
  end
end
