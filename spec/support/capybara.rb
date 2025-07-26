# frozen_string_literal: true

require "capybara"
require "capybara/rspec"
require "capybara/cuprite"

# Configure Capybara
Capybara.app = MovieTogetherApp
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 5

# Configure Cuprite (headless Chrome)
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
