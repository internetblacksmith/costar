# frozen_string_literal: true

require_relative "../services/api_response_builder"

##
# Rendering utilities for API responses
#
# Handles view rendering and response formatting for API endpoints.
# Centralizes all rendering logic and template variable assignment.
#
module ApiRenderer
  ##
  # Renders actor suggestions view
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param actors [Array<Hash>] Array of actor data
  # @param field [String] Field name for form targeting
  # @return [String] Rendered HTML
  #
  def render_actor_suggestions(app, actors, field)
    app.erb :suggestions, locals: { actors: actors, field: field }, layout: false
  end

  ##
  # Renders empty suggestions (no results)
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param field [String] Field name for form targeting
  # @return [String] Rendered HTML
  #
  def render_empty_suggestions(app, field)
    render_actor_suggestions(app, [], field)
  end

  ##
  # Renders actor comparison timeline
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param comparison_data [Hash] Timeline comparison data
  # @return [String] Rendered HTML
  #
  def render_actor_timeline(app, comparison_data)
    assign_timeline_variables(app, comparison_data)
    app.erb :timeline, layout: false
  end

  ##
  # Renders JSON response for actor movies
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param movies [Array<Hash>] Array of movie data
  # @return [String] JSON response
  #
  def render_actor_movies_json(app, movies)
    response_builder = ApiResponseBuilder.new(app)
    response_builder.success({ movies: movies })
  end

  ##
  # Renders search error message
  #
  # @param message [String] Error message
  # @return [String] Rendered error HTML
  #
  def render_search_error(message)
    "<div class=\"suggestion-item\"><strong>❌ Search Error</strong><br><small>#{message}</small></div>"
  end

  ##
  # Renders unexpected error message
  #
  # @return [String] Rendered error HTML
  #
  def render_unexpected_error
    "<div class=\"suggestion-item\"><strong>❌ Unexpected Error</strong>" \
      "<br><small>Please try again later</small></div>"
  end

  ##
  # Renders validation error message
  #
  # @param errors [Array<String>] Array of validation errors
  # @return [String] Rendered error HTML
  #
  def render_validation_errors(errors)
    error_list = errors.join(", ")
    "<div class=\"error\">Validation Error: #{error_list}</div>"
  end

  ##
  # Renders missing actors error
  #
  # @return [String] Rendered error HTML
  #
  def render_missing_actors_error
    '<div class="error">Please select both actors</div>'
  end

  ##
  # Renders comparison error message
  #
  # @param message [String] Error message
  # @return [String] Rendered error HTML
  #
  def render_comparison_error(message)
    "<div class=\"error\">#{message}</div>"
  end

  ##
  # Renders API error as JSON
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param code [Integer] HTTP status code
  # @param message [String] Error message
  #
  def render_json_error(app, code, message)
    response_builder = ApiResponseBuilder.new(app)
    app.halt response_builder.error(message, code: code)
  end

  private

  ##
  # Assigns timeline comparison data to template variables
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param data [Hash] Comparison data
  #
  def assign_timeline_variables(app, data)
    app.instance_variable_set(:@actor1_movies, data[:actor1_movies])
    app.instance_variable_set(:@actor2_movies, data[:actor2_movies])
    app.instance_variable_set(:@shared_movies, data[:shared_movies])
    app.instance_variable_set(:@actor1_name, data[:actor1_name])
    app.instance_variable_set(:@actor2_name, data[:actor2_name])
    app.instance_variable_set(:@actor1_profile, data[:actor1_profile])
    app.instance_variable_set(:@actor2_profile, data[:actor2_profile])
    app.instance_variable_set(:@years, data[:years])
    app.instance_variable_set(:@processed_movies, data[:processed_movies])
    app.instance_variable_set(:@shared_movies_by_year, data[:shared_movies_by_year])
    # Add actor IDs for share functionality
    app.instance_variable_set(:@actor1_id, data[:actor1_id])
    app.instance_variable_set(:@actor2_id, data[:actor2_id])
  end
end
