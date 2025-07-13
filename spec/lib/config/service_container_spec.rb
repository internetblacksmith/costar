# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/service_container"

RSpec.describe ServiceContainer do
  before(:each) do
    described_class.reset!
  end

  describe ".register" do
    it "registers a service initializer" do
      described_class.register(:test_service) do
        "test service instance"
      end

      expect(described_class.instance.registered?(:test_service)).to be true
    end
  end

  describe ".get" do
    context "when service is registered" do
      before do
        described_class.register(:test_service) do
          "test service instance"
        end
      end

      it "returns the service instance" do
        expect(described_class.get(:test_service)).to eq("test service instance")
      end

      it "returns the same instance on subsequent calls" do
        instance1 = described_class.get(:test_service)
        instance2 = described_class.get(:test_service)
        expect(instance1).to equal(instance2)
      end
    end

    context "when service is not registered" do
      it "raises ArgumentError" do
        expect { described_class.get(:unknown_service) }.to raise_error(ArgumentError, "Service 'unknown_service' not registered")
      end
    end

    context "with dependencies" do
      before do
        described_class.register(:dependency) do
          "dependency instance"
        end

        described_class.register(:dependent_service) do |container|
          dependency = container.get(:dependency)
          "service with #{dependency}"
        end
      end

      it "resolves dependencies correctly" do
        expect(described_class.get(:dependent_service)).to eq("service with dependency instance")
      end
    end
  end

  describe ".configure" do
    it "stores configuration" do
      config = { api_key: "test_key", timeout: 30 }
      described_class.configure(config)

      expect(described_class.instance.config).to eq(config)
    end
  end

  describe ".reset!" do
    before do
      described_class.register(:test_service) { "test" }
      described_class.configure(test: true)
      described_class.get(:test_service)
    end

    it "clears all services and configuration" do
      described_class.reset!

      expect(described_class.instance.registered_services).to be_empty
      expect(described_class.instance.config).to eq({})
    end
  end

  describe "#registered_services" do
    before do
      described_class.register(:service_a) { "A" }
      described_class.register(:service_b) { "B" }
      described_class.register(:service_c) { "C" }
    end

    it "returns all registered service names" do
      expect(described_class.instance.registered_services).to contain_exactly(:service_a, :service_b, :service_c)
    end
  end

  describe "thread safety" do
    it "handles concurrent service access safely" do
      described_class.register(:counter) do
        Thread.current[:counter] ||= 0
        Thread.current[:counter] += 1
      end

      threads = 10.times.map do
        Thread.new { described_class.get(:counter) }
      end

      threads.each(&:join)

      # Should create only one instance
      expect(described_class.get(:counter)).to eq(1)
    end
  end
end
