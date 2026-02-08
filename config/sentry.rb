# frozen_string_literal: true

require "sentry-ruby"

# Only initialize Sentry in production-like environments
# Skip in development to avoid SSL issues with bleeding-edge OpenSSL versions
rack_env = ENV.fetch("RACK_ENV", "development")
sentry_enabled = ENV.fetch("SENTRY_DSN", nil) && !ENV["SENTRY_DSN"].empty? && rack_env != "development"

if sentry_enabled

  # Sentry configuration for error tracking
  Sentry.init do |config|
    # DSN (Data Source Name) - get this from your Sentry project
    config.dsn = ENV.fetch("SENTRY_DSN", nil)

    # Only enable in production-like environments
    config.enabled_environments = %w[production staging deployment]

    # Environment
    config.environment = ENV.fetch("RACK_ENV", "development")

    # App version for release tracking
    config.release = ENV.fetch("APP_VERSION", "unknown")

    # Server name
    config.server_name = ENV.fetch("RENDER_SERVICE_NAME", "screenthread")

    # Sample rate for performance monitoring (0.0 to 1.0)
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f

    # Sample rate for errors (1.0 = capture all errors)
    config.sample_rate = 1.0

    # Configure which exceptions to ignore
    config.excluded_exceptions += [
      "Sinatra::NotFound",
      "Rack::Attack::Throttle"
    ]

    # Set breadcrumbs logger
    config.breadcrumbs_logger = %i[sentry_logger http_logger]

    # Configure before_send callback to filter sensitive data
    config.before_send = lambda do |event, _hint|
      # Filter out sensitive data from the event
      event.request.data = filter_sensitive_data(event.request.data) if event.request&.data

      event.request.headers = filter_sensitive_headers(event.request.headers) if event.request&.headers

      event
    end
  end

  # Tags to add to all events (set after initialization)
  Sentry.set_tags(
    app: "screenthread",
    component: "backend"
  )
end

# Sentry disabled when no DSN is provided

# Helper methods for data filtering
def filter_sensitive_data(data)
  return data unless data.is_a?(Hash)

  sensitive_keys = %w[password api_key token secret dsn]

  data.each do |key, value|
    if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
      data[key] = "[FILTERED]"
    elsif value.is_a?(Hash)
      data[key] = filter_sensitive_data(value)
    end
  end

  data
end

def filter_sensitive_headers(headers)
  return headers unless headers.is_a?(Hash)

  sensitive_headers = %w[authorization cookie x-api-key]

  headers.each do |key, _value|
    headers[key] = "[FILTERED]" if sensitive_headers.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
  end

  headers
end
