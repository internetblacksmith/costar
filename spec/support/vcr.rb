# frozen_string_literal: true

require "vcr"

VCR.configure do |config|
  # Configure the cassette library path
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"

  # Configure which HTTP library to hook into
  config.hook_into :webmock

  # Allow localhost connections (for Rack::Test)
  config.ignore_localhost = true

  # Configure default cassette options
  config.default_cassette_options = {
    record: :new_episodes, # Record new requests, replay existing ones
    match_requests_on: %i[method uri body],
    allow_unused_http_interactions: false,
    serialize_with: :json # More readable than YAML
  }

  # Filter sensitive data from recordings
  config.filter_sensitive_data("<TMDB_API_KEY>") { ENV["TMDB_API_KEY"] }

  # Configure RSpec metadata integration
  config.configure_rspec_metadata!

  # Prevent VCR from interfering with CodeClimate/SimpleCov and Sentry
  config.ignore_hosts "codeclimate.com", "api.codeclimate.com", "o302014.ingest.us.sentry.io"

  # Debug mode (uncomment to debug VCR issues)
  # config.debug_logger = $stderr

  # Allow real HTTP connections when no cassette is in use
  # This is useful for exploratory testing
  config.allow_http_connections_when_no_cassette = false
end

# Helper method to use VCR with custom cassette names
def with_vcr_cassette(name, options = {}, &block)
  VCR.use_cassette(name, options, &block)
end
