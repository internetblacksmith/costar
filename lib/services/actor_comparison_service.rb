# frozen_string_literal: true

# Service for comparing actors and building timeline data
class ActorComparisonService
  def initialize(tmdb_service = nil)
    @tmdb_service = tmdb_service || TMDBService.new
  end

  def compare(actor1_id, actor2_id, actor1_name, actor2_name)
    raise ValidationError, "Actor IDs cannot be nil" if actor1_id.nil? || actor2_id.nil?

    # Fetch movies concurrently if possible
    actor1_movies = @tmdb_service.get_actor_movies(actor1_id)
    actor2_movies = @tmdb_service.get_actor_movies(actor2_id)

    # Get actor profiles for the portraits
    actor1_profile = get_actor_profile(actor1_id)
    actor2_profile = get_actor_profile(actor2_id)

    # Build timeline data
    timeline_builder = TimelineBuilder.new(
      actor1_movies, 
      actor2_movies, 
      actor1_name, 
      actor2_name
    )
    
    timeline_data = timeline_builder.build

    {
      actor1_movies: actor1_movies,
      actor2_movies: actor2_movies,
      actor1_name: actor1_name,
      actor2_name: actor2_name,
      actor1_profile: actor1_profile,
      actor2_profile: actor2_profile,
      years: timeline_data[:years],
      shared_movies: timeline_data[:shared_movies],
      processed_movies: timeline_data[:processed_movies]
    }
  end

  private

  def get_actor_profile(actor_id)
    # First try to get from cache
    cache_key = "actor_profile_#{actor_id}"
    cached_result = Cache.get(cache_key)
    return cached_result if cached_result

    # If not cached, fetch from TMDB
    begin
      profile_data = @tmdb_service.get_actor_profile(actor_id)
      Cache.set(cache_key, profile_data, 3600) # 1 hour cache
      profile_data
    rescue TMDBError => e
      puts "TMDB Error getting profile: #{e.message}" if Configuration.instance.development?
      { profile_path: nil }
    end
  end
end