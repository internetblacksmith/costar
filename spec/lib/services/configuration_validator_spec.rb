# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/configuration_policy"
require_relative "../../../lib/services/configuration_validator"

RSpec.describe ConfigurationValidator do
  describe ".validate!" do
    before do
      # Save original environment
      @original_env = ENV.to_h
      ConfigurationPolicy.reset!
    end

    after do
      # Restore original environment
      ENV.clear
      @original_env.each { |k, v| ENV[k] = v }
      # Reset ConfigurationPolicy to defaults
      ConfigurationPolicy.reset!
    end

    context "with required variables" do
      it "validates TMDB_API_KEY is present" do
        ENV.delete("TMDB_API_KEY")

        results = described_class.validate!
        # In test mode, missing TMDB_API_KEY is allowed (uses test placeholder)
        if ENV["RACK_ENV"] == "test"
          expect(results[:info]).to include(/TMDB_API_KEY will use test placeholder/)
        else
          expect(results[:errors]).to include(/TMDB_API_KEY is not set/)
        end
      end

      it "validates TMDB_API_KEY is not default" do
        ENV["TMDB_API_KEY"] = "changeme"

        results = described_class.validate!
        expect(results[:errors]).to include(/TMDB_API_KEY is still set to default/)
      end

      it "passes when TMDB_API_KEY is valid" do
        ENV["TMDB_API_KEY"] = "valid_key_123"

        results = described_class.validate!
        expect(results[:info]).to include(/TMDB_API_KEY is configured/)
      end
    end

    context "with optional variables" do
      it "warns about missing Redis URL" do
        ENV.delete("REDIS_URL")

        results = described_class.validate!
        expect(results[:warnings]).to include(/REDIS_URL not set/)
      end

      it "warns about missing Sentry DSN" do
        ENV.delete("SENTRY_DSN")

        results = described_class.validate!
        expect(results[:warnings]).to include(/SENTRY_DSN not set/)
      end

      it "confirms when optional variables are set" do
        ENV["REDIS_URL"] = "redis://localhost:6379"
        ENV["SENTRY_DSN"] = "https://key@sentry.io/123"

        results = described_class.validate!
        expect(results[:info]).to include(/REDIS_URL is configured/)
        expect(results[:info]).to include(/SENTRY_DSN is configured/)
      end
    end

    context "with policy validation" do
      it "warns about short cache TTL" do
        ConfigurationPolicy.set(:cache, :ttl, 60)

        results = described_class.validate!
        expect(results[:warnings]).to include(/Cache TTL.*is very short/)
      end

      it "warns about high rate limit" do
        ConfigurationPolicy.set(:rate_limiting, :max_requests, 100)
        ConfigurationPolicy.set(:rate_limiting, :window_size, 1)

        results = described_class.validate!
        expect(results[:warnings]).to include(/Rate limit.*may be too high/)
      end

      it "warns about short API timeout" do
        ConfigurationPolicy.set(:api, :timeout, 2)

        results = described_class.validate!
        expect(results[:warnings]).to include(/API timeout.*may be too short/)
      end
    end

    context "in production environment" do
      before do
        allow(described_class).to receive(:production?).and_return(true)
        ENV["TMDB_API_KEY"] = "valid_key"
      end

      it "requires Redis URL" do
        ENV.delete("REDIS_URL")

        results = described_class.validate!
        expect(results[:errors]).to include(/REDIS_URL is required in production/)
      end

      it "requires allowed origins" do
        ConfigurationPolicy.set(:security, :allowed_origins, [])

        results = described_class.validate!
        expect(results[:errors]).to include(/ALLOWED_ORIGINS must be configured/)
      end

      it "warns about missing Sentry in production" do
        ENV.delete("SENTRY_DSN")

        results = described_class.validate!
        expect(results[:warnings]).to include(/Error tracking disabled in production/)
      end
    end
  end

  describe ".validate_runtime_config" do
    it "validates API timeout maximum" do
      config = { api: { timeout: 35 } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/API timeout cannot exceed 30 seconds/)
    end

    it "validates max retries" do
      config = { api: { max_retries: 10 } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/API max retries cannot exceed 5/)
    end

    it "validates cache TTL maximum" do
      config = { cache: { ttl: 100_000 } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/Cache TTL cannot exceed 24 hours/)
    end

    it "validates cleanup interval minimum" do
      config = { cache: { cleanup_interval: 30 } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/Cache cleanup interval must be at least 60 seconds/)
    end

    it "validates input length limits" do
      config = { security: { max_input_length: 1000 } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/Max input length must be between 50 and 500/)
    end

    it "validates origin format" do
      config = { security: { allowed_origins: ["not-a-url"] } }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to include(/Invalid origin format/)
    end

    it "passes valid configuration" do
      config = {
        api: { timeout: 10, max_retries: 3 },
        cache: { ttl: 3600, cleanup_interval: 300 },
        security: { max_input_length: 200, allowed_origins: ["https://example.com"] }
      }

      errors = described_class.validate_runtime_config(config)
      expect(errors).to be_empty
    end
  end
end
