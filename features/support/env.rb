# frozen_string_literal: true

# Set test environment before loading the app
ENV["RACK_ENV"] = "test"

# Load the Sinatra app
require_relative "../../app"

# Test dependencies
require "capybara"
require "capybara/cucumber"
require "rack/test"
require "vcr"
require "webmock/cucumber"
require_relative "vcr_config"
require_relative "vcr_helpers"

# Configure Capybara for browser simulation
Capybara.app = MovieTogetherApp
Capybara.server = :puma
Capybara.server_port = 45_670
Capybara.app_host = "http://localhost:45670"

# Load Cuprite for JavaScript support
require "capybara/cuprite"

# Configure Cuprite driver with browser-like headers
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app,
                                headless: true,
                                window_size: [1200, 800],
                                browser_path: "/usr/bin/chromium",
                                browser_options: {
                                  "no-sandbox": nil,
                                  "disable-dev-shm-usage": nil,
                                  "disable-gpu": nil
                                },
                                inspector: ENV["DEBUG"] == "true",
                                headers: {
                                  "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
                                  "Accept-Language" => "en-US,en;q=0.9"
                                },
                                timeout: 30)
end

# Configure RackTest driver for non-JS tests (with browser headers)
class BrowserSimulatorDriver < Capybara::RackTest::Driver
  def initialize(app, **options)
    super
    @browser_headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.5",
      "Accept-Encoding" => "gzip, deflate, br",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Site" => "none",
      "Sec-Fetch-User" => "?1",
      "Cache-Control" => "max-age=0"
    }
  end

  def submit(method, path, attributes)
    # Add browser headers to all requests
    attributes[:headers] ||= {}
    attributes[:headers].merge!(@browser_headers)
    super
  end

  def follow(method, path, **attributes)
    # Add browser headers to all requests
    attributes[:headers] ||= {}
    attributes[:headers].merge!(@browser_headers)
    super
  end
end

# Register our custom driver
Capybara.register_driver :browser_simulator do |app|
  BrowserSimulatorDriver.new(app)
end

# Use different drivers based on scenario tags
# @javascript tagged scenarios will use Cuprite (headless Chrome)
# Others will use RackTest with browser headers for speed
Capybara.default_driver = :browser_simulator
Capybara.javascript_driver = :cuprite

# VCR Configuration for Cucumber
VCR.configure do |config|
  config.cassette_library_dir = "features/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: ENV["VCR_RECORD_MODE"]&.to_sym || :once,
    match_requests_on: %i[method uri body],
    serialize_with: :json,
    preserve_exact_body_bytes: true
  }

  # Filter sensitive data
  api_key = ENV["TMDB_API_KEY"] || "test_api_key_placeholder"
  config.filter_sensitive_data("<TMDB_API_KEY>") { api_key }

  # Ignore localhost and test hosts
  config.ignore_localhost = true
  config.ignore_hosts "127.0.0.1", "localhost", "o302014.ingest.us.sentry.io"

  # Ignore Chrome DevTools Protocol requests
  config.ignore_request do |request|
    # Ignore Chrome DevTools requests
    request.uri.include?("devtools") || request.uri.include?("9222")
  end

  # Allow real HTTP connections when no cassette is in use
  config.allow_http_connections_when_no_cassette = ENV["VCR_ALLOW_HTTP"] == "true"
end

# Cucumber hooks
Before do |_scenario|
  # Clear any cached data between scenarios
  Rails.cache.clear if defined?(Rails) && Rails.cache

  # Reset rack-attack throttles for testing
  Rack::Attack.cache.store.clear if defined?(Rack::Attack) && Rack::Attack.cache && Rack::Attack.cache.store
end

Before("@javascript") do
  Capybara.current_driver = :cuprite
end

After("@javascript") do
  Capybara.use_default_driver
end

After do |scenario|
  # Any cleanup needed after scenarios
end

# Helper methods available in step definitions
module CucumberHelpers
  def expect_successful_response
    expect(page.status_code).to eq(200)
  end

  def expect_json_response
    expect(page.response_headers["Content-Type"]).to include("application/json")
  end

  def parse_json_response
    JSON.parse(page.body)
  end

  def with_vcr_cassette(cassette_name, &block)
    VCR.use_cassette(cassette_name, &block)
  end
end

World(CucumberHelpers)
