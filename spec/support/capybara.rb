# frozen_string_literal: true

require "capybara"
require "capybara/rspec"
require "selenium-webdriver"
require "capybara/cuprite"

# Configure Capybara
Capybara.app = MovieTogetherApp
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite # Default for most feature tests
Capybara.default_max_wait_time = 5
Capybara.reuse_server = false # Don't reuse servers between tests
Capybara.server_port = 45_670 # Use dedicated test port to avoid conflicts with dev server

# Configure Selenium WebDriver with Chrome (for accessibility testing)
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1920,1080")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure Cuprite (headless Chrome via CDP) for visual/compatibility tests
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app,
                                window_size: [1920, 1080],
                                browser_options: {
                                  "no-sandbox": nil,
                                  "disable-gpu": nil,
                                  "disable-dev-shm-usage": nil
                                },
                                inspector: ENV["CUPRITE_DEBUG"] == "true",
                                headless: ENV["CUPRITE_HEADLESS"] != "false")
end

# Helper for feature specs
RSpec.configure do |config|
  config.include Capybara::DSL, type: :feature
  config.include Capybara::RSpecMatchers, type: :feature
end
