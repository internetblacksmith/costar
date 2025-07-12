# frozen_string_literal: true

require "json"

# Log formatting utilities for structured logging
module LogFormatter
  module_function

  def setup_formatter(logger)
    if production_env?
      setup_production_formatter(logger)
    else
      setup_development_formatter(logger)
    end
  end

  def setup_production_formatter(logger)
    logger.formatter = proc do |_severity, _datetime, _progname, msg|
      "#{msg}\n"
    end
  end

  def setup_development_formatter(logger)
    logger.formatter = proc do |severity, datetime, _progname, msg|
      format_development_log(severity, datetime, msg)
    end
  end

  def format_development_log(severity, datetime, msg)
    parsed = JSON.parse(msg)
    context = parsed.except("timestamp", "level", "message", "app", "environment")
    "[#{datetime}] #{severity}: #{parsed["message"]} #{context.to_json}\n"
  rescue JSON::ParserError
    "[#{datetime}] #{severity}: #{msg}\n"
  end

  def production_env?
    env = ENV.fetch("RACK_ENV", "development")
    %w[production deployment].include?(env)
  end
end
