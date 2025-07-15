# frozen_string_literal: true

require_relative "cache_manager"
require_relative "../middleware/error_handler_module"
require_relative "../dto/dto_factory"
require_relative "../dto/comparison_result_dto"

# Service for comparing actors and building timeline data
class ActorComparisonService
  include ErrorHandlerModule
  def initialize(tmdb_service: nil, timeline_builder: nil, cache: nil)
    @tmdb_service = tmdb_service || TMDBService.new
    @timeline_builder = timeline_builder # TimelineBuilder is created per comparison
    @cache_manager = cache || CacheManager.new
  end

  def compare(actor1_id, actor2_id, actor1_name, actor2_name)
    validate_actor_ids(actor1_id, actor2_id)

    # Cache the entire comparison result to avoid redundant processing
    cached_data = @cache_manager.cache_actor_comparison(actor1_id, actor2_id) do
      perform_comparison(actor1_id, actor2_id, actor1_name, actor2_name)
    end

    # Convert to DTO if not already
    return cached_data if cached_data.is_a?(ComparisonResultDTO)

    DTOFactory.comparison_result_from_service(cached_data)
  end

  private

  def perform_comparison(actor1_id, actor2_id, actor1_name, actor2_name)
    # Use batch operations to reduce N+1 cache queries
    actor_ids = [actor1_id, actor2_id]

    # Batch fetch movies and profiles
    movies_data = fetch_actor_movies_batch(actor_ids)
    profiles_data = fetch_actor_profiles_batch(actor_ids)

    # Get actor names (batch operation to reduce cache hits)
    names_data = fetch_actor_names_batch(actor_ids, actor1_name, actor2_name)

    timeline_data = build_timeline_data(movies_data, names_data[:actor1], names_data[:actor2])

    build_comparison_result(
      movies_data, profiles_data, timeline_data,
      { actor1: names_data[:actor1], actor2: names_data[:actor2] },
      { actor1: actor1_id, actor2: actor2_id }
    )
  end

  def validate_actor_ids(actor1_id, actor2_id)
    raise ValidationError, "Actor IDs cannot be nil" if actor1_id.nil? || actor2_id.nil?
  end

  def fetch_actor_movies_batch(actor_ids)
    # Individual calls for movies since they're already cached by TMDBService
    {
      actor1: @tmdb_service.get_actor_movies(actor_ids[0]),
      actor2: @tmdb_service.get_actor_movies(actor_ids[1])
    }
  end

  def fetch_actor_profiles_batch(actor_ids)
    # Use batch operation for profiles to reduce cache round trips
    profiles = @cache_manager.batch_actor_profiles(actor_ids) do |missing_ids|
      # Fetch missing profiles from TMDB
      missing_profiles = {}
      missing_ids.each do |actor_id|
        profile_key = @cache_manager.key_builder.actor_profile(actor_id)
        profile_data = fetch_profile_from_tmdb(actor_id)
        missing_profiles[profile_key] = profile_data
      end
      missing_profiles
    end

    # Convert batch results back to expected format
    {
      actor1: profiles[@cache_manager.key_builder.actor_profile(actor_ids[0])],
      actor2: profiles[@cache_manager.key_builder.actor_profile(actor_ids[1])]
    }
  end

  def fetch_actor_names_batch(actor_ids, provided_name1, provided_name2)
    actor1_name = provided_name1 || get_cached_actor_name(actor_ids[0])
    actor2_name = provided_name2 || get_cached_actor_name(actor_ids[1])

    {
      actor1: actor1_name,
      actor2: actor2_name
    }
  end

  def get_cached_actor_name(actor_id)
    @cache_manager.cache_actor_name(actor_id) do
      actor_details = @tmdb_service.get_actor_details(actor_id)
      actor_details.name || "Unknown Actor"
    rescue TMDBError => e
      handle_tmdb_error(e, "getting actor name")
      "Unknown Actor"
    end
  end

  def fetch_profile_from_tmdb(actor_id)
    @tmdb_service.get_actor_profile(actor_id)
  rescue TMDBError => e
    handle_tmdb_error(e, "getting profile")
    { profile_path: nil }
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

  def build_comparison_result(movies_data, profiles_data, timeline_data, actor_names, actor_ids)
    {
      actor1_movies: movies_data[:actor1],
      actor2_movies: movies_data[:actor2],
      actor1_name: actor_names[:actor1],
      actor2_name: actor_names[:actor2],
      actor1_id: actor_ids[:actor1],
      actor2_id: actor_ids[:actor2],
      actor1_profile_path: extract_profile_path(profiles_data[:actor1]),
      actor2_profile_path: extract_profile_path(profiles_data[:actor2]),
      timeline_data: timeline_data
    }
  end

  def extract_profile_path(profile_data)
    return nil unless profile_data

    if profile_data.respond_to?(:profile_path)
      profile_data.profile_path
    elsif profile_data.is_a?(Hash)
      profile_data[:profile_path] || profile_data["profile_path"]
    end
  end

  def handle_tmdb_error(error, operation)
    message = "TMDB Error #{operation}: #{error.message}"
    if defined?(Configuration) && Configuration.instance.development?
      puts message
    else
      StructuredLogger.error("ActorComparisonService Error",
                             type: "service_error",
                             service: "actor_comparison",
                             operation: operation,
                             error: error.message,
                             error_class: error.class.name)
    end
  end
end
