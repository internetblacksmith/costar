# frozen_string_literal: true

source "https://rubygems.org"

# Version Pinning Strategy:
# All gems are pinned to exact versions for production stability and reproducible builds.
# To update versions:
# 1. Update the version in this file
# 2. Run `bundle update <gem-name>` for specific gems
# 3. Run `bundle install` to update Gemfile.lock
# 4. Test thoroughly before deploying
# Last updated: 2025-11-16

# Core application dependencies
gem "activesupport", "8.1.1" # For cache and notifications
gem "circuit_breaker", "1.1.2" # Circuit breaker pattern for API resilience
gem "connection_pool", "3.0.2" # Redis connection pooling
gem "dotenv", "3.2.0" # Environment variable loading (fallback)
gem "json", "2.18.0" # JSON parsing
gem "logger", "1.7.0" # Logging (Ruby 3.5+ compatibility)
gem "net-http", "0.8.0" # HTTP client
gem "nokogiri", ">= 1.18.9" # XML parsing (security fix for libxml2 CVEs)
gem "ostruct", "0.6.3" # OpenStruct (Ruby 3.5+ compatibility)
gem "puma", "7.1.0" # Web server
gem "rack", ">= 3.1.17" # Web server framework (security fixes for CVE-2025-61770, CVE-2025-61771, CVE-2025-61772, CVE-2025-61919)
gem "rack-attack", "6.8.0" # Rate limiting and security
gem "rack-ssl", "1.4.1" # HTTPS enforcement
gem "rackup", "2.3.1" # Rack server command
gem "redis", "5.4.1" # Redis client
gem "retries", "0.0.5" # Exponential backoff retries
gem "rexml", ">= 3.4.2" # XML parsing (security fix for CVE-2025-58767)
gem "sentry-ruby", "6.2.0" # Error tracking and monitoring
gem "sinatra", ">= 4.2.0" # Web framework (security fix for CVE-2025-61921)
gem "sinatra-contrib", ">= 4.2.0" # Sinatra extensions
gem "thor", ">= 1.4.0" # CLI framework (security fix for CVE-2025-54314)
gem "uri", ">= 1.0.4" # URI parsing (security fix for CVE-2025-61594)

group :development do
  gem "brakeman", "7.1.1" # Security scanner
  gem "bundle-audit", "0.2.0" # Dependency security scanner
  gem "filewatcher", "2.1.0" # File watching for auto-restart (replaces rerun)
  gem "pry", "0.15.2" # Interactive debugger
  gem "rubocop", "1.81.7" # Code style and linting
end

group :test do
  gem "axe-core-rspec", "4.11.0" # Accessibility testing with axe-core
  gem "benchmark", "0.2.0" # Performance measurement (Ruby 3.5+ compatibility)
  gem "capybara", "3.40.0" # Browser simulation for Cucumber
  gem "cucumber", "10.2.0" # BDD testing framework (Ruby 3.4+ compatible)
  gem "cuprite", "0.17" # Headless Chrome driver for Capybara (used by visual/compatibility tests)
  gem "factory_bot", "6.5.6" # Test data factories
  gem "faker", "3.5.3" # Fake data generation
  gem "rack-test", "2.2.0" # Rack application testing
  gem "rspec", "3.13.2" # Testing framework
  gem "rspec_junit_formatter", "0.6.0" # JUnit format for CI
  gem "selenium-webdriver", "4.39.0" # Selenium WebDriver for browser testing
  gem "simplecov", "0.22.0" # Code coverage analysis
  gem "vcr", "6.3.1" # Record and replay HTTP interactions
  gem "webmock", "3.26.1" # HTTP request stubbing
end

group :development, :test do
  gem "pry-byebug", "3.11.0" # Debugging with breakpoints
end
