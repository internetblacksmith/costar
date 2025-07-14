# frozen_string_literal: true

require_relative "logger"

# Configuration policy system for managing application settings
class ConfigurationPolicy
  class ConfigurationError < StandardError; end

  # Define configuration schemas with validation rules
  SCHEMAS = {
    cache: {
      ttl: {
        type: :integer,
        min: 60,
        max: 86_400,
        default: 300,
        description: "Cache TTL in seconds"
      },
      cleanup_interval: {
        type: :integer,
        min: 60,
        max: 3600,
        default: 300,
        description: "Cache cleanup interval in seconds"
      },
      batch_size: {
        type: :integer,
        min: 10,
        max: 1000,
        default: 100,
        description: "Cache cleanup batch size"
      }
    },
    rate_limiting: {
      max_requests: {
        type: :integer,
        min: 10,
        max: 100,
        default: 30,
        description: "Maximum requests per window"
      },
      window_size: {
        type: :integer,
        min: 1,
        max: 60,
        default: 10,
        description: "Rate limit window in seconds"
      }
    },
    api: {
      timeout: {
        type: :integer,
        min: 1,
        max: 30,
        default: 10,
        description: "API request timeout in seconds"
      },
      max_retries: {
        type: :integer,
        min: 0,
        max: 5,
        default: 3,
        description: "Maximum API retry attempts"
      },
      circuit_breaker_threshold: {
        type: :integer,
        min: 1,
        max: 20,
        default: 5,
        description: "Circuit breaker failure threshold"
      }
    },
    security: {
      cors_enabled: {
        type: :boolean,
        default: true,
        description: "Enable CORS headers"
      },
      max_input_length: {
        type: :integer,
        min: 50,
        max: 500,
        default: 200,
        description: "Maximum input string length"
      },
      allowed_origins: {
        type: :array,
        default: [],
        description: "Allowed CORS origins"
      }
    }
  }.freeze

  class << self
    def initialize!
      @config = {}
      @policies = {}

      # Load configuration from environment
      load_from_environment

      # Apply default values
      apply_defaults

      # Validate configuration
      validate_all

      StructuredLogger.info("Configuration initialized", config: sanitized_config)
    end

    def get(category, key)
      validate_key!(category, key)
      @config.dig(category, key)
    end

    def set(category, key, value)
      validate_key!(category, key)
      validate_value!(category, key, value)

      @config[category] ||= {}
      old_value = @config[category][key]
      @config[category][key] = value

      StructuredLogger.info("Configuration updated",
                            category: category,
                            key: key,
                            old_value: old_value,
                            new_value: value)

      notify_change(category, key, old_value, value)
      value
    end

    def register_policy(category, key, &block)
      @policies[category] ||= {}
      @policies[category][key] = block
    end

    def to_h
      @config.dup
    end

    def reset!
      @config = {}
      @policies = {}
      initialize!
    end

    private

    def load_from_environment
      # Cache configuration
      set_from_env(:cache, :ttl, "CACHE_TTL")
      set_from_env(:cache, :cleanup_interval, "CACHE_CLEANUP_INTERVAL")
      set_from_env(:cache, :batch_size, "CACHE_CLEANUP_BATCH_SIZE")

      # Rate limiting configuration
      set_from_env(:rate_limiting, :max_requests, "RATE_LIMIT_MAX_REQUESTS")
      set_from_env(:rate_limiting, :window_size, "RATE_LIMIT_WINDOW_SIZE")

      # API configuration
      set_from_env(:api, :timeout, "API_TIMEOUT")
      set_from_env(:api, :max_retries, "API_MAX_RETRIES")
      set_from_env(:api, :circuit_breaker_threshold, "CIRCUIT_BREAKER_THRESHOLD")

      # Security configuration
      set_from_env(:security, :cors_enabled, "CORS_ENABLED")
      set_from_env(:security, :max_input_length, "MAX_INPUT_LENGTH")
      set_from_env_array(:security, :allowed_origins, "ALLOWED_ORIGINS")
    end

    def set_from_env(category, key, env_var)
      return unless ENV[env_var]

      schema = SCHEMAS.dig(category, key)
      return unless schema

      value = parse_env_value(ENV.fetch(env_var, nil), schema[:type])
      set(category, key, value)
    rescue StandardError => e
      StructuredLogger.warn("Failed to load config from environment",
                            env_var: env_var,
                            error: e.message)
    end

    def set_from_env_array(category, key, env_var)
      return unless ENV[env_var]

      values = ENV[env_var].split(",").map(&:strip).reject(&:empty?)
      set(category, key, values)
    end

    def parse_env_value(value, type)
      case type
      when :integer
        Integer(value)
      when :boolean
        %w[true yes 1].include?(value.downcase)
      when :string, nil
        value
      end
    end

    def apply_defaults
      SCHEMAS.each do |category, keys|
        keys.each do |key, schema|
          next if @config.dig(category, key)

          @config[category] ||= {}
          @config[category][key] = schema[:default]
        end
      end
    end

    def validate_all
      SCHEMAS.each do |category, keys|
        keys.each_key do |key|
          value = @config.dig(category, key)
          validate_value!(category, key, value) if value
        end
      end
    end

    def validate_key!(category, key)
      raise ConfigurationError, "Unknown category: #{category}" unless SCHEMAS[category]
      raise ConfigurationError, "Unknown key: #{category}.#{key}" unless SCHEMAS[category][key]
    end

    def validate_value!(category, key, value)
      schema = SCHEMAS.dig(category, key)
      raise ConfigurationError, "No schema for #{category}.#{key}" unless schema

      case schema[:type]
      when :integer
        validate_integer(value, schema, "#{category}.#{key}")
      when :boolean
        validate_boolean(value, "#{category}.#{key}")
      when :array
        validate_array(value, "#{category}.#{key}")
      end

      # Run custom policy if registered
      policy = @policies.dig(category, key)
      policy&.call(value)
    end

    def validate_integer(value, schema, path)
      raise ConfigurationError, "#{path} must be an integer" unless value.is_a?(Integer)

      raise ConfigurationError, "#{path} must be >= #{schema[:min]}" if schema[:min] && value < schema[:min]

      return unless schema[:max] && value > schema[:max]

      raise ConfigurationError, "#{path} must be <= #{schema[:max]}"
    end

    def validate_boolean(value, path)
      return if [true, false].include?(value)

      raise ConfigurationError, "#{path} must be a boolean"
    end

    def validate_array(value, path)
      raise ConfigurationError, "#{path} must be an array" unless value.is_a?(Array)
    end

    def notify_change(category, key, old_value, new_value)
      # Could emit events or notify listeners here
      policy = @policies.dig(category, key)
      policy&.call(new_value, old_value)
    end

    def sanitized_config
      # Return config with sensitive values masked
      @config.transform_values do |category_config|
        category_config.transform_values do |value|
          value.is_a?(String) && value.length > 20 ? "#{value[0..10]}..." : value
        end
      end
    end
  end
end

# Configuration helper methods
module ConfigurationHelpers
  def config_get(category, key)
    ConfigurationPolicy.get(category, key)
  end

  def config_set(category, key, value)
    ConfigurationPolicy.set(category, key, value)
  end

  def with_config(category, key, temp_value)
    old_value = config_get(category, key)
    config_set(category, key, temp_value)
    yield
  ensure
    config_set(category, key, old_value)
  end
end
