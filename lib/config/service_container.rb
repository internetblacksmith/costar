# frozen_string_literal: true

require "singleton"

# Service container for dependency injection
# Manages service initialization and provides centralized access to all services
class ServiceContainer
  include Singleton

  attr_reader :services

  def initialize
    @services = {}
    @initializers = {}
    @mutex = Mutex.new
  end

  # Register a service initializer
  #
  # @param name [Symbol] Service name
  # @param block [Proc] Service initialization block
  # @example
  #   ServiceContainer.register(:tmdb_service) do |container|
  #     TMDBService.new(
  #       client: container.get(:tmdb_client),
  #       cache: container.get(:cache_manager)
  #     )
  #   end
  def self.register(name, &block)
    instance.register(name, &block)
  end

  # Get a service instance
  #
  # @param name [Symbol] Service name
  # @return [Object] Service instance
  # @raise [ArgumentError] if service not registered
  def self.get(name)
    instance.get(name)
  end

  # Configure all services
  #
  # @param config [Hash] Configuration options
  def self.configure(config = {})
    instance.configure(config)
  end

  # Reset the container (mainly for testing)
  def self.reset!
    instance.reset!
  end

  # Instance methods
  def register(name, &block)
    @mutex.synchronize do
      @initializers[name] = block
    end
  end

  def get(name)
    # Check if already initialized without locking
    return @services[name] if @services.key?(name)

    @mutex.synchronize do
      # Double-check after acquiring lock
      return @services[name] if @services.key?(name)

      initializer = @initializers[name]
      raise ArgumentError, "Service '#{name}' not registered" unless initializer

      # Initialize service outside of lock to prevent deadlock
      service = nil
      @mutex.unlock
      begin
        service = initializer.call(self)
      ensure
        @mutex.lock
      end

      @services[name] = service
    end
  end

  def configure(config = {})
    @config = config
  end

  def config
    @config ||= {}
  end

  def reset!
    @mutex.synchronize do
      @services.clear
      @initializers.clear
      @config = {}
    end
  end

  # Convenience method to check if a service is registered
  #
  # @param name [Symbol] Service name
  # @return [Boolean]
  def registered?(name)
    @initializers.key?(name)
  end

  # Get all registered service names
  #
  # @return [Array<Symbol>]
  def registered_services
    @initializers.keys
  end
end
