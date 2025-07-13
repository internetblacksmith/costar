# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/service_initializer"

RSpec.describe ServiceInitializer do
  before(:each) do
    described_class.reset!
  end

  describe ".initialize_services" do
    before do
      described_class.initialize_services
    end

    it "registers all required services" do
      expected_services = %i[
        cache
        cache_manager
        tmdb_client
        tmdb_service
        comparison_service
        response_builder
        performance_monitor
        logger
      ]

      registered = ServiceContainer.instance.registered_services
      expect(registered).to include(*expected_services)
    end

    it "creates cache service" do
      cache = described_class.get(:cache)
      expect(cache).to eq(Cache)
    end

    it "creates cache manager with cache dependency" do
      cache_manager = described_class.get(:cache_manager)
      expect(cache_manager).to be_instance_of(CacheManager)
    end

    it "creates TMDB client with dependencies" do
      tmdb_client = described_class.get(:tmdb_client)
      expect(tmdb_client).to be_instance_of(ResilientTMDBClient)
    end

    it "creates TMDB service with dependencies" do
      tmdb_service = described_class.get(:tmdb_service)
      expect(tmdb_service).to be_instance_of(TMDBService)
    end

    it "creates comparison service with dependencies" do
      comparison_service = described_class.get(:comparison_service)
      expect(comparison_service).to be_instance_of(ActorComparisonService)
    end

    it "creates response builder factory when no app instance provided" do
      response_builder = described_class.get(:response_builder)
      expect(response_builder).to respond_to(:call)
    end

    it "creates performance monitor" do
      monitor = described_class.get(:performance_monitor)
      expect(monitor).to eq(PerformanceMonitor)
    end

    it "creates logger" do
      logger = described_class.get(:logger)
      expect(logger).to eq(StructuredLogger)
    end
  end

  describe ".initialize_services with app instance" do
    let(:app_instance) { double("app") }

    before do
      described_class.initialize_services(app_instance)
    end

    it "creates response builder with app instance" do
      response_builder = described_class.get(:response_builder)
      expect(response_builder).to be_instance_of(ApiResponseBuilder)
    end
  end

  describe ".configure" do
    it "delegates to ServiceContainer" do
      config = { api_key: "test" }
      expect(ServiceContainer).to receive(:configure).with(config)
      described_class.configure(config)
    end
  end

  describe ".get" do
    before do
      described_class.initialize_services
    end

    it "retrieves services from container" do
      tmdb_service = described_class.get(:tmdb_service)
      expect(tmdb_service).to be_instance_of(TMDBService)
    end
  end

  describe ".reset!" do
    it "delegates to ServiceContainer" do
      expect(ServiceContainer).to receive(:reset!)
      described_class.reset!
    end
  end
end
