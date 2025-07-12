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
          headers "Access-Control-Allow-Origin" => "*"
        end

        get "/actors/search" do
          ApiHandlers.new(self).handle_actor_search
        end

        get "/actors/:id/movies" do
          ApiHandlers.new(self).handle_actor_movies
        end

        get "/actors/compare" do
          ApiHandlers.new(self).handle_actor_comparison
        end
      end
    end
  end
end
