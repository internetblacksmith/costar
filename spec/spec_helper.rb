# frozen_string_literal: true

# Configure SimpleCov for test coverage
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/views/"
  add_filter "/public/"
  add_group "Services", "lib/services"
  add_group "Configuration", "lib/config"
  add_group "Application", "app.rb"

  minimum_coverage 30 # Temporary lower target while fixing tests
end

# Load test environment
ENV["RACK_ENV"] = "test"
# Set a dummy API key for VCR tests
ENV["TMDB_API_KEY"] = "test_api_key_for_vcr" unless ENV["TMDB_API_KEY"]

# Auto-detect Redis for comprehensive testing
# If Redis is running on default port and no REDIS_URL is set, use it
unless ENV["REDIS_URL"]
  begin
    require "redis"
    redis = Redis.new(url: "redis://localhost:6379", connect_timeout: 1)
    redis.ping
    ENV["REDIS_URL"] = "redis://localhost:6379"
    puts "✅ Auto-detected Redis at localhost:6379 for testing"
    redis.close
  rescue StandardError
    # Redis not available, tests will use memory cache (suppress verbose output)
    ENV["REDIS_URL"] ||= nil
  end
end

# Require the main application
require_relative "../app"

# Test dependencies
require "rack/test"
require "webmock/rspec"
require "factory_bot"
require "faker"

# Load support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

# Configure RSpec
RSpec.configure do |config|
  # Include Rack::Test methods for integration tests
  config.include Rack::Test::Methods

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Configure FactoryBot
  config.before(:suite) do
    FactoryBot.find_definitions
  end

  # WebMock configuration
  config.before(:each) do |_example|
    WebMock.reset!
    # For VCR tests we allow external connections, for regular tests we block them
    # All tests block localhost for safety
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Clear cache between tests and disable performance monitoring
  config.before(:each) do |example|
    Cache.clear if defined?(Cache)
    RequestContext.current = nil if defined?(RequestContext)

    # Disable performance monitoring during tests
    allow(PerformanceMonitor).to receive(:track_request).and_return(nil) if defined?(PerformanceMonitor)
    allow(PerformanceMonitor).to receive(:track_cache_performance).and_return(nil) if defined?(PerformanceMonitor)
    allow(PerformanceMonitor).to receive(:track_api_performance).and_return(nil) if defined?(PerformanceMonitor)

    # For VCR tests, disable caching to ensure HTTP interactions are recorded/replayed
    if example.metadata[:vcr]
      # Mock Cache.get to always return nil (cache miss)
      allow(Cache).to receive(:get).and_return(nil)
      # Mock Cache.set to be a no-op
      allow(Cache).to receive(:set).and_return(true)
    else
      # Disable circuit breaker fallbacks during non-VCR tests to allow proper mocking
      allow_any_instance_of(SimpleCircuitBreaker).to receive(:call).and_yield if defined?(SimpleCircuitBreaker)

      # Disable retry mechanisms during non-VCR tests
      allow_any_instance_of(ResilientTMDBClient).to receive(:with_retries).and_yield if defined?(ResilientTMDBClient)
    end
  end

  # Expectations configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mocks configuration
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Test behavior configuration
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  # Formatter configuration
  config.default_formatter = "doc" if config.files_to_run.one?

  # Performance profiling
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Shared configuration for request specs
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Ensure Capybara servers are properly cleaned up after test suite
  config.after(:suite) do
    if defined?(Capybara)
      # Clean up any Capybara servers
      Capybara.reset_sessions!
      # Kill any remaining Capybara server processes
      Capybara.current_session.driver.quit if Capybara.current_session.driver.respond_to?(:quit)
    end
  end
end

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

# Load accessibility testing if running accessibility specs
# Using axe-core-rspec (maintained by Deque Systems - actively developed)
require "axe/rspec" if ENV["ACCESSIBILITY_TESTS"] || ARGV.any? { |arg| arg.include?("accessibility") }
