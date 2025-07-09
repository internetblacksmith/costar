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
    ENV["POSTHOG_API_KEY"]
  end

  def posthog_host
    ENV.fetch("POSTHOG_HOST", "https://app.posthog.com")
  end

  def development?
    ENV.fetch("RACK_ENV", "development") == "development"
  end

  def production?
    ENV.fetch("RACK_ENV", "development") == "production"
  end

  private

  def setup_environment
    # Only setup environment loading if not in production (where env vars are set by platform)
    return if production?

    # Try to load from Doppler CLI if available
    if doppler_available?
      puts "Loading secrets from Doppler..."
      load_from_doppler
    else
      puts "Doppler not available, loading from .env file..."
      load_from_dotenv
    end
  end

  def doppler_available?
    system("which doppler > /dev/null 2>&1") && File.exist?(".doppler")
  end

  def load_from_doppler
    begin
      # Use Doppler CLI to load environment variables
      doppler_output = `doppler secrets download --no-file --format env 2>/dev/null`
      
      if $?.success?
        doppler_output.each_line do |line|
          next if line.strip.empty? || line.start_with?('#')
          
          key, value = line.strip.split('=', 2)
          ENV[key] = value.gsub(/^"|"$/, '') if key && value && !ENV[key]
        end
        puts "✅ Secrets loaded from Doppler"
      else
        puts "⚠️  Failed to load from Doppler, falling back to .env file"
        load_from_dotenv
      end
    rescue StandardError => e
      puts "⚠️  Error loading from Doppler: #{e.message}"
      puts "Falling back to .env file"
      load_from_dotenv
    end
  end

  def load_from_dotenv
    if File.exist?('.env')
      require 'dotenv'
      Dotenv.load
      puts "✅ Environment loaded from .env file"
    else
      puts "⚠️  No .env file found. Make sure environment variables are set."
    end
  end

  def validate_required_env_vars
    required_vars = %w[TMDB_API_KEY]
    missing = required_vars.reject { |var| ENV[var] }
    raise "Missing required environment variables: #{missing.join(', ')}" if missing.any?
  end
end