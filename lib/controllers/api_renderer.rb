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
    # Convert DTOs to hashes if needed
    actor_hashes = if actors.respond_to?(:actors)
                     # It's a SearchResultsDTO
                     actors.actors.map(&:to_h)
                   elsif actors.is_a?(Array)
                     actors.map { |actor| actor.respond_to?(:to_h) ? actor.to_h : actor }
                   else
                     []
                   end

    app.erb :suggestions, locals: { actors: actor_hashes, field: field }, layout: false
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
    # Convert DTOs to hashes if needed
    movie_hashes = if movies.is_a?(Array)
                     movies.map { |movie| movie.respond_to?(:to_h) ? movie.to_h : movie }
                   else
                     []
                   end

    response_builder = ApiResponseBuilder.new(app)
    response_builder.success({ movies: movie_hashes })
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
  # Renders validation error with 400 status (for security-critical validation)
  #
  # @param errors [Array<String>] Array of validation errors
  # @return [String] Rendered error HTML
  #
  def render_validation_errors_with_400(errors)
    @app.status 400
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
  # Renders missing movies error
  #
  # @return [String] Rendered error HTML
  #
  def render_missing_movies_error
    '<div class="error">Please select both movies</div>'
  end

  ##
  # Renders movie suggestions view
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param movies [Array<Hash>] Array of movie data
  # @param field [String] Field name for form targeting
  # @return [String] Rendered HTML
  #
  def render_movie_suggestions(app, movies, field)
    # Convert DTOs to hashes if needed
    movie_hashes = if movies.respond_to?(:movies)
                     # It's a MovieSearchResultsDTO
                     movies.movies.map(&:to_h)
                   elsif movies.is_a?(Array)
                     movies.map { |movie| movie.respond_to?(:to_h) ? movie.to_h : movie }
                   else
                     []
                   end

    app.erb :movie_suggestions, locals: { movies: movie_hashes, field: field }, layout: false
  end

  ##
  # Renders empty movie suggestions (no results)
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param field [String] Field name for form targeting
  # @return [String] Rendered HTML
  #
  def render_empty_movie_suggestions(app, field)
    render_movie_suggestions(app, [], field)
  end

  ##
  # Renders movie comparison results (shared actors)
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param comparison_data [Hash] Movie comparison data
  # @return [String] Rendered HTML
  #
  def render_movie_comparison(app, comparison_data)
    assign_movie_comparison_variables(app, comparison_data)
    app.erb :movie_comparison, layout: false
  end

  ##
  # Renders JSON response for movie cast
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param cast [Array<Hash>] Array of actor data
  # @return [String] JSON response
  #
  def render_movie_cast_json(app, cast)
    # Convert DTOs to hashes if needed
    cast_hashes = if cast.is_a?(Array)
                    cast.map { |actor| actor.respond_to?(:to_h) ? actor.to_h : actor }
                  else
                    []
                  end

    response_builder = ApiResponseBuilder.new(app)
    response_builder.success({ cast: cast_hashes })
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
    # Handle both DTO and hash formats
    if data.respond_to?(:actor1)
      assign_dto_timeline_variables(app, data)
    else
      assign_hash_timeline_variables(app, data)
    end
  end

  def assign_dto_timeline_variables(app, data)
    # It's a ComparisonResultDTO
    app.instance_variable_set(:@actor1_movies, data.actor1_movies.map(&:to_h))
    app.instance_variable_set(:@actor2_movies, data.actor2_movies.map(&:to_h))
    app.instance_variable_set(:@shared_movies, data.shared_movies.map(&:to_h))
    app.instance_variable_set(:@actor1_name, data.actor1.name)
    app.instance_variable_set(:@actor2_name, data.actor2.name)
    app.instance_variable_set(:@actor1_profile, { profile_path: data.actor1.profile_path })
    app.instance_variable_set(:@actor2_profile, { profile_path: data.actor2.profile_path })
    app.instance_variable_set(:@years, data.timeline_data[:years])

    # Convert processed_movies DTOs to hashes
    processed_movies = convert_processed_movies_to_hashes(data.timeline_data[:processed_movies])
    app.instance_variable_set(:@processed_movies, processed_movies)

    # Convert shared_movies_by_year DTOs to hashes
    shared_by_year = convert_shared_movies_by_year_to_hashes(data.timeline_data[:shared_movies_by_year])
    app.instance_variable_set(:@shared_movies_by_year, shared_by_year)

    app.instance_variable_set(:@actor1_id, data.actor1.id)
    app.instance_variable_set(:@actor2_id, data.actor2.id)
  end

  def convert_processed_movies_to_hashes(processed_movies)
    return processed_movies unless processed_movies.is_a?(Hash)

    result = {}
    processed_movies.each do |year, entries|
      result[year] = entries.map do |entry|
        if entry[:type] == :shared && entry[:movies]
          {
            type: :shared,
            movies: entry[:movies].map do |movie_data|
              {
                side: movie_data[:side],
                actor: movie_data[:actor],
                movie: movie_data[:movie].respond_to?(:to_h) ? movie_data[:movie].to_h : movie_data[:movie]
              }
            end
          }
        elsif entry[:type] == :single && entry[:movie]
          {
            type: :single,
            movie: {
              side: entry[:movie][:side],
              actor: entry[:movie][:actor],
              movie: entry[:movie][:movie].respond_to?(:to_h) ? entry[:movie][:movie].to_h : entry[:movie][:movie]
            }
          }
        else
          entry
        end
      end
    end
    result
  end

  def convert_shared_movies_by_year_to_hashes(shared_movies)
    return shared_movies unless shared_movies.is_a?(Hash)

    result = {}
    shared_movies.each do |year, movies|
      result[year] = movies.map do |movie|
        movie.respond_to?(:to_h) ? movie.to_h : movie
      end
    end
    result
  end

  def assign_hash_timeline_variables(app, data)
    # Legacy hash format
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
    app.instance_variable_set(:@actor1_id, data[:actor1_id])
    app.instance_variable_set(:@actor2_id, data[:actor2_id])
  end

  ##
  # Assigns movie comparison data to template variables
  #
  # @param app [Sinatra::Base] Sinatra application instance
  # @param data [Hash] Movie comparison data
  #
  def assign_movie_comparison_variables(app, data)
    # Handle both DTO and hash formats
    if data.respond_to?(:movie1)
      assign_dto_movie_comparison_variables(app, data)
    else
      assign_hash_movie_comparison_variables(app, data)
    end
  end

  def assign_dto_movie_comparison_variables(app, data)
    # It's a MovieComparisonResultDTO
    app.instance_variable_set(:@movie1, data.movie1.to_h)
    app.instance_variable_set(:@movie2, data.movie2.to_h)
    app.instance_variable_set(:@movie1_cast, data.movie1_cast.map(&:to_h))
    app.instance_variable_set(:@movie2_cast, data.movie2_cast.map(&:to_h))
    app.instance_variable_set(:@shared_actors, data.shared_actors.map(&:to_h))
  end

  def assign_hash_movie_comparison_variables(app, data)
    # Hash format
    app.instance_variable_set(:@movie1, {
                                id: data[:movie1_id],
                                title: data[:movie1_title],
                                poster_path: data[:movie1_poster_path],
                                year: data[:movie1_year]
                              })
    app.instance_variable_set(:@movie2, {
                                id: data[:movie2_id],
                                title: data[:movie2_title],
                                poster_path: data[:movie2_poster_path],
                                year: data[:movie2_year]
                              })
    app.instance_variable_set(:@movie1_cast, convert_cast_to_hashes(data[:movie1_cast]))
    app.instance_variable_set(:@movie2_cast, convert_cast_to_hashes(data[:movie2_cast]))
    app.instance_variable_set(:@shared_actors, convert_cast_to_hashes(data[:shared_actors]))
  end

  def convert_cast_to_hashes(cast)
    return [] unless cast

    cast.map { |actor| actor.respond_to?(:to_h) ? actor.to_h : actor }
  end
end
