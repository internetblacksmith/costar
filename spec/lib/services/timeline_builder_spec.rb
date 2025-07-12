# frozen_string_literal: true

require "spec_helper"

RSpec.describe TimelineBuilder do
  let(:actor1_movies) do
    [
      { title: "Inception", release_date: "2010-07-16", id: 27_205, year: 2010 },
      { title: "The Departed", release_date: "2006-10-06", id: 1422, year: 2006 },
      { title: "Titanic", release_date: "1997-12-19", id: 597, year: 1997 }
    ]
  end

  let(:actor2_movies) do
    [
      { title: "Forrest Gump", release_date: "1994-07-06", id: 13, year: 1994 },
      { title: "Cast Away", release_date: "2000-12-22", id: 8358, year: 2000 },
      { title: "Catch Me If You Can", release_date: "2002-12-25", id: 640, year: 2002 }
    ]
  end

  let(:builder) { TimelineBuilder.new(actor1_movies, actor2_movies, "Leonardo DiCaprio", "Tom Hanks") }

  describe "#build" do
    it "builds a chronological timeline" do
      result = builder.build

      expect(result).to have_key(:years)
      expect(result).to have_key(:shared_movies)
      expect(result).to have_key(:processed_movies)

      years = result[:years]
      expect(years).to include(1994, 1997, 2000, 2002, 2006, 2010)
      expect(years).to eq(years.sort.reverse) # Should be reverse chronological
    end

    it "correctly identifies shared movies" do
      # Add a shared movie to both actors
      shared_movie = { title: "Shared Film", release_date: "2005-01-01", id: 999, year: 2005 }
      actor1_with_shared = actor1_movies + [shared_movie]
      actor2_with_shared = actor2_movies + [shared_movie]

      builder_with_shared = TimelineBuilder.new(actor1_with_shared, actor2_with_shared, "Leonardo DiCaprio",
                                                "Tom Hanks")
      result = builder_with_shared.build

      shared_movie_ids = result[:shared_movies].map { |m| m[:id] }
      expect(shared_movie_ids).to include(999)
    end

    it "handles empty movie lists" do
      empty_builder = TimelineBuilder.new([], [], "Actor One", "Actor Two")
      result = empty_builder.build

      expect(result[:years]).to be_empty
      expect(result[:shared_movies]).to be_empty
      expect(result[:processed_movies]).to be_empty
    end

    it "handles movies without release dates" do
      movies_no_dates = [
        { title: "Unknown Date Movie", release_date: nil, id: 1, year: nil }
      ]

      builder_no_dates = TimelineBuilder.new(movies_no_dates, [], "Actor One", "Actor Two")
      result = builder_no_dates.build

      expect(result[:years]).not_to include(nil)
    end
  end

  describe "performance with large datasets" do
    it "handles large movie lists efficiently" do
      large_movies1 = Array.new(1000) do |i|
        { title: "Movie #{i}", release_date: "#{2000 + (i % 20)}-01-01", id: i, year: 2000 + (i % 20) }
      end

      large_movies2 = Array.new(1000) do |i|
        { title: "Film #{i}", release_date: "#{1990 + (i % 30)}-01-01", id: i + 1000, year: 1990 + (i % 30) }
      end

      start_time = Time.now
      large_builder = TimelineBuilder.new(large_movies1, large_movies2, "Actor One", "Actor Two")
      result = large_builder.build
      execution_time = Time.now - start_time

      expect(result[:years]).not_to be_empty
      expect(execution_time).to be < 1.0 # Should complete in under 1 second
    end
  end
end
