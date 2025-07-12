# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TimelineBuilder do
  let(:builder) { TimelineBuilder.new }

  describe '#build_timeline' do
    let(:actor1_movies) do
      [
        { 'title' => 'Inception', 'release_date' => '2010-07-16', 'id' => 27205 },
        { 'title' => 'The Departed', 'release_date' => '2006-10-06', 'id' => 1422 },
        { 'title' => 'Titanic', 'release_date' => '1997-12-19', 'id' => 597 }
      ]
    end

    let(:actor2_movies) do
      [
        { 'title' => 'Forrest Gump', 'release_date' => '1994-07-06', 'id' => 13 },
        { 'title' => 'Cast Away', 'release_date' => '2000-12-22', 'id' => 8408 },
        { 'title' => 'Catch Me If You Can', 'release_date' => '2002-12-25', 'id' => 640 }
      ]
    end

    let(:shared_movies) do
      [
        { 'title' => 'Catch Me If You Can', 'release_date' => '2002-12-25', 'id' => 640 }
      ]
    end

    it 'builds a chronological timeline' do
      result = builder.build_timeline(actor1_movies, actor2_movies, shared_movies)

      expect(result).to have_key(:years)
      expect(result).to have_key(:processed_movies)
      
      years = result[:years]
      expect(years).to include(1994, 1997, 2000, 2002, 2006, 2010)
      expect(years).to eq(years.sort) # Should be chronologically ordered
    end

    it 'correctly identifies shared movies' do
      result = builder.build_timeline(actor1_movies, actor2_movies, shared_movies)
      processed_movies = result[:processed_movies]

      shared_movie = processed_movies.find { |m| m[:id] == 640 }
      expect(shared_movie).not_to be_nil
      expect(shared_movie[:shared]).to be true
      expect(shared_movie[:title]).to eq('Catch Me If You Can')
    end

    it 'marks non-shared movies correctly' do
      result = builder.build_timeline(actor1_movies, actor2_movies, shared_movies)
      processed_movies = result[:processed_movies]

      inception = processed_movies.find { |m| m[:id] == 27205 }
      expect(inception[:shared]).to be false
      expect(inception[:actor]).to eq(1)

      forrest_gump = processed_movies.find { |m| m[:id] == 13 }
      expect(forrest_gump[:shared]).to be false
      expect(forrest_gump[:actor]).to eq(2)
    end

    it 'groups movies by year' do
      result = builder.build_timeline(actor1_movies, actor2_movies, shared_movies)
      processed_movies = result[:processed_movies]

      movies_2002 = processed_movies.select { |m| m[:year] == 2002 }
      expect(movies_2002.length).to eq(1)
      expect(movies_2002.first[:title]).to eq('Catch Me If You Can')
    end

    it 'handles movies without release dates' do
      movies_without_dates = [
        { 'title' => 'Unknown Movie', 'release_date' => nil, 'id' => 999 }
      ]

      result = builder.build_timeline(movies_without_dates, [], [])
      processed_movies = result[:processed_movies]

      unknown_movie = processed_movies.find { |m| m[:id] == 999 }
      expect(unknown_movie[:year]).to eq('Unknown')
    end

    it 'handles empty movie lists' do
      result = builder.build_timeline([], [], [])

      expect(result[:years]).to eq([])
      expect(result[:processed_movies]).to eq([])
    end

    context 'with invalid release dates' do
      let(:invalid_movies) do
        [
          { 'title' => 'Invalid Date Movie', 'release_date' => 'invalid-date', 'id' => 888 }
        ]
      end

      it 'handles invalid date formats gracefully' do
        result = builder.build_timeline(invalid_movies, [], [])
        processed_movies = result[:processed_movies]

        invalid_movie = processed_movies.find { |m| m[:id] == 888 }
        expect(invalid_movie[:year]).to eq('Unknown')
      end
    end
  end

  describe '#sort_movies_chronologically' do
    let(:unsorted_movies) do
      [
        { year: 2010, title: 'Inception' },
        { year: 1997, title: 'Titanic' },
        { year: 2006, title: 'The Departed' },
        { year: 1997, title: 'Another 1997 Movie' }
      ]
    end

    it 'sorts movies by year and then by title' do
      sorted = builder.send(:sort_movies_chronologically, unsorted_movies)

      expect(sorted[0][:title]).to eq('Another 1997 Movie')
      expect(sorted[1][:title]).to eq('Titanic')
      expect(sorted[2][:title]).to eq('The Departed')
      expect(sorted[3][:title]).to eq('Inception')
    end
  end

  describe '#extract_year' do
    it 'extracts year from valid date' do
      year = builder.send(:extract_year, '2010-07-16')
      expect(year).to eq(2010)
    end

    it 'returns "Unknown" for nil date' do
      year = builder.send(:extract_year, nil)
      expect(year).to eq('Unknown')
    end

    it 'returns "Unknown" for empty date' do
      year = builder.send(:extract_year, '')
      expect(year).to eq('Unknown')
    end

    it 'returns "Unknown" for invalid date format' do
      year = builder.send(:extract_year, 'invalid-date')
      expect(year).to eq('Unknown')
    end

    it 'handles partial dates' do
      year = builder.send(:extract_year, '2010')
      expect(year).to eq(2010)
    end
  end

  describe 'performance with large datasets' do
    let(:large_dataset) do
      (1990..2023).map do |year|
        {
          'title' => "Movie #{year}",
          'release_date' => "#{year}-01-01",
          'id' => year
        }
      end
    end

    it 'handles large movie lists efficiently' do
      start_time = Time.now
      
      result = builder.build_timeline(large_dataset, large_dataset, [])
      
      execution_time = Time.now - start_time
      expect(execution_time).to be < 1.0 # Should complete in under 1 second
      
      expect(result[:years].length).to eq(34) # 1990-2023
      expect(result[:processed_movies].length).to eq(68) # 34 * 2 actors
    end
  end
end