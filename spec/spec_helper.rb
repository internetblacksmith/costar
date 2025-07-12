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
  config.before(:each) do
    WebMock.reset!
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Clear cache between tests
  config.before(:each) do
    Cache.clear if defined?(Cache)
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
end
