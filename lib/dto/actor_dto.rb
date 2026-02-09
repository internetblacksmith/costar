# frozen_string_literal: true

require_relative "base_dto"

# DTO for actor data
class ActorDTO < BaseDTO
  protected

  def required_fields
    %i[id name]
  end

  def optional_fields
    {
      character: nil,
      character_in_movie1: nil,
      character_in_movie2: nil,
      profile_path: nil,
      popularity: 0.0,
      known_for_department: nil,
      known_for: [],
      biography: nil,
      birthday: nil,
      place_of_birth: nil
    }
  end

  def validate!
    super
    validate_id!
    validate_name!
    validate_known_for!
  end

  private

  def validate_id!
    return if id.is_a?(Integer) && id.positive?

    raise ValidationError, "ID must be a positive integer"
  end

  def validate_name!
    return if name.is_a?(String) && !name.empty?

    raise ValidationError, "Name must be a non-empty string"
  end

  def validate_known_for!
    raise ValidationError, "Known for must be an array" unless known_for.is_a?(Array)

    known_for.each do |item|
      raise ValidationError, "Known for items must have a title" unless item.is_a?(Hash) && item.key?(:title)
    end
  end
end
