# frozen_string_literal: true

require_relative "base_dto"

# DTO for movie comparison requests
class MovieComparisonRequest < BaseDTO
  MAX_TITLE_LENGTH = 200

  protected

  def required_fields
    %i[movie1_id movie2_id]
  end

  def optional_fields
    {
      movie1_title: nil,
      movie2_title: nil
    }
  end

  def validate!
    super
    validate_movie_ids!
    validate_movie_titles!
  end

  private

  def validate_movie_ids!
    raise ValidationError, "Movie1 ID must be a positive integer" unless movie1_id.is_a?(Integer) && movie1_id.positive?

    raise ValidationError, "Movie2 ID must be a positive integer" unless movie2_id.is_a?(Integer) && movie2_id.positive?

    return unless movie1_id == movie2_id

    raise ValidationError, "Cannot compare a movie with itself"
  end

  def validate_movie_titles!
    validate_movie_title!(movie1_title, "Movie1") if movie1_title
    validate_movie_title!(movie2_title, "Movie2") if movie2_title
  end

  def validate_movie_title!(title, label)
    raise ValidationError, "#{label} title must be a string" unless title.is_a?(String)

    return unless title.length > MAX_TITLE_LENGTH

    raise ValidationError, "#{label} title too long (max #{MAX_TITLE_LENGTH} characters)"
  end
end
