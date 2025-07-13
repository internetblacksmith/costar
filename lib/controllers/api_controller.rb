# frozen_string_literal: true

require_relative "api_handlers"

# API routes controller for actor search and comparison
module APIController
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def api_routes
      namespace "/api" do
        before do
          configure_cors_headers
        end

        # Handle preflight requests for CORS
        options "*" do
          response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
          response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, User-Agent"
          response.headers["Access-Control-Max-Age"] = "3600"
          200
        end

        get "/actors/search" do
          ApiHandlers.new(self).handle_actor_search(params)
        end

        get "/actors/:id/movies" do
          ApiHandlers.new(self).handle_actor_movies(params)
        end

        get "/actors/compare" do
          ApiHandlers.new(self).handle_actor_comparison(params)
        end
      end
    end
  end
end
