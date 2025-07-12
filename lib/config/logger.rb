# frozen_string_literal: true

require "logger"
require "json"

# Structured JSON logger for production
class StructuredLogger
  class << self
    def setup
      @logger ||= create_logger
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
        timestamp: Time.now.iso8601
      )
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
      }.merge(context)

      @logger.send(level, log_entry.to_json)
    end

    def create_logger
      logger = Logger.new($stdout)
      
      # Use JSON formatter in production/deployment, readable format in development
      if production_env?
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
      else
        logger.formatter = proc do |severity, datetime, progname, msg|
          parsed = JSON.parse(msg)
          "[#{datetime}] #{severity}: #{parsed['message']} #{parsed.except('timestamp', 'level', 'message', 'app', 'environment').to_json}\n"
        rescue JSON::ParserError
          "[#{datetime}] #{severity}: #{msg}\n"
        end
      end
      
      logger.level = production_env? ? Logger::INFO : Logger::DEBUG
      logger
    end

    def production_env?
      env = ENV.fetch("RACK_ENV", "development")
      env == "production" || env == "deployment"
    end
  end
end