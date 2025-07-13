# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/dto/dto_factory"

RSpec.describe DTOFactory do
  describe ".actor_from_api" do
    let(:api_data) do
      {
        "id" => 123,
        "name" => "Tom Hanks",
        "profile_path" => "/profile.jpg",
        "popularity" => 45.5,
        "known_for_department" => "Acting",
        "known_for" => [
          { "title" => "Forrest Gump" },
          { "name" => "Cast Away" }
        ],
        "biography" => "American actor",
        "birthday" => "1956-07-09",
        "place_of_birth" => "Concord, California, USA"
      }
    end

    it "creates ActorDTO from API response" do
      actor = described_class.actor_from_api(api_data)

      expect(actor).to be_a(ActorDTO)
      expect(actor.id).to eq(123)
      expect(actor.name).to eq("Tom Hanks")
      expect(actor.profile_path).to eq("/profile.jpg")
      expect(actor.popularity).to eq(45.5)
      expect(actor.known_for).to eq([
                                      { title: "Forrest Gump" },
                                      { title: "Cast Away" }
                                    ])
    end

    it "handles symbol keys" do
      symbol_data = api_data.transform_keys(&:to_sym)
      actor = described_class.actor_from_api(symbol_data)

      expect(actor.id).to eq(123)
      expect(actor.name).to eq("Tom Hanks")
    end

    it "returns nil for nil input" do
      expect(described_class.actor_from_api(nil)).to be_nil
    end

    it "handles missing optional fields" do
      minimal_data = { "id" => 123, "name" => "Tom Hanks" }
      actor = described_class.actor_from_api(minimal_data)

      expect(actor.id).to eq(123)
      expect(actor.name).to eq("Tom Hanks")
      expect(actor.popularity).to eq(0.0)
      expect(actor.known_for).to eq([])
    end
  end

  describe ".movie_from_api" do
    let(:api_data) do
      {
        "id" => 456,
        "title" => "Forrest Gump",
        "character" => "Forrest Gump",
        "release_date" => "1994-07-06",
        "poster_path" => "/poster.jpg",
        "overview" => "A movie about...",
        "vote_average" => 8.5,
        "popularity" => 100.5
      }
    end

    it "creates MovieDTO from API response" do
      movie = described_class.movie_from_api(api_data)

      expect(movie).to be_a(MovieDTO)
      expect(movie.id).to eq(456)
      expect(movie.title).to eq("Forrest Gump")
      expect(movie.character).to eq("Forrest Gump")
      expect(movie.release_date).to eq("1994-07-06")
      expect(movie.year).to eq(1994)
      expect(movie.vote_average).to eq(8.5)
    end

    it "extracts year from release_date" do
      movie = described_class.movie_from_api(api_data)
      expect(movie.year).to eq(1994)
    end

    it "uses provided year over extracted" do
      data_with_year = api_data.merge("year" => 1995)
      movie = described_class.movie_from_api(data_with_year)
      expect(movie.year).to eq(1995)
    end

    it "handles invalid release date" do
      data = api_data.merge("release_date" => "invalid")
      movie = described_class.movie_from_api(data)
      expect(movie.year).to be_nil
    end
  end

  describe ".search_results_from_api" do
    let(:api_response) do
      {
        "results" => [
          { "id" => 1, "name" => "Actor 1" },
          { "id" => 2, "name" => "Actor 2" }
        ],
        "total_results" => 2,
        "total_pages" => 1,
        "page" => 1
      }
    end

    it "creates SearchResultsDTO from API response" do
      results = described_class.search_results_from_api(api_response)

      expect(results).to be_a(SearchResultsDTO)
      expect(results.actors.size).to eq(2)
      expect(results.actors.first).to be_a(ActorDTO)
      expect(results.actors.first.name).to eq("Actor 1")
      expect(results.total_results).to eq(2)
      expect(results.total_pages).to eq(1)
      expect(results.page).to eq(1)
    end

    it "handles empty results" do
      empty_response = { "results" => [], "total_results" => 0 }
      results = described_class.search_results_from_api(empty_response)

      expect(results.actors).to eq([])
      expect(results.total_results).to eq(0)
    end

    it "handles nil response" do
      results = described_class.search_results_from_api(nil)
      expect(results.actors).to eq([])
    end

    it "uses query params for page if not in response" do
      response_without_page = api_response.except("page")
      results = described_class.search_results_from_api(response_without_page, page: 3)
      expect(results.page).to eq(3)
    end
  end

  describe ".comparison_result_from_service" do
    let(:service_data) do
      {
        actor1_id: 1,
        actor1_name: "Actor 1",
        actor1_profile_path: "/actor1.jpg",
        actor2_id: 2,
        actor2_name: "Actor 2",
        actor2_profile_path: "/actor2.jpg",
        actor1_movies: [
          { id: 101, title: "Movie 1" },
          { id: 102, title: "Movie 2" }
        ],
        actor2_movies: [
          { id: 102, title: "Movie 2" },
          { id: 103, title: "Movie 3" }
        ],
        shared_movies: [
          { id: 102, title: "Movie 2" }
        ],
        timeline_data: {
          years: [2023, 2022],
          shared_movies: [102],
          processed_movies: { 2023 => [], 2022 => [] },
          shared_movies_by_year: { 2023 => [] }
        }
      }
    end

    it "creates ComparisonResultDTO from service response" do
      result = described_class.comparison_result_from_service(service_data)

      expect(result).to be_a(ComparisonResultDTO)
      expect(result.actor1).to be_a(ActorDTO)
      expect(result.actor1.name).to eq("Actor 1")
      expect(result.actor2.name).to eq("Actor 2")
      expect(result.actor1_movies.size).to eq(2)
      expect(result.actor2_movies.size).to eq(2)
      expect(result.shared_movies.size).to eq(1)
      expect(result.timeline_data[:years]).to eq([2023, 2022])
    end

    it "adds metadata" do
      result = described_class.comparison_result_from_service(service_data)

      expect(result.metadata[:total_movies]).to eq({
                                                     actor1: 2,
                                                     actor2: 2,
                                                     shared: 1
                                                   })
      expect(result.metadata[:comparison_date]).to match(/^\d{4}-\d{2}-\d{2}T/)
    end

    it "handles missing timeline data" do
      data_without_timeline = service_data.except(:timeline_data)
      result = described_class.comparison_result_from_service(data_without_timeline)

      expect(result.timeline_data).to eq({
                                           years: [],
                                           shared_movies: [],
                                           processed_movies: {},
                                           shared_movies_by_year: {}
                                         })
    end

    it "returns nil for nil input" do
      expect(described_class.comparison_result_from_service(nil)).to be_nil
    end
  end
end
