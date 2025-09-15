# frozen_string_literal: true

source "https://rubygems.org"

# Version Pinning Strategy:
# All gems are pinned to exact versions for production stability and reproducible builds.
# To update versions:
# 1. Update the version in this file
# 2. Run `bundle update <gem-name>` for specific gems
# 3. Run `bundle install` to update Gemfile.lock
# 4. Test thoroughly before deploying
# Last updated: 2025-07-13

# Core application dependencies
gem "activesupport", "8.0.2.1" # For cache and notifications
gem "circuit_breaker", "1.1.2" # Circuit breaker pattern for API resilience
gem "connection_pool", "2.5.4" # Redis connection pooling
gem "dotenv", "3.1.8" # Environment variable loading (fallback)
gem "json", "2.13.2" # JSON parsing
gem "logger", "1.7.0" # Logging (Ruby 3.5+ compatibility)
gem "net-http", "0.6.0" # HTTP client
gem "ostruct", "0.6.3" # OpenStruct (Ruby 3.5+ compatibility)
gem "puma", "7.0.3" # Web server
gem "rack-attack", "6.7.0" # Rate limiting and security
gem "rack-ssl", "1.4.1" # HTTPS enforcement
gem "rackup", "2.2.1" # Rack server command
gem "redis", "5.4.1" # Redis client
gem "retries", "0.0.5" # Exponential backoff retries
gem "sentry-ruby", "5.27.0" # Error tracking and monitoring
gem "sinatra", "4.1.1" # Web framework
gem "sinatra-contrib", "4.1.1" # Sinatra extensions

group :development do
  gem "brakeman", "6.2.2" # Security scanner
  gem "bundle-audit", "0.1.0" # Dependency security scanner
  gem "filewatcher", "2.1.0" # File watching for auto-restart (replaces rerun)
  gem "pry", "0.15.2" # Interactive debugger
  gem "rubocop", "1.78.0" # Code style and linting
end

group :test do
  gem "axe-matchers", "2.6.1" # Accessibility testing with axe-core
  gem "capybara", "3.40.0" # Browser simulation for Cucumber
  gem "cucumber", "10.0.0" # BDD testing framework (Ruby 3.4+ compatible)
  gem "cuprite", "0.17" # Headless Chrome driver for Capybara
  gem "factory_bot", "6.5.4" # Test data factories
  gem "faker", "3.5.2" # Fake data generation
  gem "rack-test", "2.2.0" # Rack application testing
  gem "rspec", "3.13.1" # Testing framework
  gem "rspec_junit_formatter", "0.6.0" # JUnit format for CI
  gem "simplecov", "0.22.0" # Code coverage analysis
  gem "vcr", "6.3.1" # Record and replay HTTP interactions
  gem "webmock", "3.25.1" # HTTP request stubbing
end

group :development, :test do
  gem "pry-byebug", "3.11.0" # Debugging with breakpoints
end
