# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Actor Search Flow Integration" do
  include Rack::Test::Methods

  describe "complete actor search and suggestion flow" do
    let(:actor_search_results) do
      [
        {
          "id" => 31,
          "name" => "Tom Hanks",
          "popularity" => 50.5,
          "profile_path" => "/xndWFsBlClOJFRdhSt4NBwiPq2o.jpg",
          "known_for_department" => "Acting",
          "known_for" => [
            { "title" => "Forrest Gump", "media_type" => "movie" },
            { "title" => "Cast Away", "media_type" => "movie" },
            { "title" => "Saving Private Ryan", "media_type" => "movie" }
          ]
        },
        {
          "id" => 32,
          "name" => "Tom Hardy",
          "popularity" => 35.2,
          "profile_path" => "/test.jpg",
          "known_for_department" => "Acting",
          "known_for" => [
            { "title" => "Mad Max: Fury Road", "media_type" => "movie" },
            { "title" => "The Dark Knight Rises", "media_type" => "movie" }
          ]
        },
        {
          "id" => 33,
          "name" => "Tom Cruise",
          "popularity" => 30.1,
          "profile_path" => "/test2.jpg",
          "known_for_department" => "Acting",
          "known_for" => [] # Actor with no known_for data
        }
      ]
    end

    before do
      # Mock the TMDB API search request at HTTP level
      stub_request(:get, %r{https://api.themoviedb.org/3/search/person})
        .with(query: hash_including("query" => "Tom"))
        .to_return(
          status: 200,
          body: { results: actor_search_results }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "searches for actors and displays suggestions with proper known_for formatting" do
      # Perform the search
      get "/api/actors/search", { q: "Tom", field: "actor1" }

      expect(last_response.status).to eq(200)

      # Parse the HTML response
      html = last_response.body

      # Verify all actors are displayed
      expect(html).to include("Tom Hanks")
      expect(html).to include("Tom Hardy")
      expect(html).to include("Tom Cruise")

      # Verify known_for is properly formatted
      expect(html).to include("Known for: Forrest Gump, Cast Away, Saving Private Ryan")
      expect(html).to include("Known for: Mad Max: Fury Road, The Dark Knight Rises")

      # Tom Cruise has no known_for, so it shouldn't appear
      expect(html.scan(/Tom Cruise.*?Known for:/m)).to be_empty

      # Verify no hash formatting artifacts
      expect(html).not_to include("{title:")
      expect(html).not_to match(/\bwn for:/) # Ensure "Known for:" is not truncated to just "wn for:"
      expect(html).not_to include("title: \"")

      # Verify onclick handlers are properly formatted
      expect(html).to include("selectActor('31', 'Tom Hanks', 'actor1')")
      expect(html).to include("selectActor('32', 'Tom Hardy', 'actor1')")
      expect(html).to include("selectActor('33', 'Tom Cruise', 'actor1')")
    end

    it "handles special characters in actor names correctly" do
      special_char_results = [
        {
          "id" => 100,
          "name" => "Lupita Nyong'o",
          "popularity" => 25.0,
          "profile_path" => "/test.jpg",
          "known_for_department" => "Acting",
          "known_for" => [
            { "title" => "Black Panther", "media_type" => "movie" },
            { "title" => "12 Years a Slave", "media_type" => "movie" }
          ]
        }
      ]

      stub_request(:get, %r{https://api.themoviedb.org/3/search/person})
        .with(query: hash_including("query" => "Lupita"))
        .to_return(
          status: 200,
          body: { results: special_char_results }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      get "/api/actors/search", { q: "Lupita", field: "actor2" }

      expect(last_response.status).to eq(200)
      html = last_response.body

      # Verify the apostrophe is properly escaped in the onclick handler
      # The apostrophe escaping is handled by the gsub in the view
      expect(html).to match(/selectActor\('100', 'Lupita Nyong.*o', 'actor2'\)/)
      expect(html).to include("Known for: Black Panther, 12 Years a Slave")
    end

    it "maintains field parameter throughout the flow" do
      # Mock the TMDB API for the test
      stub_request(:get, %r{https://api.themoviedb.org/3/search/person})
        .with(query: hash_including("query" => "Tom"))
        .to_return(
          status: 200,
          body: { results: actor_search_results }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      
      # Test with actor1 field
      get "/api/actors/search", { q: "Tom", field: "actor1" }
      expect(last_response.body).to include("'actor1')")
      expect(last_response.body).not_to include("'actor2')")

      # Test with actor2 field
      get "/api/actors/search", { q: "Tom", field: "actor2" }
      expect(last_response.body).to include("'actor2')")
      expect(last_response.body).not_to include("'actor1')")
    end

    context "when search returns no results" do
      before do
        stub_request(:get, %r{https://api.themoviedb.org/3/search/person})
          .with(query: hash_including("query" => "NonexistentActor"))
          .to_return(
            status: 200,
            body: { results: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns empty response gracefully" do
        get "/api/actors/search", { q: "NonexistentActor", field: "actor1" }

        expect(last_response.status).to eq(200)
        expect(last_response.body.strip).to be_empty
      end
    end
  end
end
