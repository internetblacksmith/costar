# frozen_string_literal: true

# Dual-mode VCR configuration for Cucumber tests
#
# Modes:
# 1. CI/CD Mode (default): Uses pre-recorded cassettes only
# 2. Development Mode: Can make real API calls and record new cassettes
#
# Usage:
# - CI/CD: No configuration needed, uses cassettes by default
# - Development: Set VCR_RECORD_MODE=new_episodes to record missing interactions
# - Development: Set VCR_ALLOW_HTTP=true to allow real HTTP when no cassette

module VCRConfig
  class << self
    def configure!
      mode = detect_mode
      puts "VCR Mode: #{mode}" if ENV["DEBUG"]

      case mode
      when :ci
        configure_ci_mode
      when :development
        configure_development_mode
      else
        raise "Unknown VCR mode: #{mode}"
      end
    end

    private

    def detect_mode
      # CI/CD environments
      return :ci if ENV["CI"] == "true"
      return :ci if ENV["RACK_ENV"] == "production"
      return :ci if ENV["VCR_MODE"] == "ci"

      # Development mode
      :development
    end

    def configure_ci_mode
      # CI mode: Strictly use cassettes, fail if missing
      ENV["VCR_RECORD_MODE"] = "none"
      ENV["VCR_ALLOW_HTTP"] = "false"

      # Ensure cassettes exist
      cassette_dir = File.expand_path("../../fixtures/vcr_cassettes", __dir__)
      unless Dir.exist?(cassette_dir)
        raise "VCR cassette directory not found: #{cassette_dir}. " \
              "Please ensure cassettes are committed to the repository."
      end

      return unless Dir.empty?(cassette_dir)

      raise "VCR cassette directory is empty. " \
            "Please record cassettes in development mode first."
    end

    def configure_development_mode
      # Development mode: Allow recording new cassettes
      ENV["VCR_RECORD_MODE"] ||= "once"
      ENV["VCR_ALLOW_HTTP"] ||= "false"

      # Create cassette directory if it doesn't exist
      cassette_dir = File.expand_path("../../fixtures/vcr_cassettes", __dir__)
      FileUtils.mkdir_p(cassette_dir)

      # Show helpful message
      if ENV["VCR_RECORD_MODE"] == "new_episodes"
        puts "\n📼 VCR Development Mode: Recording new API interactions"
        puts "   Existing cassettes will be preserved"
        puts "   New interactions will be recorded"
      elsif ENV["VCR_RECORD_MODE"] == "all"
        puts "\n📼 VCR Development Mode: Re-recording ALL interactions"
        puts "   ⚠️  Warning: This will overwrite existing cassettes!"
      else
        puts "\n📼 VCR Development Mode: Using existing cassettes"
        puts "   Set VCR_RECORD_MODE=new_episodes to record missing interactions"
      end
    end
  end
end

# Configure VCR based on environment
VCRConfig.configure!
