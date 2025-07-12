# frozen_string_literal: true

# Rendering utilities for API responses
module ApiRenderer
  def render_empty_suggestions(field)
    @app.erb :suggestions, locals: { actors: [], field: field }, layout: false
  end

  def render_search_error(message)
    "<div class=\"suggestion-item\"><strong>❌ Search Error</strong><br><small>#{message}</small></div>"
  end

  def render_unexpected_error
    "<div class=\"suggestion-item\"><strong>❌ Unexpected Error</strong>" \
      "<br><small>Please try again later</small></div>"
  end

  def set_search_variables(query, field)
    @app.instance_variable_set(:@actors, @app.settings.tmdb_service.search_actors(query))
    @app.instance_variable_set(:@field, field)
  end

  def error_missing_actors
    '<div class="error">Please select both actors</div>'
  end
end
