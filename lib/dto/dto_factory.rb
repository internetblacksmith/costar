# frozen_string_literal: true

require_relative "actor_dto"
require_relative "movie_dto"
require_relative "search_results_dto"
require_relative "movie_search_results_dto"
require_relative "comparison_result_dto"
require_relative "movie_comparison_result_dto"

# Factory for creating DTOs from API responses
class DTOFactory
  class << self
    # Create ActorDTO from TMDB API response
    def actor_from_api(api_data)
      return nil unless api_data

      ActorDTO.new(
        id: api_data["id"] || api_data[:id],
        name: api_data["name"] || api_data[:name],
        profile_path: api_data["profile_path"] || api_data[:profile_path],
        popularity: api_data["popularity"] || api_data[:popularity] || 0.0,
        known_for_department: api_data["known_for_department"] || api_data[:known_for_department],
        known_for: extract_known_for(api_data),
        biography: api_data["biography"] || api_data[:biography],
        birthday: api_data["birthday"] || api_data[:birthday],
        place_of_birth: api_data["place_of_birth"] || api_data[:place_of_birth]
      )
    end

    # Create MovieDTO from TMDB API response
    def movie_from_api(api_data)
      return nil unless api_data

      release_date = api_data["release_date"] || api_data[:release_date]
      # Validate release date format before creating DTO
      if release_date.is_a?(String) && release_date != ""
        begin
          Date.parse(release_date)
        rescue Date::Error
          release_date = nil # Set to nil if invalid
        end
      end

      MovieDTO.new(
        id: api_data["id"] || api_data[:id],
        title: api_data["title"] || api_data[:title],
        character: api_data["character"] || api_data[:character],
        release_date: release_date,
        year: extract_year(api_data),
        poster_path: api_data["poster_path"] || api_data[:poster_path],
        overview: api_data["overview"] || api_data[:overview],
        vote_average: api_data["vote_average"] || api_data[:vote_average] || 0.0,
        popularity: api_data["popularity"] || api_data[:popularity] || 0.0
      )
    end

    # Create SearchResultsDTO from search response
    def search_results_from_api(api_response, query_params = {})
      return SearchResultsDTO.new(actors: []) unless api_response

      actors = (api_response["results"] || api_response[:results] || []).map do |actor_data|
        actor_from_api(actor_data)
      end.compact

      SearchResultsDTO.new(
        actors: actors,
        total_results: api_response["total_results"] || api_response[:total_results] || actors.size,
        total_pages: api_response["total_pages"] || api_response[:total_pages] || 1,
        page: api_response["page"] || api_response[:page] || query_params[:page] || 1
      )
    end

    # Create MovieSearchResultsDTO from movie search response
    def movie_search_results_from_api(api_response, query_params = {})
      return MovieSearchResultsDTO.new(movies: []) unless api_response

      movies = (api_response["results"] || api_response[:results] || []).map do |movie_data|
        movie_from_api(movie_data)
      end.compact

      MovieSearchResultsDTO.new(
        movies: movies,
        total_results: api_response["total_results"] || api_response[:total_results] || movies.size,
        total_pages: api_response["total_pages"] || api_response[:total_pages] || 1,
        page: api_response["page"] || api_response[:page] || query_params[:page] || 1
      )
    end

    # Create MovieComparisonResultDTO from service response
    def movie_comparison_result_from_service(service_data)
      return nil unless service_data

      # Extract movie data
      movie1_data = extract_movie_data(service_data, 1)
      movie2_data = extract_movie_data(service_data, 2)

      # Create actor DTOs (handle both raw data and existing DTOs)
      movie1_cast = convert_actors_array(service_data[:movie1_cast])
      movie2_cast = convert_actors_array(service_data[:movie2_cast])
      shared_actors = convert_actors_array(service_data[:shared_actors])

      MovieComparisonResultDTO.new(
        movie1: movie_from_api(movie1_data),
        movie2: movie_from_api(movie2_data),
        movie1_cast: movie1_cast,
        movie2_cast: movie2_cast,
        shared_actors: shared_actors,
        metadata: extract_movie_comparison_metadata(service_data)
      )
    end

    # Create ComparisonResultDTO from service response
    def comparison_result_from_service(service_data)
      return nil unless service_data

      # Extract actor data
      actor1_data = extract_actor_data(service_data, 1)
      actor2_data = extract_actor_data(service_data, 2)

      # Create movie DTOs (handle both raw data and existing DTOs)
      actor1_movies = convert_movies_array(service_data[:actor1_movies])
      actor2_movies = convert_movies_array(service_data[:actor2_movies])
      shared_movies = convert_movies_array(service_data[:shared_movies])

      ComparisonResultDTO.new(
        actor1: actor_from_api(actor1_data),
        actor2: actor_from_api(actor2_data),
        actor1_movies: actor1_movies,
        actor2_movies: actor2_movies,
        shared_movies: shared_movies,
        timeline_data: service_data[:timeline_data] || build_empty_timeline,
        metadata: extract_metadata(service_data)
      )
    end

    private

    def extract_known_for(api_data)
      known_for = api_data["known_for"] || api_data[:known_for] || []
      known_for.map do |item|
        {
          title: item["title"] || item[:title] || item["name"] || item[:name]
        }
      end
    end

    def extract_year(api_data)
      year = api_data["year"] || api_data[:year]
      return year if year

      release_date = api_data["release_date"] || api_data[:release_date]
      return nil unless release_date

      Date.parse(release_date.to_s).year
    rescue StandardError
      nil
    end

    def extract_actor_data(service_data, actor_num)
      {
        id: service_data[:"actor#{actor_num}_id"],
        name: service_data[:"actor#{actor_num}_name"],
        profile_path: service_data[:"actor#{actor_num}_profile_path"]
      }
    end

    def build_empty_timeline
      {
        years: [],
        shared_movies: [],
        processed_movies: {},
        shared_movies_by_year: {}
      }
    end

    def convert_movies_array(movies)
      return [] unless movies

      movies.map do |movie|
        if movie.is_a?(MovieDTO)
          movie
        else
          movie_from_api(movie)
        end
      end.compact
    end

    def extract_metadata(service_data)
      {
        comparison_date: Time.now.iso8601,
        total_movies: {
          actor1: service_data[:actor1_movies]&.size || 0,
          actor2: service_data[:actor2_movies]&.size || 0,
          shared: service_data[:shared_movies]&.size || 0
        }
      }
    end

    def extract_movie_data(service_data, movie_num)
      {
        id: service_data[:"movie#{movie_num}_id"],
        title: service_data[:"movie#{movie_num}_title"],
        poster_path: service_data[:"movie#{movie_num}_poster_path"],
        release_date: service_data[:"movie#{movie_num}_release_date"],
        year: service_data[:"movie#{movie_num}_year"]
      }
    end

    def convert_actors_array(actors)
      return [] unless actors

      actors.map do |actor|
        if actor.is_a?(ActorDTO)
          actor
        else
          actor_from_api(actor)
        end
      end.compact
    end

    def extract_movie_comparison_metadata(service_data)
      {
        comparison_date: Time.now.iso8601,
        total_cast: {
          movie1: service_data[:movie1_cast]&.size || 0,
          movie2: service_data[:movie2_cast]&.size || 0,
          shared: service_data[:shared_actors]&.size || 0
        }
      }
    end
  end
end
