# frozen_string_literal: true

require_relative "base_dto"
require_relative "actor_dto"

# DTO for search results
class SearchResultsDTO < BaseDTO
  protected

  def required_fields
    %i[actors]
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
    validate_actors!
    validate_pagination!
  end

  private

  def validate_actors!
    raise ValidationError, "Actors must be an array" unless actors.is_a?(Array)

    # Convert actor hashes to ActorDTO if needed
    @attributes[:actors] = actors.map do |actor|
      actor.is_a?(ActorDTO) ? actor : ActorDTO.new(actor)
    end
    @actors = @attributes[:actors]
  end

  def validate_pagination!
    raise ValidationError, "Total results must be a non-negative integer" unless total_results.is_a?(Integer) && total_results >= 0

    raise ValidationError, "Total pages must be a non-negative integer" unless total_pages.is_a?(Integer) && total_pages >= 0

    return if page.is_a?(Integer) && page.positive?

    raise ValidationError, "Page must be a positive integer"
  end
end
