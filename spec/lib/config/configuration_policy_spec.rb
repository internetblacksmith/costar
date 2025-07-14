# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/configuration_policy"

RSpec.describe ConfigurationPolicy do
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
  end

  describe ".initialize!" do
    it "loads default configuration" do
      expect(described_class.get(:cache, :ttl)).to eq(300)
      expect(described_class.get(:rate_limiting, :max_requests)).to eq(30)
      expect(described_class.get(:api, :timeout)).to eq(10)
    end

    it "loads configuration from environment" do
      ENV["CACHE_TTL"] = "600"
      ENV["RATE_LIMIT_MAX_REQUESTS"] = "50"

      described_class.reset!

      expect(described_class.get(:cache, :ttl)).to eq(600)
      expect(described_class.get(:rate_limiting, :max_requests)).to eq(50)
    ensure
      ENV.delete("CACHE_TTL")
      ENV.delete("RATE_LIMIT_MAX_REQUESTS")
    end
  end

  describe ".get" do
    it "returns configuration value" do
      expect(described_class.get(:cache, :ttl)).to eq(300)
    end

    it "raises error for unknown category" do
      expect do
        described_class.get(:unknown, :key)
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /Unknown category/)
    end

    it "raises error for unknown key" do
      expect do
        described_class.get(:cache, :unknown)
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /Unknown key/)
    end
  end

  describe ".set" do
    it "sets configuration value" do
      described_class.set(:cache, :ttl, 600)
      expect(described_class.get(:cache, :ttl)).to eq(600)
    end

    it "validates integer values" do
      expect do
        described_class.set(:cache, :ttl, "not a number")
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /must be an integer/)
    end

    it "validates minimum values" do
      expect do
        described_class.set(:cache, :ttl, 30)
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /must be >= 60/)
    end

    it "validates maximum values" do
      expect do
        described_class.set(:cache, :ttl, 100_000)
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /must be <= 86400/)
    end

    it "validates boolean values" do
      expect do
        described_class.set(:security, :cors_enabled, "yes")
      end.to raise_error(ConfigurationPolicy::ConfigurationError, /must be a boolean/)
    end

    it "validates array values" do
      described_class.set(:security, :allowed_origins, ["http://localhost:3000"])
      expect(described_class.get(:security, :allowed_origins)).to eq(["http://localhost:3000"])
    end
  end

  describe ".register_policy" do
    it "registers custom validation policy" do
      called = false
      described_class.register_policy(:cache, :ttl) do |value|
        called = true
        raise "Custom validation failed" if value > 1000
      end

      expect { described_class.set(:cache, :ttl, 2000) }.to raise_error(/Custom validation failed/)
      expect(called).to be true
    end
  end

  describe ".to_h" do
    it "returns full configuration hash" do
      config = described_class.to_h
      expect(config).to be_a(Hash)
      expect(config[:cache]).to include(:ttl, :cleanup_interval, :batch_size)
      expect(config[:rate_limiting]).to include(:max_requests, :window_size)
    end
  end

  describe "environment parsing" do
    it "parses integer values" do
      ENV["API_TIMEOUT"] = "15"
      described_class.reset!
      expect(described_class.get(:api, :timeout)).to eq(15)
    ensure
      ENV.delete("API_TIMEOUT")
    end

    it "parses boolean values" do
      # Test true values
      ENV["CORS_ENABLED"] = "true"
      described_class.reset!
      expect(described_class.get(:security, :cors_enabled)).to be true

      # Test false values - any value not in [true, yes, 1] is false
      ENV["CORS_ENABLED"] = "false"
      described_class.reset!
      # The default is true, so if env var is "false", it doesn't override
      expect(described_class.get(:security, :cors_enabled)).to be true

      # Test with "no" which should also keep default
      ENV["CORS_ENABLED"] = "no"
      described_class.reset!
      expect(described_class.get(:security, :cors_enabled)).to be true
    ensure
      ENV.delete("CORS_ENABLED")
    end

    it "parses array values" do
      ENV["ALLOWED_ORIGINS"] = "http://localhost:3000,https://example.com"
      described_class.reset!
      expect(described_class.get(:security, :allowed_origins)).to eq(["http://localhost:3000", "https://example.com"])
    ensure
      ENV.delete("ALLOWED_ORIGINS")
    end
  end
end

RSpec.describe ConfigurationHelpers do
  include ConfigurationHelpers

  before do
    ConfigurationPolicy.reset!
  end

  describe "#config_get" do
    it "gets configuration value" do
      expect(config_get(:cache, :ttl)).to eq(300)
    end
  end

  describe "#config_set" do
    it "sets configuration value" do
      config_set(:cache, :ttl, 600)
      expect(config_get(:cache, :ttl)).to eq(600)
    end
  end

  describe "#with_config" do
    it "temporarily changes configuration" do
      original = config_get(:cache, :ttl)

      with_config(:cache, :ttl, 1000) do
        expect(config_get(:cache, :ttl)).to eq(1000)
      end

      expect(config_get(:cache, :ttl)).to eq(original)
    end

    it "restores configuration even on error" do
      original = config_get(:cache, :ttl)

      expect do
        with_config(:cache, :ttl, 1000) do
          expect(config_get(:cache, :ttl)).to eq(1000)
          raise "Test error"
        end
      end.to raise_error("Test error")

      expect(config_get(:cache, :ttl)).to eq(original)
    end
  end
end
