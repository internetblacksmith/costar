# frozen_string_literal: true

require "logger"
require "json"
require_relative "log_formatter"

# Structured JSON logger for production
class StructuredLogger
  class << self
    def setup
      @setup ||= create_logger
    end

    def info(message, **context)
      log(:info, message, **context)
    end

    def warn(message, **context)
      log(:warn, message, **context)
    end

    def error(message, **context)
      log(:error, message, **context)
    end

    def debug(message, **context)
      log(:debug, message, **context)
    end

    def log_request(env, status, duration_ms)
      log(:info, "HTTP Request",
          type: "request",
          method: env["REQUEST_METHOD"],
          path: env["PATH_INFO"],
          query: env["QUERY_STRING"],
          ip: env["REMOTE_ADDR"] || env["HTTP_X_FORWARDED_FOR"],
          user_agent: env["HTTP_USER_AGENT"],
          status: status,
          duration_ms: duration_ms.round(2),
          timestamp: Time.now.iso8601)
    end

    def log_api_call(service, endpoint, duration_ms, success: true, error: nil)
      context = {
        type: "api_call",
        service: service,
        endpoint: endpoint,
        duration_ms: duration_ms.round(2),
        success: success,
        timestamp: Time.now.iso8601
      }

      context[:error] = error.message if error

      if success
        log(:info, "API Call Success", **context)
      else
        log(:error, "API Call Failed", **context)
      end
    end

    def log_cache_operation(operation, key, hit: nil, duration_ms: nil)
      context = {
        type: "cache",
        operation: operation,
        key: key,
        timestamp: Time.now.iso8601
      }

      context[:hit] = hit unless hit.nil?
      context[:duration_ms] = duration_ms.round(2) if duration_ms

      log(:debug, "Cache Operation", **context)
    end

    private

    def log(level, message, **context)
      return unless @logger

      log_entry = {
        timestamp: Time.now.iso8601,
        level: level.to_s.upcase,
        message: message,
        app: "actorsync",
        environment: ENV.fetch("RACK_ENV", "development")
      }

      # Include request context if available
      if defined?(RequestContext) && RequestContext.current
        log_entry[:request_id] = RequestContext.current.request_id
        log_entry[:request_path] = RequestContext.current.path
        log_entry[:request_method] = RequestContext.current.method
      end

      log_entry.merge!(context)

      @logger.send(level, log_entry.to_json)
    end

    def create_logger
      logger = Logger.new($stdout)
      LogFormatter.setup_formatter(logger)
      logger.level = LogFormatter.production_env? ? Logger::INFO : Logger::DEBUG
      logger
    end
  end
end
