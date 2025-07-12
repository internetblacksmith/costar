# frozen_string_literal: true

# Service for handling movie poster URLs and optimization
class PosterService
  BASE_URL = "https://image.tmdb.org/t/p"

  # Available sizes: w92, w154, w185, w342, w500, w780, original
  POSTER_SIZES = {
    thumbnail: "w154",    # For mobile/small screens
    medium: "w342",       # For desktop cards
    large: "w500",        # For detailed views
    original: "original"  # Full resolution
  }.freeze

  class << self
    def poster_url(poster_path, size = :medium)
      return placeholder_url if poster_path.nil? || poster_path.empty?

      size_param = POSTER_SIZES[size] || POSTER_SIZES[:medium]
      "#{BASE_URL}/#{size_param}#{poster_path}"
    end

    def poster_urls(poster_path)
      return all_placeholder_urls if poster_path.nil? || poster_path.empty?

      POSTER_SIZES.transform_values do |size_param|
        "#{BASE_URL}/#{size_param}#{poster_path}"
      end
    end

    def placeholder_url
      "data:image/svg+xml;base64,#{placeholder_svg_base64}"
    end

    private

    def all_placeholder_urls
      POSTER_SIZES.keys.to_h { |size| [size, placeholder_url] }
    end

    def placeholder_svg_base64
      # Simple SVG placeholder for missing posters
      svg = <<~SVG
        <svg width="342" height="513" xmlns="http://www.w3.org/2000/svg">
          <rect width="100%" height="100%" fill="#e0e0e0"/>
          <g fill="#9e9e9e" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">
            <text x="50%" y="45%">No Poster</text>
            <text x="50%" y="55%">Available</text>
          </g>
        </svg>
      SVG

      require "base64"
      Base64.strict_encode64(svg)
    end
  end
end
