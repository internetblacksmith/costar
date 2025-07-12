# frozen_string_literal: true

require_relative "../config/logger"
require_relative "api_error_handler"
require_relative "api_renderer"

# API handlers for actor search and comparison
class ApiHandlers
  include ApiErrorHandler
  include ApiRenderer
  def initialize(app)
    @app = app
  end

  def handle_actor_search
    query = @app.params[:q]
    field = @app.params[:field] || "actor1"

    return render_empty_suggestions(field) if query.nil? || query.empty?

    search_actors(query, field)
  end

  def handle_actor_movies
    actor_id = @app.params[:id]
    @app.halt 400, { error: "Actor ID required" }.to_json if actor_id.nil?

    fetch_actor_movies(actor_id)
  end

  def handle_actor_comparison
    actor_ids = extract_actor_params
    return error_missing_actors if actor_ids[:actor1_id].nil? || actor_ids[:actor2_id].nil?

    perform_comparison(actor_ids)
  end

  private

  def search_actors(query, field)
    set_search_variables(query, field)
    @app.erb :suggestions, layout: false
  rescue TMDBError => e
    handle_api_error(e, "search_actors")
    render_search_error(e.message)
  rescue StandardError => e
    handle_unexpected_error(e, "search_actors")
    render_unexpected_error
  end

  def fetch_actor_movies(actor_id)
    movies = @app.settings.tmdb_service.get_actor_movies(actor_id)
    @app.content_type :json
    movies.to_json
  rescue TMDBError => e
    handle_api_error_with_context(e, "fetch_actor_movies", actor_id: actor_id)
    @app.halt e.code, { error: e.message }.to_json
  rescue StandardError => e
    handle_unexpected_error_with_context(e, "fetch_actor_movies", actor_id: actor_id)
    @app.halt 500, { error: "Failed to get actor movies" }.to_json
  end

  def extract_actor_params
    {
      actor1_id: @app.params[:actor1_id],
      actor2_id: @app.params[:actor2_id],
      actor1_name: @app.params[:actor1_name],
      actor2_name: @app.params[:actor2_name]
    }
  end

  def perform_comparison(actor_ids)
    comparison_data = fetch_comparison_data(actor_ids)
    assign_timeline_variables(comparison_data)
    @app.erb :timeline, layout: false
  rescue ValidationError => e
    "<div class=\"error\">#{e.message}</div>"
  rescue TMDBError => e
    "<div class=\"error\">API Error: #{e.message}</div>"
  rescue StandardError
    "<div class=\"error\">Failed to compare actors. Please try again.</div>"
  end

  def fetch_comparison_data(actor_ids)
    @app.settings.comparison_service.compare(
      actor_ids[:actor1_id], actor_ids[:actor2_id],
      actor_ids[:actor1_name], actor_ids[:actor2_name]
    )
  end

  def assign_timeline_variables(data)
    @app.instance_variable_set(:@actor1_movies, data[:actor1_movies])
    @app.instance_variable_set(:@actor2_movies, data[:actor2_movies])
    @app.instance_variable_set(:@shared_movies, data[:shared_movies])
    @app.instance_variable_set(:@actor1_name, data[:actor1_name])
    @app.instance_variable_set(:@actor2_name, data[:actor2_name])
    @app.instance_variable_set(:@actor1_profile, data[:actor1_profile])
    @app.instance_variable_set(:@actor2_profile, data[:actor2_profile])
    @app.instance_variable_set(:@years, data[:years])
    @app.instance_variable_set(:@processed_movies, data[:processed_movies])
  end
end
