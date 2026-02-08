# frozen_string_literal: true

require_relative "base_dto"
require_relative "actor_dto"
require_relative "movie_dto"

# DTO for movie comparison results (finding shared actors between two movies)
class MovieComparisonResultDTO < BaseDTO
  protected

  def required_fields
    %i[movie1 movie2 movie1_cast movie2_cast]
  end

  def optional_fields
    {
      shared_actors: [],
      metadata: {}
    }
  end

  def validate!
    super
    validate_movies!
    validate_casts!
  end

  private

  def validate_movies!
    # Convert to MovieDTO if needed
    @attributes[:movie1] = ensure_movie_dto(movie1, "Movie1")
    @movie1 = @attributes[:movie1]

    @attributes[:movie2] = ensure_movie_dto(movie2, "Movie2")
    @movie2 = @attributes[:movie2]
  end

  def ensure_movie_dto(movie, label)
    return movie if movie.is_a?(MovieDTO)

    MovieDTO.new(movie)
  rescue StandardError => e
    raise ValidationError, "#{label} data invalid: #{e.message}"
  end

  def validate_casts!
    @attributes[:movie1_cast] = ensure_actor_array(movie1_cast, "Movie1")
    @movie1_cast = @attributes[:movie1_cast]

    @attributes[:movie2_cast] = ensure_actor_array(movie2_cast, "Movie2")
    @movie2_cast = @attributes[:movie2_cast]

    @attributes[:shared_actors] = ensure_actor_array(shared_actors, "Shared")
    @shared_actors = @attributes[:shared_actors]
  end

  def ensure_actor_array(actors, label)
    raise ValidationError, "#{label} cast must be an array" unless actors.is_a?(Array)

    actors.map do |actor|
      actor.is_a?(ActorDTO) ? actor : ActorDTO.new(actor)
    end
  rescue StandardError => e
    raise ValidationError, "#{label} cast data invalid: #{e.message}"
  end
end
