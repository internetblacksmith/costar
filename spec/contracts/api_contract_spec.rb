# frozen_string_literal: true

require "spec_helper"
require "json_schema"

RSpec.describe "API Contracts", type: :request do
  describe "GET /api/actors/search" do
    let(:search_schema) do
      {
        type: "string",
        description: "HTML response with suggestion items"
      }
    end

    it "returns valid HTML response" do
      get "/api/actors/search?q=Tom&field=actor1"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")
      expect(last_response.body).to match(/<div class="suggestion-item"/)
    end

    it "handles empty results" do
      get "/api/actors/search?q=xyznonexistent&field=actor1"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("") # Empty response for no results
    end
  end

  describe "GET /api/actors/compare" do
    it "returns valid timeline HTML" do
      get "/api/actors/compare?actor1_id=31&actor2_id=5344"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")

      # Should contain timeline structure
      expect(last_response.body).to include("timeline")
      expect(last_response.body).to include("actor-name")
    end

    it "returns error for invalid actor IDs" do
      get "/api/actors/compare?actor1_id=invalid&actor2_id=invalid"

      expect(last_response.status).to eq(200) # HTMX expects 200 with error content
      expect(last_response.body).to include("error")
    end
  end

  describe "Response Headers" do
    it "includes required security headers" do
      get "/"

      required_headers = %w[
        X-Content-Type-Options
        X-Frame-Options
        X-XSS-Protection
        Content-Security-Policy
      ]

      required_headers.each do |header|
        expect(last_response.headers).to have_key(header)
      end
    end

    it "includes cache headers for static assets" do
      get "/css/main.css"

      expect(last_response.headers["Cache-Control"]).to be_present
    end
  end
end
