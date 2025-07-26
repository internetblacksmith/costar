# frozen_string_literal: true

require_relative "../config/logger"
require_relative "api_error_handler"
require_relative "api_renderer"
require_relative "input_validator"
require_relative "api_business_logic"

##
# Orchestrates API request handling with separated concerns
#
# Coordinates input validation, business logic, and rendering
# while maintaining clean separation of responsibilities.
#
class ApiHandlers
  include ApiErrorHandler
  include ApiRenderer

  def initialize(app)
    @app = app
    @validator = InputValidator.new
    @business_logic = ApiBusinessLogic.new(
      app.settings.tmdb_service,
      app.settings.comparison_service
    )
  end

  ##
  # Handles actor search requests
  #
  # @return [String] Rendered HTML response
  #
  def handle_actor_search(params = nil)
    # Use provided params or fall back to app params
    request_params = params || @app.params

    # Validate input
    validation = @validator.validate_actor_search(request_params)

    # Handle validation errors
    unless validation.valid?
      # Use 400 status for security violations (oversized input)
      return render_validation_errors_with_400(validation.errors) if validation.security_violation?
      
      # Use 200 status for other validation errors
      return render_validation_errors(validation.errors)
    end

    # Handle empty query (valid case)
    return render_empty_suggestions(@app, validation.field) if validation.query.nil?

    begin
      # Execute business logic
      actors = @business_logic.search_actors(validation.query)

      # Render response
      render_actor_suggestions(@app, actors, validation.field)
    rescue TMDBError => e
      handle_api_error(e, "search_actors")
      # Return the error HTML directly
      return render_search_error(e.message)
    rescue StandardError => e
      handle_unexpected_error(e, "search_actors")
      # Return the error HTML directly
      return render_unexpected_error
    end
  end

  ##
  # Handles actor movies requests
  #
  # @return [String] JSON response
  #
  def handle_actor_movies(params = nil)
    # Use provided params or fall back to app params
    request_params = params || @app.params

    # Validate input
    validation = @validator.validate_actor_id(request_params)

    return render_json_error(@app, 400, validation.errors.first) unless validation.valid?

    begin
      # Execute business logic
      movies = @business_logic.fetch_actor_movies(validation.actor_id)

      # Render response
      render_actor_movies_json(@app, movies)
    rescue TMDBError => e
      handle_api_error_with_context(e, "fetch_actor_movies", actor_id: validation.actor_id)
      render_json_error(@app, e.code, e.message)
    rescue StandardError => e
      handle_unexpected_error_with_context(e, "fetch_actor_movies", actor_id: validation.actor_id)
      render_json_error(@app, 500, "Failed to get actor movies")
    end
  end

  ##
  # Handles actor comparison requests
  #
  # @return [String] Rendered HTML response
  #
  def handle_actor_comparison(params = nil)
    # Use provided params or fall back to app params
    request_params = params || @app.params

    # Validate input
    validation = @validator.validate_actor_comparison(request_params)

    unless validation.valid?
      # Check if this is a missing actor ID error - use generic message for UX consistency
      return render_missing_actors_error if validation.errors.any? { |error| error.include?("Actor") && error.include?("ID is required") }

      return render_validation_errors(validation.errors)

    end

    begin
      # Execute business logic
      comparison_data = @business_logic.compare_actors(
        validation.actor1_id, validation.actor2_id,
        validation.actor1_name, validation.actor2_name
      )

      # Render response
      render_actor_timeline(@app, comparison_data)
    rescue ValidationError => e
      handle_validation_error_with_context(e, "compare_actors", validation: validation)
      render_comparison_error(e.message)
    rescue TMDBError => e
      handle_api_error_with_context(e, "compare_actors", validation: validation)
      render_comparison_error("API Error: #{e.message}")
    rescue StandardError => e
      handle_unexpected_error_with_context(e, "compare_actors", validation: validation)
      render_comparison_error("Failed to compare actors. Please try again.")
    end
  end
end
