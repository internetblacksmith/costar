# frozen_string_literal: true

##
# Provides fallback responses for TMDB API endpoints
#
# Centralizes the logic for generating appropriate fallback data
# when the TMDB API is unavailable or returns errors.
#
class TMDBFallbackProvider
  FALLBACK_RESPONSES = {
    search_person: {
      "results" => [],
      "total_results" => 0,
      "total_pages" => 0,
      "page" => 1
    },
    movie_credits: {
      "cast" => [],
      "crew" => [],
      "id" => 0
    },
    person_details: {
      "id" => 0,
      "name" => "Unknown Actor",
      "biography" => "",
      "profile_path" => nil,
      "known_for_department" => "Acting"
    },
    default: {
      "error" => "Service temporarily unavailable",
      "fallback" => true
    }
  }.freeze

  ##
  # Generate fallback data for a given endpoint
  #
  # @param endpoint [String] The TMDB API endpoint
  # @return [Hash] Appropriate fallback data for the endpoint
  #
  def self.for_endpoint(endpoint)
    response_type = determine_response_type(endpoint)
    FALLBACK_RESPONSES[response_type].dup
  end

  ##
  # Determine the type of response needed based on the endpoint
  #
  # @param endpoint [String] The TMDB API endpoint
  # @return [Symbol] The response type key
  #
  def self.determine_response_type(endpoint)
    case endpoint
    when %r{search/person}
      :search_person
    when %r{person/\d+/movie_credits}
      :movie_credits
    when %r{person/\d+$}
      :person_details
    else
      :default
    end
  end

  ##
  # Check if a response is a fallback response
  #
  # @param response [Hash] The response to check
  # @return [Boolean] True if this is a fallback response
  #
  def self.fallback?(response)
    response.is_a?(Hash) && response["fallback"] == true
  end
end