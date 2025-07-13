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
    # Mock at the service level for integration tests
    tmdb_service = app.settings.tmdb_service
    allow(tmdb_service).to receive(:search_actors).with(query).and_return(results)

    # Also stub HTTP requests as fallback
    stub_request(:get, %r{api\.themoviedb\.org/3/search/person})
      .to_return(
        status: 200,
        body: { results: results }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def mock_tmdb_actor_movies(actor_id, movies = [])
    # Mock at the service level for integration tests
    tmdb_service = app.settings.tmdb_service
    # Handle both string and integer versions of actor_id
    allow(tmdb_service).to receive(:get_actor_movies).with(actor_id.to_i).and_return(movies)
    allow(tmdb_service).to receive(:get_actor_movies).with(actor_id.to_s).and_return(movies)

    # Also stub HTTP requests as fallback
    stub_request(:get, %r{api\.themoviedb\.org/3/person/#{actor_id}/movie_credits})
      .to_return(
        status: 200,
        body: { cast: movies }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def mock_tmdb_actor_profile(actor_id, profile = {})
    # Mock at the service level for integration tests
    tmdb_service = app.settings.tmdb_service
    # Handle both string and integer versions of actor_id
    allow(tmdb_service).to receive(:get_actor_profile).with(actor_id.to_i).and_return(profile)
    allow(tmdb_service).to receive(:get_actor_profile).with(actor_id.to_s).and_return(profile)

    # Also stub HTTP requests as fallback (with or without query params)
    stub_request(:get, %r{api\.themoviedb\.org/3/person/#{actor_id}(\?|$)})
      .to_return(
        status: 200,
        body: profile.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
