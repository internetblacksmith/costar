# frozen_string_literal: true

# Service for building timeline data from actor movies
class TimelineBuilder
  def initialize(actor1_movies, actor2_movies, actor1_name, actor2_name)
    @actor1_movies = actor1_movies
    @actor2_movies = actor2_movies
    @actor1_name = actor1_name
    @actor2_name = actor2_name
  end

  def build
    {
      years: sorted_years,
      shared_movies: shared_movies,
      processed_movies: processed_movies_by_year
    }
  end

  private

  def sorted_years
    all_years.uniq.compact.sort.reverse
  end

  def all_years
    (@actor1_movies + @actor2_movies).map { |m| m[:year] }
  end

  def shared_movies
    @shared_movies ||= find_shared_movies
  end

  def find_shared_movies
    actor1_movie_ids = @actor1_movies.map { |m| m[:id] }
    @actor2_movies.select { |movie| actor1_movie_ids.include?(movie[:id]) }
  end

  def processed_movies_by_year
    result = {}

    sorted_years.each do |year|
      result[year] = process_movies_for_year(year)
    end

    result
  end

  def process_movies_for_year(year)
    actor1_movies = @actor1_movies.select { |m| m[:year] == year }
    actor2_movies = @actor2_movies.select { |m| m[:year] == year }

    return [] if actor1_movies.empty? && actor2_movies.empty?

    all_movies_this_year = build_movie_list_for_year(actor1_movies, actor2_movies)
    all_movies_this_year.sort_by! { |item| item[:movie][:release_date] || "0000-00-00" }

    group_shared_movies(all_movies_this_year)
  end

  def build_movie_list_for_year(actor1_movies, actor2_movies)
    all_movies = []

    # Add actor1 movies
    all_movies.concat(actor1_movies.map do |movie|
      create_movie_entry(movie, @actor1_name, :left)
    end)

    # Add actor2 movies
    all_movies.concat(actor2_movies.map do |movie|
      create_movie_entry(movie, @actor2_name, :right)
    end)

    all_movies
  end

  def create_movie_entry(movie, actor_name, side)
    {
      movie: movie,
      actor: actor_name,
      side: side,
      is_shared: shared_movies.any? { |shared| shared[:id] == movie[:id] }
    }
  end

  def group_shared_movies(movies)
    processed_movies = []
    shared_movie_ids = []

    movies.each do |item|
      if item[:is_shared] && !shared_movie_ids.include?(item[:movie][:id])
        # Find both versions of this shared movie
        shared_versions = movies.select { |m| m[:movie][:id] == item[:movie][:id] }
        processed_movies << { type: :shared, movies: shared_versions }
        shared_movie_ids << item[:movie][:id]
      elsif !item[:is_shared]
        processed_movies << { type: :single, movie: item }
      end
    end

    processed_movies
  end
end
