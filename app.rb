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
require_relative "lib/config/configuration_policy"
require_relative "lib/services/configuration_validator"
require_relative "lib/config/cache"
require_relative "lib/config/errors"
require_relative "lib/config/logger"
require_relative "lib/config/service_container"
require_relative "lib/config/service_initializer"
require_relative "lib/middleware/request_logger"
require_relative "lib/middleware/request_context_middleware"
require_relative "lib/middleware/performance_headers"
require_relative "lib/services/cache_key_builder"
require_relative "lib/services/cache_manager"
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

class MovieTogetherApp < Sinatra::Base
  register Sinatra::Namespace
  include HealthController
  include APIController
  include ErrorHandler

  configure do
    # Initialize configuration (loads .env file in development)
    Configuration.instance

    # Initialize configuration policies
    ConfigurationPolicy.initialize!

    # Validate configuration
    ConfigurationValidator.validate!

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

    # Initialize services using dependency injection
    ServiceInitializer.initialize_services
    set :tmdb_service, ServiceContainer.get(:tmdb_service)
    set :comparison_service, ServiceContainer.get(:comparison_service)
  end

  # Production security and performance configuration
  configure :production do
    require "rack/ssl"

    # Enable gzip compression for all responses
    use Rack::Deflater

    # Force HTTPS (exclude health checks for internal monitoring) - skip in test
    use Rack::SSL, exclude: ->(env) { env["PATH_INFO"].start_with?("/health") } unless ENV.fetch("RACK_ENV", "development") == "test"
  end

  # Security configuration for all environments (including test for security tests)
  # Additional security headers - adjust for test environment
  unless ENV.fetch("RACK_ENV", "development") == "test"
    # Full protection in non-test environments
    use Rack::Protection,
        except: %i[json_csrf frame_options xss_header], # Handle these ourselves
        use: %i[authenticity_token encrypted_cookie form_token
                http_origin ip_spoofing path_traversal session_hijacking]
  end

  # Custom security headers for all environments
  before do
    # Set all security headers directly
    headers "Content-Security-Policy" => build_csp_header
    headers "Referrer-Policy" => "strict-origin-when-cross-origin"
    headers "Permissions-Policy" => "geolocation=(), microphone=(), camera=()"
    headers "X-Frame-Options" => "DENY"
    headers "X-Content-Type-Options" => "nosniff"
    headers "X-XSS-Protection" => "1; mode=block"

    # Only add HSTS in production
    headers "Strict-Transport-Security" => "max-age=31536000; includeSubDomains; preload" if ENV.fetch("RACK_ENV", "development") == "production"

    # Add cache control for static assets to prevent stale content
    cache_control :public, :must_revalidate, max_age: 3600 if request.path.match?(/\.(js|css|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot|svg)$/)
  end

  # Rate limiting configuration
  require_relative "config/rack_attack"
  use Rack::Attack

  # Request context middleware (must be early in the stack)
  use RequestContextMiddleware

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
    {
      status: "ok",
      git_sha: ENV.fetch("RENDER_GIT_COMMIT", `git rev-parse --short HEAD 2>/dev/null`.strip) || "unknown"
    }.to_json
  end

  # Main page
  get "/" do
    # Check if actor IDs are provided in URL parameters
    @actor1_id = params[:actor1_id]
    @actor2_id = params[:actor2_id]

    # Fetch actor names if IDs are provided
    if @actor1_id && @actor2_id
      begin
        # Fetch actor profiles to get names
        actor1_profile = settings.tmdb_service.get_actor_profile(@actor1_id.to_i)
        actor2_profile = settings.tmdb_service.get_actor_profile(@actor2_id.to_i)

        @actor1_name = actor1_profile[:name] if actor1_profile
        @actor2_name = actor2_profile[:name] if actor2_profile

        # Log what we got
        settings.logger.info "Share link loaded",
                             actor1_id: @actor1_id,
                             actor1_name: @actor1_name,
                             actor2_id: @actor2_id,
                             actor2_name: @actor2_name
      rescue StandardError => e
        settings.logger.error "Error fetching actor names", error: e.message
        # Continue without names, let client-side fetch them
      end
    end

    # Pass the IDs and names to the view to pre-populate and auto-trigger comparison
    erb :index
  end

  # API endpoints
  api_routes

  private

  # Add comprehensive security headers for production
  def add_security_headers
    headers "Content-Security-Policy" => build_csp_header
    headers "Referrer-Policy" => "strict-origin-when-cross-origin"
    headers "Permissions-Policy" => "geolocation=(), microphone=(), camera=()"

    # Only add HSTS in production/test with HTTPS
    return unless ENV.fetch("RACK_ENV", "development") == "production"

    headers "Strict-Transport-Security" => "max-age=31536000; includeSubDomains; preload"
  end

  def override_rack_protection_headers
    # Override Rack::Protection defaults with our more secure settings
    headers "X-Frame-Options" => "DENY"
    headers "X-Content-Type-Options" => "nosniff"
    headers "X-XSS-Protection" => "1; mode=block"
  end

  def build_csp_header
    # Build Content Security Policy
    policies = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com https://*.posthog.com https://browser.sentry-cdn.com", # HTMX from CDN + PostHog + Sentry (with eval for HTMX)
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://unpkg.com", # Allow CSS imports and external styles
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' https://image.tmdb.org data:", # TMDB images
      "connect-src 'self' https://api.themoviedb.org https://*.posthog.com https://*.sentry.io", # API calls + analytics
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

    # Common CORS headers for all environments
    headers "Access-Control-Allow-Credentials" => "false"
    headers "Access-Control-Expose-Headers" => "X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset"
  end
end

# Run the app when executed directly
MovieTogetherApp.run! if __FILE__ == $PROGRAM_NAME
