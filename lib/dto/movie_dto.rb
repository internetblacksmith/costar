# frozen_string_literal: true

require_relative "base_dto"

# DTO for movie data
class MovieDTO < BaseDTO
  protected

  def required_fields
    %i[id title]
  end

  def optional_fields
    {
      character: nil,
      release_date: nil,
      year: nil,
      poster_path: nil,
      overview: nil,
      vote_average: 0.0,
      popularity: 0.0
    }
  end

  def validate!
    super
    validate_id!
    validate_title!
    validate_year!
    validate_release_date!
  end

  private

  def validate_id!
    return if id.is_a?(Integer) && id.positive?

    raise ValidationError, "ID must be a positive integer"
  end

  def validate_title!
    return if title.is_a?(String) && !title.empty?

    raise ValidationError, "Title must be a non-empty string"
  end

  def validate_year!
    return if year.nil?

    return if year.is_a?(Integer) && year >= 1888 && year <= Date.today.year + 10

    raise ValidationError, "Year must be between 1888 and #{Date.today.year + 10}"
  end

  def validate_release_date!
    return if release_date.nil?
    return if release_date.is_a?(String) && release_date.strip.empty?

    raise ValidationError, "Release date must be a string or Date" unless release_date.is_a?(String) || release_date.is_a?(Date)

    # Try to parse if string
    Date.parse(release_date) if release_date.is_a?(String)
  rescue Date::Error
    raise ValidationError, "Invalid release date format"
  end
end
