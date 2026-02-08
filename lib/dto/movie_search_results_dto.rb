# frozen_string_literal: true

require_relative "base_dto"
require_relative "movie_dto"

# DTO for movie search results
class MovieSearchResultsDTO < BaseDTO
  protected

  def required_fields
    %i[movies]
  end

  def optional_fields
    {
      total_results: 0,
      total_pages: 0,
      page: 1
    }
  end

  def validate!
    super
    validate_movies!
    validate_pagination!
  end

  private

  def validate_movies!
    raise ValidationError, "Movies must be an array" unless movies.is_a?(Array)

    # Convert movie hashes to MovieDTO if needed
    @attributes[:movies] = movies.map do |movie|
      movie.is_a?(MovieDTO) ? movie : MovieDTO.new(movie)
    end
    @movies = @attributes[:movies]
  end

  def validate_pagination!
    raise ValidationError, "Total results must be a non-negative integer" unless total_results.is_a?(Integer) && total_results >= 0

    raise ValidationError, "Total pages must be a non-negative integer" unless total_pages.is_a?(Integer) && total_pages >= 0

    return if page.is_a?(Integer) && page.positive?

    raise ValidationError, "Page must be a positive integer"
  end
end
