# frozen_string_literal: true

require "sinatra"
require "sinatra/namespace"
require "dotenv"
require "rack/attack"
require "active_support/cache"
require "active_support/notifications"

# Initialize Sentry for error tracking (always load, but enable conditionally)
require_relative "config/sentry"

# Load application dependencies

# Load configuration and services
require_relative "lib/config/configuration"
require_relative "lib/config/cache"
require_relative "lib/config/errors"
require_relative "lib/config/logger"
require_relative "lib/middleware/request_logger"
require_relative "lib/middleware/performance_headers"
require_relative "lib/services/tmdb_client"
require_relative "lib/services/tmdb_data_processor"
require_relative "lib/services/tmdb_service"
require_relative "lib/services/timeline_builder"
require_relative "lib/services/actor_comparison_service"
require_relative "lib/services/poster_service"
require_relative "lib/services/actor_profile_service"

# Load controllers
require_relative "lib/controllers/health_controller"
require_relative "lib/controllers/api_controller"
require_relative "lib/controllers/error_handler"

class ActorSyncApp < Sinatra::Base
  register Sinatra::Namespace
  include HealthController
  include APIController
  include ErrorHandler

  configure do
    # Initialize configuration (loads .env file in development)
    Configuration.instance
    
    set :public_folder, "public"
    set :views, "views"

    # Configure sessions with proper secret
    enable :sessions
    set :session_store, Rack::Session::Cookie
    set :session_secret, ENV.fetch("SESSION_SECRET") {
      # Generate a consistent secret in development, require it in production
      raise "SESSION_SECRET environment variable is required in production" if ENV.fetch("RACK_ENV", "development") == "production"

      # Development secret - must be >=64 characters
      "development_secret_abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    }

    # Setup structured logging
    StructuredLogger.setup
    set :logger, StructuredLogger

    # Only set port/bind for direct Ruby execution (development)
    # Let Puma handle this in production
    unless defined?(::Puma)
      set :port, ENV.fetch("PORT", 4567)
      set :bind, "0.0.0.0"
    end

    # Initialize services
    set :tmdb_service, TMDBService.new
    set :comparison_service, ActorComparisonService.new
  end

  # Production security and performance configuration
  configure :production do
    require "rack/ssl"

    # Enable gzip compression for all responses
    use Rack::Deflater

    # Force HTTPS (exclude health checks for internal monitoring)
    use Rack::SSL, exclude: ->(env) { env["PATH_INFO"].start_with?("/health") }

    # Additional security headers
    use Rack::Protection,
        except: [:json_csrf], # Allow JSON requests
        use: %i[authenticity_token encrypted_cookie form_token frame_options
                http_origin ip_spoofing path_traversal session_hijacking xss_header]

    # Custom security headers
    before do
      add_security_headers if ENV.fetch("RACK_ENV", "development") == "production"
    end
  end

  # Rate limiting configuration
  require_relative "config/rack_attack"
  use Rack::Attack

  # Performance optimization middleware
  use PerformanceHeaders

  # Request logging middleware
  use RequestLogger

  # Sentry error tracking middleware (conditionally enabled in config)
  use Sentry::Rack::CaptureExceptions

  # Error handling with Sentry integration
  setup_error_handlers

  # Health check endpoint
  health_check_endpoint

  # Simple health check for Render's internal monitoring (always returns 200)
  get "/health/simple" do
    content_type :json
    { status: "ok" }.to_json
  end

  # Main page
  get "/" do
    # Check if actor IDs are provided in URL parameters
    @actor1_id = params[:actor1_id]
    @actor2_id = params[:actor2_id]
    
    # Pass the IDs to the view to pre-populate and auto-trigger comparison
    erb :index
  end

  # API endpoints
  api_routes

  private

  # Add comprehensive security headers for production
  def add_security_headers
    response.headers["Content-Security-Policy"] = build_csp_header
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
  end

  def build_csp_header
    # Build Content Security Policy
    policies = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com https://*.posthog.com", # HTMX from CDN + PostHog (with eval for HTMX)
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://unpkg.com", # Allow CSS imports and external styles
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' https://image.tmdb.org data:", # TMDB images
      "connect-src 'self' https://api.themoviedb.org https://*.posthog.com", # API calls
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'"
    ]
    policies.join("; ")
  end

  def configure_cors_headers
    # Configure CORS based on environment
    if ENV.fetch("RACK_ENV", "development") == "production"
      # In production, be more restrictive with CORS
      allowed_origins = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip)
      origin = request.env["HTTP_ORIGIN"]

      headers "Access-Control-Allow-Origin" => origin || "*" if allowed_origins.empty? || allowed_origins.include?(origin)
    else
      # In development, allow all origins
      headers "Access-Control-Allow-Origin" => "*"
    end

    # Common security headers for all environments
    headers "Access-Control-Allow-Credentials" => "false"
    headers "Access-Control-Expose-Headers" => "X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset"
    headers "X-Content-Type-Options" => "nosniff"
    headers "X-Frame-Options" => "DENY"
    headers "X-XSS-Protection" => "1; mode=block"
  end
end

# Run the app when executed directly
ActorSyncApp.run! if __FILE__ == $PROGRAM_NAME
