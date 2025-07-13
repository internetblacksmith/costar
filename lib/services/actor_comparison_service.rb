# frozen_string_literal: true

# Service for comparing actors and building timeline data
class ActorComparisonService
  def initialize(tmdb_service = nil)
    @tmdb_service = tmdb_service || TMDBService.new
  end

  def compare(actor1_id, actor2_id, actor1_name, actor2_name)
    validate_actor_ids(actor1_id, actor2_id)

    movies_data = fetch_actor_movies(actor1_id, actor2_id)
    profiles_data = fetch_actor_profiles(actor1_id, actor2_id)
    timeline_data = build_timeline_data(movies_data, actor1_name, actor2_name)

    build_comparison_result(movies_data, profiles_data, timeline_data, actor1_name, actor2_name, actor1_id, actor2_id)
  end

  private

  def validate_actor_ids(actor1_id, actor2_id)
    raise ValidationError, "Actor IDs cannot be nil" if actor1_id.nil? || actor2_id.nil?
  end

  def fetch_actor_movies(actor1_id, actor2_id)
    {
      actor1: @tmdb_service.get_actor_movies(actor1_id),
      actor2: @tmdb_service.get_actor_movies(actor2_id)
    }
  end

  def fetch_actor_profiles(actor1_id, actor2_id)
    {
      actor1: get_actor_profile(actor1_id),
      actor2: get_actor_profile(actor2_id)
    }
  end

  def build_timeline_data(movies_data, actor1_name, actor2_name)
    timeline_builder = TimelineBuilder.new(
      movies_data[:actor1],
      movies_data[:actor2],
      actor1_name,
      actor2_name
    )
    timeline_builder.build
  end

  def build_comparison_result(movies_data, profiles_data, timeline_data, actor1_name, actor2_name, actor1_id, actor2_id)
    {
      actor1_movies: movies_data[:actor1],
      actor2_movies: movies_data[:actor2],
      actor1_name: actor1_name,
      actor2_name: actor2_name,
      actor1_id: actor1_id,
      actor2_id: actor2_id,
      actor1_profile: profiles_data[:actor1],
      actor2_profile: profiles_data[:actor2],
      years: timeline_data[:years],
      shared_movies: timeline_data[:shared_movies],
      processed_movies: timeline_data[:processed_movies]
    }
  end

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
