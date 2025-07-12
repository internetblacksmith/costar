# frozen_string_literal: true

source "https://rubygems.org"

gem "activesupport" # For cache and notifications
gem "connection_pool" # Redis connection pooling
gem "dotenv" # Keep dotenv as fallback
gem "json"
gem "logger" # Required for Ruby 3.5+ compatibility
gem "net-http"
gem "ostruct" # Required for Ruby 3.5+ compatibility
gem "puma"
gem "rack-attack" # Rate limiting and security
gem "rack-ssl" # HTTPS enforcement
gem "redis", "~> 5.0" # Redis client
gem "sentry-ruby" # Error tracking and Rack integration
gem "sinatra", "~> 3.0"
gem "sinatra-contrib", "~> 3.0"

group :development do
  gem "pry"
  gem "rerun"
  gem "rubocop", "~> 1.78"
end

group :test do
  gem "factory_bot", "~> 6.2"
  gem "faker", "~> 3.2"
  gem "rack-test", "~> 2.1"
  gem "rspec", "~> 3.12"
  gem "simplecov", "~> 0.22"
  gem "webmock", "~> 3.18"
end

group :development, :test do
  gem "pry-byebug"
end
