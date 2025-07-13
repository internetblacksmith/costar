# frozen_string_literal: true

require_relative "base_dto"
require_relative "actor_dto"
require_relative "movie_dto"

# DTO for actor comparison results
class ComparisonResultDTO < BaseDTO
  protected

  def required_fields
    %i[actor1 actor2 actor1_movies actor2_movies timeline_data]
  end

  def optional_fields
    {
      shared_movies: [],
      metadata: {}
    }
  end

  def validate!
    super
    validate_actors!
    validate_movies!
    validate_timeline_data!
  end

  private

  def validate_actors!
    # Convert to ActorDTO if needed
    @attributes[:actor1] = ensure_actor_dto(actor1, "Actor1")
    @actor1 = @attributes[:actor1]

    @attributes[:actor2] = ensure_actor_dto(actor2, "Actor2")
    @actor2 = @attributes[:actor2]
  end

  def ensure_actor_dto(actor, label)
    return actor if actor.is_a?(ActorDTO)

    ActorDTO.new(actor)
  rescue StandardError => e
    raise ValidationError, "#{label} data invalid: #{e.message}"
  end

  def validate_movies!
    @attributes[:actor1_movies] = ensure_movie_array(actor1_movies, "Actor1")
    @actor1_movies = @attributes[:actor1_movies]

    @attributes[:actor2_movies] = ensure_movie_array(actor2_movies, "Actor2")
    @actor2_movies = @attributes[:actor2_movies]

    @attributes[:shared_movies] = ensure_movie_array(shared_movies, "Shared")
    @shared_movies = @attributes[:shared_movies]
  end

  def ensure_movie_array(movies, label)
    raise ValidationError, "#{label} movies must be an array" unless movies.is_a?(Array)

    movies.map do |movie|
      movie.is_a?(MovieDTO) ? movie : MovieDTO.new(movie)
    end
  rescue StandardError => e
    raise ValidationError, "#{label} movie data invalid: #{e.message}"
  end

  def validate_timeline_data!
    raise ValidationError, "Timeline data must be a hash" unless timeline_data.is_a?(Hash)

    required_timeline_fields = %i[years shared_movies processed_movies shared_movies_by_year]
    missing_fields = required_timeline_fields - timeline_data.keys

    return if missing_fields.empty?

    raise ValidationError, "Timeline data missing fields: #{missing_fields.join(", ")}"
  end
end
