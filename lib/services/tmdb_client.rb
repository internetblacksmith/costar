# frozen_string_literal: true

require "net/http"
require "json"

# Low-level TMDB API client for making HTTP requests
class TMDBClient
  BASE_URL = "https://api.themoviedb.org/3"

  def initialize(api_key = nil)
    @api_key = api_key || Configuration.instance.tmdb_api_key
  end

  def request(endpoint, params = {})
    raise TMDBError.new("TMDB API key not configured", 500) unless @api_key

    url = build_url(endpoint, params)
    response = make_http_request(url)

    handle_response(response)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TMDBError.new("TMDB API request timed out", 503)
  rescue SocketError, Net::HTTPError => e
    raise TMDBError.new("Network error: #{e.message}", 503)
  rescue JSON::ParserError
    raise TMDBError.new("Invalid JSON response from TMDB", 502)
  end

  private

  def build_url(endpoint, params)
    query_params = params.merge(api_key: @api_key)
    query_string = URI.encode_www_form(query_params)
    "#{BASE_URL}/#{endpoint}?#{query_string}"
  end

  def make_http_request(url)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
      http.get(uri)
    end
  end

  def handle_response(response)
    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 401
      raise TMDBError.new("Invalid TMDB API key", 401)
    when 404
      raise TMDBError.new("Resource not found", 404)
    when 429
      raise TMDBError.new("Rate limit exceeded", 429)
    else
      raise TMDBError.new("TMDB API error: #{response.code}", response.code.to_i)
    end
  end
end
