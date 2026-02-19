#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches real TMDB image URLs for prototype templates and replaces all
# placehold.co placeholders with real images.
#
# Usage: doppler run --project movie_together --config dev -- ruby scripts/fetch_prototype_images.rb

require "net/http"
require "json"
require "uri"

TMDB_API_KEY = ENV.fetch("TMDB_API_KEY") {
  abort "TMDB_API_KEY not set. Run with: doppler run --project movie_together --config dev -- ruby #{$PROGRAM_NAME}"
}
TMDB_BASE = "https://api.themoviedb.org/3"
IMG_BASE = "https://image.tmdb.org/t/p"

def tmdb_get(path, params = {})
  params[:api_key] = TMDB_API_KEY
  uri = URI("#{TMDB_BASE}#{path}")
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

def search_person(name)
  data = tmdb_get("/search/person", query: name)
  data["results"]&.first
end

def search_movie(title)
  data = tmdb_get("/search/movie", query: title)
  data["results"]&.first
end

def img_url(path, size = "w500")
  return nil unless path
  "#{IMG_BASE}/#{size}#{path}"
end

# All people and movies used in the prototypes
PEOPLE = ["Robert De Niro", "Joe Pesci", "Frank Vincent"]
MOVIES = ["Goodfellas", "Casino", "Raging Bull", "The Irishman"]

# Map text= parameter values to the entity they represent.
# Covers all variations found across the 5 templates.
TEXT_TO_PERSON = {
  "De+Niro"  => "Robert De Niro",
  "DeNiro"   => "Robert De Niro",
  "De Niro"  => "Robert De Niro",
  "Niro"     => "Robert De Niro",
  "RD"       => "Robert De Niro",
  "Pesci"    => "Joe Pesci",
  "JP"       => "Joe Pesci",
  "Vincent"  => "Frank Vincent",
  "FV"       => "Frank Vincent",
}

TEXT_TO_MOVIE = {
  "Goodfellas"    => "Goodfellas",
  "Casino"        => "Casino",
  "Raging+Bull"   => "Raging Bull",
  "Raging Bull"   => "Raging Bull",
  "The+Irishman"  => "The Irishman",
  "The Irishman"  => "The Irishman",
}

puts "=" * 60
puts "TMDB Image URLs for Prototypes"
puts "=" * 60

# Fetch all people
puts "\n## ACTORS\n"
person_paths = {}
PEOPLE.each do |name|
  person = search_person(name)
  if person && person["profile_path"]
    person_paths[name] = person["profile_path"]
    puts "  #{name}: #{img_url(person['profile_path'])}"
  else
    puts "  #{name}: NOT FOUND"
  end
end

# Fetch all movies
puts "\n## MOVIES\n"
movie_paths = {}
MOVIES.each do |title|
  movie = search_movie(title)
  if movie && movie["poster_path"]
    movie_paths[title] = movie["poster_path"]
    puts "  #{title}: #{img_url(movie['poster_path'])}"
  else
    puts "  #{title}: NOT FOUND"
  end
end

# Process each prototype file
puts "\n" + "=" * 60
puts "REPLACING PLACEHOLDERS"
puts "=" * 60

proto_dir = File.join(__dir__, "..", "public", "prototypes")
Dir.glob(File.join(proto_dir, "*.html")).sort.each do |file|
  content = File.read(file)
  count = 0

  # Match any placehold.co URL with a text= parameter
  content.gsub!(%r{https://placehold\.co/(\d+)x(\d+)/[0-9a-fA-F]+/[0-9a-fA-F]+\?text=([^"'\s&]+)}) do |match|
    width = ::Regexp.last_match(1).to_i
    height = ::Regexp.last_match(2).to_i
    text = ::Regexp.last_match(3)

    # Determine if this is a person or movie
    person_name = TEXT_TO_PERSON[text]
    movie_title = TEXT_TO_MOVIE[text]

    if person_name && person_paths[person_name]
      # Pick size based on placeholder dimensions
      size = width <= 100 ? "w185" : "w500"
      count += 1
      img_url(person_paths[person_name], size)
    elsif movie_title && movie_paths[movie_title]
      size = width <= 200 ? "w185" : "w500"
      count += 1
      img_url(movie_paths[movie_title], size)
    else
      puts "  WARNING: No match for text=#{text} in #{File.basename(file)}"
      match # leave unchanged
    end
  end

  File.write(file, content)
  puts "  #{File.basename(file)}: #{count} replacements"
end

puts "\nDone!"
