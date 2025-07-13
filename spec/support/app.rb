# frozen_string_literal: true

# App definition for Rack::Test
def app
  ActorSyncApp
end

# Helper methods for testing
module TestHelpers
  def json_response
    JSON.parse(last_response.body)
  end

  def mock_tmdb_actor_search(query, results = [])
    # Mock at the service level for unit tests
    # For integration tests, use VCR cassettes instead
    tmdb_service = app.settings.tmdb_service
    allow(tmdb_service).to receive(:search_actors).with(query).and_return(results)
  end

  def mock_tmdb_actor_movies(actor_id, movies = [])
    # Mock at the service level for unit tests
    # For integration tests, use VCR cassettes instead
    tmdb_service = app.settings.tmdb_service
    # Handle both string and integer versions of actor_id
    allow(tmdb_service).to receive(:get_actor_movies).with(actor_id.to_i).and_return(movies)
    allow(tmdb_service).to receive(:get_actor_movies).with(actor_id.to_s).and_return(movies)
  end

  def mock_tmdb_actor_profile(actor_id, profile = {})
    # Mock at the service level for unit tests
    # For integration tests, use VCR cassettes instead
    tmdb_service = app.settings.tmdb_service
    # Handle both string and integer versions of actor_id
    allow(tmdb_service).to receive(:get_actor_profile).with(actor_id.to_i).and_return(profile)
    allow(tmdb_service).to receive(:get_actor_profile).with(actor_id.to_s).and_return(profile)
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
