# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/services/tmdb_fallback_provider"

RSpec.describe TMDBFallbackProvider do
  describe ".for_endpoint" do
    it "returns search fallback for search/person endpoint" do
      result = described_class.for_endpoint("search/person")
      expect(result).to eq(
        "results" => [],
        "total_results" => 0,
        "total_pages" => 0,
        "page" => 1
      )
    end

    it "returns movie credits fallback for person movie_credits endpoint" do
      result = described_class.for_endpoint("person/123/movie_credits")
      expect(result).to eq(
        "cast" => [],
        "crew" => [],
        "id" => 0
      )
    end

    it "returns person details fallback for person endpoint" do
      result = described_class.for_endpoint("person/123")
      expect(result).to eq(
        "id" => 0,
        "name" => "Unknown Actor",
        "biography" => "",
        "profile_path" => nil,
        "known_for_department" => "Acting"
      )
    end

    it "returns default fallback for unknown endpoints" do
      result = described_class.for_endpoint("unknown/endpoint")
      expect(result).to eq(
        "error" => "Service temporarily unavailable",
        "fallback" => true
      )
    end

    it "returns a copy of the fallback data" do
      result1 = described_class.for_endpoint("search/person")
      result2 = described_class.for_endpoint("search/person")
      
      expect(result1).to eq(result2)
      expect(result1.object_id).not_to eq(result2.object_id)
    end
  end

  describe ".determine_response_type" do
    it "identifies search/person endpoints" do
      expect(described_class.determine_response_type("search/person")).to eq(:search_person)
      expect(described_class.determine_response_type("search/person?query=test")).to eq(:search_person)
    end

    it "identifies person movie_credits endpoints" do
      expect(described_class.determine_response_type("person/123/movie_credits")).to eq(:movie_credits)
      expect(described_class.determine_response_type("person/456/movie_credits?lang=en")).to eq(:movie_credits)
    end

    it "identifies person details endpoints" do
      expect(described_class.determine_response_type("person/123")).to eq(:person_details)
      expect(described_class.determine_response_type("person/456")).to eq(:person_details)
    end

    it "returns default for unknown endpoints" do
      expect(described_class.determine_response_type("movie/123")).to eq(:default)
      expect(described_class.determine_response_type("tv/456")).to eq(:default)
    end
  end

  describe ".fallback?" do
    it "returns true for fallback responses" do
      response = { "error" => "Service temporarily unavailable", "fallback" => true }
      expect(described_class.fallback?(response)).to be true
    end

    it "returns false for regular responses" do
      response = { "results" => [], "total_results" => 0 }
      expect(described_class.fallback?(response)).to be false
    end

    it "returns false for non-hash responses" do
      expect(described_class.fallback?("string")).to be false
      expect(described_class.fallback?(nil)).to be false
      expect(described_class.fallback?([])).to be false
    end
  end
end