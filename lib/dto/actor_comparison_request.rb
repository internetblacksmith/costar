# frozen_string_literal: true

require_relative "base_dto"

# DTO for actor comparison requests
class ActorComparisonRequest < BaseDTO
  MAX_NAME_LENGTH = 100

  protected

  def required_fields
    %i[actor1_id actor2_id]
  end

  def optional_fields
    {
      actor1_name: nil,
      actor2_name: nil
    }
  end

  def validate!
    super
    validate_actor_ids!
    validate_actor_names!
  end

  private

  def validate_actor_ids!
    raise ValidationError, "Actor1 ID must be a positive integer" unless actor1_id.is_a?(Integer) && actor1_id.positive?

    raise ValidationError, "Actor2 ID must be a positive integer" unless actor2_id.is_a?(Integer) && actor2_id.positive?

    return unless actor1_id == actor2_id

    raise ValidationError, "Cannot compare an actor with themselves"
  end

  def validate_actor_names!
    validate_actor_name!(actor1_name, "Actor1") if actor1_name
    validate_actor_name!(actor2_name, "Actor2") if actor2_name
  end

  def validate_actor_name!(name, label)
    raise ValidationError, "#{label} name must be a string" unless name.is_a?(String)

    return unless name.length > MAX_NAME_LENGTH

    raise ValidationError, "#{label} name too long (max #{MAX_NAME_LENGTH} characters)"
  end
end
