# frozen_string_literal: true

require "spec_helper"

RSpec.describe CacheKeyBuilder do
  subject(:builder) { described_class.new }

  describe "#actor_profile" do
    it "generates consistent key for actor profile" do
      expect(builder.actor_profile(12_345)).to eq("v1:actor:profile:12345")
    end

    it "handles string actor IDs" do
      expect(builder.actor_profile("12345")).to eq("v1:actor:profile:12345")
    end
  end

  describe "#actor_movies" do
    it "generates consistent key for actor movies" do
      expect(builder.actor_movies(12_345)).to eq("v1:actor:movies:12345")
    end
  end

  describe "#search_results" do
    it "generates hashed key for search query" do
      query = "Leonardo DiCaprio"
      result = builder.search_results(query)

      expect(result).to start_with("v1:search:")
      expect(result).to include(Digest::MD5.hexdigest(query.downcase.strip))
    end

    it "generates same key for equivalent queries" do
      query1 = "Leonardo DiCaprio"
      query2 = "  LEONARDO DICAPRIO  "

      key1 = builder.search_results(query1)
      key2 = builder.search_results(query2)

      expect(key1).to eq(key2)
    end

    it "handles nil query" do
      expect { builder.search_results(nil) }.not_to raise_error
    end
  end

  describe "#actor_comparison" do
    it "generates consistent key for actor comparison" do
      result = builder.actor_comparison(123, 456)
      expect(result).to eq("v1:comparison:123:456")
    end

    it "normalizes actor order for consistent caching" do
      key1 = builder.actor_comparison(456, 123)
      key2 = builder.actor_comparison(123, 456)

      expect(key1).to eq(key2)
      expect(key1).to eq("v1:comparison:123:456")
    end

    it "handles string actor IDs" do
      result = builder.actor_comparison("123", "456")
      expect(result).to eq("v1:comparison:123:456")
    end
  end

  describe "#actor_name" do
    it "generates consistent key for actor name" do
      expect(builder.actor_name(12_345)).to eq("v1:actor:name:12345")
    end
  end

  describe "#health_check" do
    it "generates consistent key for health check" do
      expect(builder.health_check).to eq("v1:health:tmdb_api")
    end
  end

  describe "#movie_details" do
    it "generates consistent key for movie details" do
      expect(builder.movie_details(12_345)).to eq("v1:movie:details:12345")
    end
  end

  describe "#invalidation_pattern" do
    it "generates pattern for specific actor invalidation" do
      pattern = builder.invalidation_pattern("actor", 123)
      expect(pattern).to eq("v1:actor:123*")
    end

    it "generates pattern for all actors" do
      pattern = builder.invalidation_pattern("actor")
      expect(pattern).to eq("v1:actor*")
    end

    it "generates pattern for search invalidation" do
      pattern = builder.invalidation_pattern("search")
      expect(pattern).to eq("v1:search*")
    end
  end

  describe "versioning" do
    it "includes version in all keys" do
      keys = [
        builder.actor_profile(123),
        builder.actor_movies(123),
        builder.search_results("test"),
        builder.actor_comparison(123, 456),
        builder.actor_name(123),
        builder.health_check,
        builder.movie_details(123)
      ]

      keys.each do |key|
        expect(key).to start_with("v1:")
      end
    end
  end
end
