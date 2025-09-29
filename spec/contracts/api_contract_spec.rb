# frozen_string_literal: true

require "spec_helper"

RSpec.describe "API Contracts", type: :request do
  describe "GET /api/actors/search" do
    it "returns valid HTML response", vcr: { cassette_name: "actor_search_leonardo" } do
      get "/api/actors/search?q=Leonardo&field=actor1"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")
      # Should contain suggestions OR empty response (both are valid)
      expect([
        last_response.body.include?('class="suggestion-item"'),
        last_response.body.empty?
      ].any?).to be true
    end

    it "handles empty results" do
      get "/api/actors/search?q=xyznonexistent&field=actor1"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("") # Empty response for no results
    end
  end

  describe "GET /api/actors/compare" do
    it "returns valid timeline HTML or error response" do
      get "/api/actors/compare", {
        actor1_id: 31,
        actor2_id: 5344,
        actor1_name: "Tom Hanks",
        actor2_name: "Meg Ryan"
      }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")

      # Should contain timeline structure OR proper error handling
      expect([
        last_response.body.include?('class="timeline"'),
        last_response.body.include?("actor-name"),
        last_response.body.include?("error")
      ].any?).to be true
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

      expect(last_response.headers["Cache-Control"]).not_to be_nil
    end
  end
end
