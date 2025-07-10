# frozen_string_literal: true

require "sinatra"
require "sinatra/namespace"
require "dotenv"

# Load application dependencies
# Doppler configuration will be loaded by the configuration class if available

# Load configuration and services
require_relative "lib/config/configuration"
require_relative "lib/config/cache"
require_relative "lib/config/errors"
require_relative "lib/services/tmdb_service"
require_relative "lib/services/timeline_builder"
require_relative "lib/services/actor_comparison_service"
require_relative "lib/services/poster_service"
require_relative "lib/services/actor_profile_service"

class ActorSyncApp < Sinatra::Base
  register Sinatra::Namespace

  configure do
    set :public_folder, "public"
    set :views, "views"
    enable :sessions
    set :port, ENV.fetch('PORT', 4567)
    set :bind, '0.0.0.0'
    
    # Initialize services
    set :tmdb_service, TMDBService.new
    set :comparison_service, ActorComparisonService.new
  end

  # Error handling
  error APIError do
    status env["sinatra.error"].code
    content_type :json
    { error: env["sinatra.error"].message }.to_json
  end

  error ValidationError do
    status 400
    content_type :json
    { error: env["sinatra.error"].message }.to_json
  end

  # Main page
  get "/" do
    erb :index
  end

  # API endpoints
  namespace "/api" do
    before do
      headers "Access-Control-Allow-Origin" => "*"
    end

    # Search for actors
    get "/actors/search" do
      query = params[:q]
      field = params[:field] || "actor1"

      return erb :suggestions, locals: { actors: [], field: field }, layout: false if query.nil? || query.empty?

      begin
        @actors = settings.tmdb_service.search_actors(query)
        @field = field
        erb :suggestions, layout: false
      rescue TMDBError => e
        "<div class=\"suggestion-item\"><strong>❌ Search Error</strong><br><small>#{e.message}</small></div>"
      rescue StandardError => e
        "<div class=\"suggestion-item\"><strong>❌ Unexpected Error</strong><br><small>Please try again later</small></div>"
      end
    end

    # Get actor's filmography
    get "/actors/:id/movies" do
      actor_id = params[:id]
      halt 400, { error: "Actor ID required" }.to_json if actor_id.nil?

      begin
        movies = settings.tmdb_service.get_actor_movies(actor_id)
        content_type :json
        movies.to_json
      rescue TMDBError => e
        halt e.code, { error: e.message }.to_json
      rescue StandardError => e
        halt 500, { error: "Failed to get actor movies" }.to_json
      end
    end

    # Compare two actors
    get "/actors/compare" do
      actor1_id = params[:actor1_id]
      actor2_id = params[:actor2_id]
      actor1_name = params[:actor1_name]
      actor2_name = params[:actor2_name]

      return '<div class="error">Please select both actors</div>' if actor1_id.nil? || actor2_id.nil?

      begin
        comparison_data = settings.comparison_service.compare(
          actor1_id, actor2_id, actor1_name, actor2_name
        )

        # Set instance variables for the template
        @actor1_movies = comparison_data[:actor1_movies]
        @actor2_movies = comparison_data[:actor2_movies]
        @shared_movies = comparison_data[:shared_movies]
        @actor1_name = comparison_data[:actor1_name]
        @actor2_name = comparison_data[:actor2_name]
        @actor1_profile = comparison_data[:actor1_profile]
        @actor2_profile = comparison_data[:actor2_profile]
        @years = comparison_data[:years]
        @processed_movies = comparison_data[:processed_movies]

        erb :timeline, layout: false
      rescue ValidationError => e
        "<div class=\"error\">#{e.message}</div>"
      rescue TMDBError => e
        "<div class=\"error\">API Error: #{e.message}</div>"
      rescue StandardError => e
        "<div class=\"error\">Failed to compare actors. Please try again.</div>"
      end
    end
  end

end

# Run the app when executed directly
ActorSyncApp.run! if __FILE__ == $PROGRAM_NAME
