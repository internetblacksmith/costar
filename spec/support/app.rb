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
    stub_request(:get, "https://api.themoviedb.org/3/search/person")
      .with(query: hash_including(query: query))
      .to_return(
        status: 200,
        body: { results: results }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def mock_tmdb_actor_movies(actor_id, movies = [])
    stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}/movie_credits")
      .to_return(
        status: 200,
        body: { cast: movies }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def mock_tmdb_actor_profile(actor_id, profile = {})
    stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}")
      .to_return(
        status: 200,
        body: profile.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end