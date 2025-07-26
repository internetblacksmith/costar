# frozen_string_literal: true

require_relative "service_container"
require_relative "../services/resilient_tmdb_client"
require_relative "../services/tmdb_service"
require_relative "../services/actor_comparison_service"
require_relative "../services/timeline_builder"
require_relative "../services/api_response_builder"
require_relative "../services/cache_manager"
require_relative "../services/performance_monitor"
require_relative "../services/input_sanitizer"
require_relative "../services/cache_cleaner"
require_relative "../services/simple_request_throttler"
require_relative "../controllers/input_validator"

# Initializes and configures all application services
module ServiceInitializer
  def self.initialize_services(app_instance = nil)
    register_core_services
    register_api_services
    register_utility_services(app_instance)
  end

  def self.register_core_services
    # Register cache service
    ServiceContainer.register(:cache) do
      Cache
    end

    # Register cache manager
    ServiceContainer.register(:cache_manager) do
      CacheManager.new
    end

    # Register cache cleaner
    ServiceContainer.register(:cache_cleaner) do
      cleaner = CacheCleaner.new
      # Start cleaner only in production or if explicitly enabled
      cleaner.start if ENV["RACK_ENV"] == "production" || ENV["ENABLE_CACHE_CLEANER"] == "true"
      cleaner
    end
  end

  def self.register_api_services
    # Register request throttler (using simple version to avoid threading issues)
    ServiceContainer.register(:request_throttler) do
      SimpleRequestThrottler.new
    end

    # Register TMDB client with circuit breaker
    ServiceContainer.register(:tmdb_client) do |container|
      # Allow tests to run without API key when using VCR cassettes
      api_key = if ENV["RACK_ENV"] == "test"
                  ENV["TMDB_API_KEY"] || "test_api_key_placeholder"
                else
                  ENV.fetch("TMDB_API_KEY")
                end

      ResilientTMDBClient.new(
        api_key: api_key,
        cache: container.get(:cache_manager)
      )
    end

    # Register TMDB service
    ServiceContainer.register(:tmdb_service) do |container|
      # Get dependencies first to avoid recursive locking
      client = container.get(:tmdb_client)
      cache = container.get(:cache_manager)
      throttler = container.get(:request_throttler)
      TMDBService.new(client: client, cache: cache, throttler: throttler)
    end

    # Register actor comparison service
    ServiceContainer.register(:comparison_service) do |container|
      # Get dependencies first to avoid recursive locking
      tmdb_service = container.get(:tmdb_service)
      cache = container.get(:cache_manager)
      ActorComparisonService.new(
        tmdb_service: tmdb_service,
        timeline_builder: nil, # TimelineBuilder is created per comparison
        cache: cache
      )
    end
  end

  def self.register_utility_services(app_instance = nil)
    # Register API response builder (requires app instance)
    ServiceContainer.register(:response_builder) do
      if app_instance
        ApiResponseBuilder.new(app_instance)
      else
        # Return a factory that creates response builders on demand
        ->(app) { ApiResponseBuilder.new(app) }
      end
    end

    # Register performance monitor
    ServiceContainer.register(:performance_monitor) do
      PerformanceMonitor
    end

    # Register logger
    ServiceContainer.register(:logger) do
      StructuredLogger
    end

    # Register input sanitizer
    ServiceContainer.register(:input_sanitizer) do
      InputSanitizer.new
    end

    # Register input validator
    ServiceContainer.register(:input_validator) do
      InputValidator.new
    end
  end

  # Configure services with application-specific settings
  def self.configure(config = {})
    ServiceContainer.configure(config)
  end

  # Get a service instance
  def self.get(service_name)
    ServiceContainer.get(service_name)
  end

  # Reset services (mainly for testing)
  def self.reset!
    ServiceContainer.reset!
  end
end
