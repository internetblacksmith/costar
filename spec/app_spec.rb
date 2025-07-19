# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MovieTogether Application", type: :request do
  describe "GET /" do
    it "renders the main page" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("MovieTogether")
    end
  end

  describe "GET /health/complete" do
    it "returns health status", vcr: { cassette_name: "health_check_app" } do
      get "/health/complete"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("application/json")

      response_data = JSON.parse(last_response.body)
      expect(response_data).to have_key("status")
    end
  end
end
