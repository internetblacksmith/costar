# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ActorSync Application", type: :request do
  describe "GET /" do
    it "renders the main page" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("ActorSync")
    end
  end

  describe "GET /health/complete" do
    before do
      # Mock the TMDB API health check
      stub_request(:get, "https://api.themoviedb.org/3/search/person")
        .with(query: hash_including(query: "test"))
        .to_return(status: 200, body: { results: [] }.to_json)
    end

    it "returns health status" do
      get "/health/complete"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("application/json")

      response_data = JSON.parse(last_response.body)
      expect(response_data).to have_key("status")
    end
  end
end
