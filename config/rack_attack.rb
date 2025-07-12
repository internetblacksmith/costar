# frozen_string_literal: true

# Rack::Attack configuration for ActorSync
# Rate limiting and security rules

require "rack/attack"
require "active_support/cache"
require "active_support/notifications"
require_relative "../lib/config/logger"

module Rack
  class Attack
    # Disable Rack::Attack in test environment
    unless ENV.fetch("RACK_ENV", "development") == "test"

      # Configure cache store - use Redis in production, memory for development
      rack_env = ENV.fetch("RACK_ENV", "development")
      if rack_env == "production" || rack_env == "deployment"
        # Use Redis cache in production via connection pool
        require "redis"
        require "connection_pool"

        redis_pool = ConnectionPool.new(size: 5, timeout: 5) do
          Redis.new(
            url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
            reconnect_attempts: 3,
            reconnect_delay: 1,
            timeout: 5
          )
        end

        begin
          # Use Rack::Attack's native Redis store which doesn't depend on ActiveSupport cache
          redis_config = {
            url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
            reconnect_attempts: 3,
            connect_timeout: 5,
            read_timeout: 5,
            write_timeout: 5
          }
          Rack::Attack.cache.store = Redis.new(redis_config)
        rescue => e
          StructuredLogger.warn("Rack::Attack Redis Failed", type: "rack_attack", error: e.message, fallback: "memory_cache")
          Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
        end
      else
        # Use memory cache in development
        Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
      end

      # Throttle requests to search endpoint
      # Allow 60 requests per minute per IP for search
      throttle("search/ip", limit: 60, period: 60) do |req|
        req.ip if req.path.start_with?("/api/actors/search")
      end

      # Throttle requests to comparison endpoint
      # Allow 30 requests per minute per IP for comparison (more expensive)
      throttle("compare/ip", limit: 30, period: 60) do |req|
        req.ip if req.path.start_with?("/api/actors/compare")
      end

      # Throttle general API requests
      # Allow 120 requests per minute per IP for all API endpoints
      throttle("api/ip", limit: 120, period: 60) do |req|
        req.ip if req.path.start_with?("/api/")
      end

      # Block requests with suspicious user agents
      blocklist("block bad user agents") do |req|
        # Block requests with empty or suspicious user agents
        user_agent = req.user_agent
        user_agent.nil? ||
          user_agent.empty? ||
          user_agent.match(/curl|wget|python|java|go-http|bot/i)
      end

      # Block requests with suspicious referers
      blocklist("block suspicious referers") do |req|
        referer = req.referer
        referer&.match(/malicious|spam|attack/i)
      end

      # Allow requests from localhost in development
      safelist("allow localhost") do |req|
        ENV.fetch("RACK_ENV", "development") == "development" &&
          ["127.0.0.1", "::1"].include?(req.ip)
      end

      # Custom response for throttled requests
      self.throttled_responder = lambda do |env|
        match_data = env["rack.attack.match_data"]
        now = match_data[:epoch_time]

        headers = {
          "Content-Type" => "application/json",
          "X-RateLimit-Limit" => match_data[:limit].to_s,
          "X-RateLimit-Remaining" => "0",
          "X-RateLimit-Reset" => (now + match_data[:period]).to_s,
          "Retry-After" => match_data[:period].to_s
        }

        body = {
          error: "Rate limit exceeded",
          message: "Too many requests. Please try again later.",
          retry_after: match_data[:period]
        }.to_json

        [429, headers, [body]]
      end

      # Custom response for blocked requests
      self.blocklisted_responder = lambda do |_env|
        [403, { "Content-Type" => "application/json" }, [
          { error: "Forbidden", message: "Access denied" }.to_json
        ]]
      end

      # Log blocked and throttled requests
      ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _request_id, payload|
        StructuredLogger.warn("Request Blocked", 
          type: "security", 
          action: "blocked", 
          ip: payload[:request].ip, 
          path: payload[:request].path,
          user_agent: payload[:request].user_agent
        )
      end

      ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
        StructuredLogger.warn("Request Throttled", 
          type: "security", 
          action: "throttled", 
          ip: payload[:request].ip, 
          path: payload[:request].path,
          user_agent: payload[:request].user_agent
        )
      end

    end
  end
end
