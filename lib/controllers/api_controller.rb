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
        before { configure_cors_headers }

        options "*" do
          response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
          response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, User-Agent"
          response.headers["Access-Control-Max-Age"] = "3600"
          200
        end

        # Actor endpoints
        get("/actors/search") { ApiHandlers.new(self).handle_actor_search(params) }
        get("/actors/:id/movies") { ApiHandlers.new(self).handle_actor_movies(params) }
        get("/actors/compare") { ApiHandlers.new(self).handle_actor_comparison(params) }

        # Movie endpoints
        get("/movies/search") { ApiHandlers.new(self).handle_movie_search(params) }
        get("/movies/:id/cast") { ApiHandlers.new(self).handle_movie_cast(params) }
        get("/movies/compare") { ApiHandlers.new(self).handle_movie_comparison(params) }
      end
    end
  end
end
