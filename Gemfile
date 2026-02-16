# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 4.0.0"

# Version Pinning Strategy:
# All gems are pinned to exact versions for production stability and reproducible builds.
# To update versions:
# 1. Run `bundle outdated` to see available updates
# 2. Update the version in this file
# 3. Run `bundle update <gem-name>` for specific gems
# 4. Run `bundle install` to update Gemfile.lock
# 5. Test thoroughly before deploying
# Last updated: 2025-12-29 (Ruby 4.0.0 upgrade)

# Core application dependencies
gem "activesupport", "8.1.2" # For cache and notifications
gem "circuit_breaker", "1.1.2" # Circuit breaker pattern for API resilience
gem "connection_pool", "3.0.2" # Redis connection pooling
gem "dotenv", "3.2.0" # Environment variable loading (fallback)
gem "json", "2.18.1" # JSON parsing
gem "logger", "1.7.0" # Logging
gem "net-http", "0.9.1" # HTTP client
gem "nokogiri", "1.19.0" # XML parsing
gem "ostruct", "0.6.3" # OpenStruct
gem "puma", "7.2.0" # Web server
gem "rack", "3.2.5" # Web server framework
gem "rack-attack", "6.8.0" # Rate limiting and security
gem "rack-ssl", "1.4.1" # HTTPS enforcement
gem "rackup", "2.3.1" # Rack server command
gem "redis", "5.4.1" # Redis client
gem "retries", "0.0.5" # Exponential backoff retries
gem "rexml", "3.4.4" # XML parsing
gem "sentry-ruby", "6.3.1" # Error tracking and monitoring
gem "sinatra", "4.2.1" # Web framework
gem "sinatra-contrib", "4.2.1" # Sinatra extensions
gem "thor", "1.5.0" # CLI framework
gem "uri", "1.1.1" # URI parsing

group :development do
  gem "brakeman", "7.1.2" # Security scanner
  gem "bundle-audit", "0.2.0" # Dependency security scanner
  gem "listen", "3.10.0" # File watching for auto-restart
  gem "pry", "0.16.0" # Interactive debugger
  gem "rubocop", "1.82.1" # Code style and linting
end

group :test do
  gem "axe-core-rspec", "4.11.1" # Accessibility testing with axe-core
  gem "benchmark", "0.5.0" # Performance measurement
  gem "capybara", "3.40.0" # Browser simulation for Cucumber
  gem "cucumber", "10.2.0" # BDD testing framework
  gem "cuprite", "0.17" # Headless Chrome driver for Capybara
  gem "factory_bot", "6.5.6" # Test data factories
  gem "faker", "3.5.3" # Fake data generation
  gem "rack-test", "2.2.0" # Rack application testing
  gem "rspec", "3.13.2" # Testing framework
  gem "rspec_junit_formatter", "0.6.0" # JUnit format for CI
  gem "selenium-webdriver", "4.40.0" # Selenium WebDriver for browser testing
  gem "simplecov", "0.22.0" # Code coverage analysis
  gem "vcr", "6.4.0" # Record and replay HTTP interactions
  gem "webmock", "3.26.1" # HTTP request stubbing
end

group :development, :test do
  gem "pry-byebug", "3.12.0" # Debugging with breakpoints
end
