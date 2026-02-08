# frozen_string_literal: true

require_relative "base_dto"

# DTO for movie search requests
class MovieSearchRequest < BaseDTO
  MAX_QUERY_LENGTH = 100
  VALID_FIELDS = %w[movie1 movie2].freeze

  protected

  def required_fields
    %i[field]
  end

  def optional_fields
    {
      query: nil,
      page: 1,
      limit: 10
    }
  end

  def validate!
    super
    validate_query!
    validate_field!
    validate_pagination!
  end

  private

  def validate_query!
    return if query.nil? # Allow nil for empty searches

    raise ValidationError, "Query must be a string" unless query.is_a?(String)

    return unless query.length > MAX_QUERY_LENGTH

    raise ValidationError, "Query too long (max #{MAX_QUERY_LENGTH} characters)"
  end

  def validate_field!
    return if VALID_FIELDS.include?(field)

    raise ValidationError, "Invalid field: #{field}. Must be one of: #{VALID_FIELDS.join(", ")}"
  end

  def validate_pagination!
    raise ValidationError, "Page must be a positive integer" unless page.is_a?(Integer) && page.positive?

    return if limit.is_a?(Integer) && limit.positive? && limit <= 100

    raise ValidationError, "Limit must be a positive integer (max 100)"
  end
end
