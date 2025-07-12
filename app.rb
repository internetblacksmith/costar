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
    set :public_folder, "public"
    set :views, "views"
    enable :sessions

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

  # Production security configuration
  configure :production do
    require "rack/ssl"

    # Force HTTPS
    use Rack::SSL

    # Additional security headers
    use Rack::Protection,
        except: [:json_csrf], # Allow JSON requests
        use: %i[authenticity_token encrypted_cookie form_token frame_options
                http_origin ip_spoofing path_traversal session_hijacking xss_header]
  end

  # Rate limiting configuration
  require_relative "config/rack_attack"
  use Rack::Attack

  # Sentry error tracking middleware (conditionally enabled in config)
  use Sentry::Rack::CaptureExceptions

  # Error handling with Sentry integration
  setup_error_handlers

  # Health check endpoint
  health_check_endpoint

  # Main page
  get "/" do
    erb :index
  end

  # API endpoints
  api_routes
end

# Run the app when executed directly
ActorSyncApp.run! if __FILE__ == $PROGRAM_NAME
