# frozen_string_literal: true

require "spec_helper"

RSpec.describe TMDBService do
  let(:service) { TMDBService.new }
  let(:api_key) { "test_api_key" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TMDB_API_KEY").and_return(api_key)
  end

  describe "#search_actors" do
    context "with valid query" do
      let(:query) { "Leonardo DiCaprio" }
      let(:mock_response) do
        {
          "results" => [
            {
              "id" => 6193,
              "name" => "Leonardo DiCaprio",
              "popularity" => 45.8,
              "profile_path" => "/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg",
              "known_for_department" => "Acting",
              "known_for" => [
                { "title" => "Inception" },
                { "title" => "The Wolf of Wall Street" }
              ]
            },
            {
              "id" => 123,
              "name" => "Leonardo Nam",
              "popularity" => 5.2,
              "profile_path" => "/test.jpg",
              "known_for_department" => "Acting",
              "known_for" => []
            }
          ]
        }
      end

      before do
        stub_request(:get, "https://api.themoviedb.org/3/search/person")
          .with(
            query: hash_including(
              api_key: api_key,
              query: query
            )
          )
          .to_return(
            status: 200,
            body: mock_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns actor search results" do
        results = service.search_actors(query)

        expect(results).to be_an(Array)
        expect(results.length).to eq(2)
        expect(results.first[:name]).to eq("Leonardo DiCaprio")
        expect(results.first[:id]).to eq(6193)
      end

      it "caches the results" do
        # First call should make HTTP request
        results1 = service.search_actors(query)
        expect(results1.first[:name]).to eq("Leonardo DiCaprio")

        # Reset WebMock to track new requests
        WebMock.reset_executed_requests!

        # Second call should use cache (no new HTTP requests)
        results2 = service.search_actors(query)
        expect(results2.first[:name]).to eq("Leonardo DiCaprio")

        # Verify no new requests were made
        expect(a_request(:get, "https://api.themoviedb.org/3/search/person")).to have_been_made.times(0)
      end
    end

    context "with empty query" do
      it "returns empty array for empty string" do
        result = service.search_actors("")
        expect(result).to eq([])
      end

      it "returns empty array for nil query" do
        result = service.search_actors(nil)
        expect(result).to eq([])
      end
    end

    context "with API error" do
      let(:query) { "test" }

      before do
        stub_request(:get, "https://api.themoviedb.org/3/search/person")
          .with(query: hash_including(api_key: api_key, query: query))
          .to_return(status: 401, body: { status_message: "Invalid API key" }.to_json)
      end

      it "returns empty array on API error" do
        result = service.search_actors(query)
        expect(result).to eq([])
      end
    end
  end

  describe "#get_actor_movies" do
    let(:actor_id) { 6193 }
    let(:mock_movies) do
      {
        cast: [
          {
            id: 27_205,
            title: "Inception",
            character: "Dom Cobb",
            release_date: "2010-07-16",
            poster_path: "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg"
          },
          {
            id: 640,
            title: "Catch Me If You Can",
            character: "Frank Abagnale Jr.",
            release_date: "2002-12-25",
            poster_path: "/ctjEj2xM32OvBXCq8zAdK3ZrsAj.jpg"
          }
        ]
      }
    end

    before do
      stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}/movie_credits")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: mock_movies.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns actor filmography" do
      movies = service.get_actor_movies(actor_id)

      expect(movies).to be_an(Array)
      expect(movies.length).to eq(2)
      expect(movies.first[:title]).to eq("Inception")
      expect(movies.first[:character]).to eq("Dom Cobb")
    end

    it "caches the results" do
      # First call should make HTTP request
      movies1 = service.get_actor_movies(actor_id)
      expect(movies1.first[:title]).to eq("Inception")

      # Reset WebMock to track new requests
      WebMock.reset_executed_requests!

      # Second call should use cache (no new HTTP requests)
      movies2 = service.get_actor_movies(actor_id)
      expect(movies2.first[:title]).to eq("Inception")

      # Verify no new requests were made after cache reset
      expect(a_request(:get,
                       "https://api.themoviedb.org/3/person/#{actor_id}/movie_credits")).to have_been_made.times(0)
    end

    context "with invalid actor ID" do
      before do
        stub_request(:get, "https://api.themoviedb.org/3/person/999999/movie_credits")
          .with(query: hash_including(api_key: api_key))
          .to_return(status: 404, body: { status_message: "The resource you requested could not be found." }.to_json)
      end

      it "returns empty array on invalid actor ID" do
        result = service.get_actor_movies(999_999)
        expect(result).to eq([])
      end
    end
  end

  describe "#get_actor_profile" do
    let(:actor_id) { 6193 }
    let(:mock_profile) do
      {
        id: 6193,
        name: "Leonardo DiCaprio",
        biography: "Leonardo Wilhelm DiCaprio is an American actor...",
        birthday: "1974-11-11",
        place_of_birth: "Los Angeles, California, USA",
        profile_path: "/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg"
      }
    end

    before do
      stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: mock_profile.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns actor profile" do
      profile = service.get_actor_profile(actor_id)

      expect(profile[:name]).to eq("Leonardo DiCaprio")
      expect(profile[:birthday]).to eq("1974-11-11")
      expect(profile[:place_of_birth]).to eq("Los Angeles, California, USA")
    end

    it "caches the results" do
      # First call should make HTTP request
      profile1 = service.get_actor_profile(actor_id)
      expect(profile1[:name]).to eq("Leonardo DiCaprio")

      # Reset WebMock to track new requests
      WebMock.reset_executed_requests!

      # Second call should use cache (no new HTTP requests)
      profile2 = service.get_actor_profile(actor_id)
      expect(profile2[:name]).to eq("Leonardo DiCaprio")

      # Verify no new requests were made after cache reset
      expect(a_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}")).to have_been_made.times(0)
    end
  end

  describe "error handling" do
    context "when network request fails" do
      before do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_raise(StandardError.new("Network error"))
      end

      it "raises StandardError for search_actors" do
        expect { service.search_actors("test") }.to raise_error(StandardError, "Network error")
      end

      it "raises StandardError for get_actor_movies" do
        expect { service.get_actor_movies(123) }.to raise_error(StandardError, "Network error")
      end
    end

    context "when API returns invalid JSON" do
      before do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 200, body: "invalid json")
      end

      it "returns empty array on invalid JSON" do
        result = service.search_actors("test")
        expect(result).to eq([])
      end
    end
  end
end
