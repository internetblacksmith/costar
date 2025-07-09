# frozen_string_literal: true

require "base64"

# Service for handling TMDB actor profile images
class ActorProfileService
  BASE_URL = "https://image.tmdb.org/t/p"
  
  PROFILE_SIZES = {
    small: "w92",
    medium: "w185",
    large: "w500",
    original: "original"
  }.freeze

  def self.profile_url(profile_path, size = :medium)
    return placeholder_url if profile_path.nil? || profile_path.empty?
    
    size_param = PROFILE_SIZES[size] || PROFILE_SIZES[:medium]
    "#{BASE_URL}/#{size_param}#{profile_path}"
  end

  def self.placeholder_url
    "data:image/svg+xml;base64,#{Base64.encode64(placeholder_svg).strip}"
  end

  private

  def self.placeholder_svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="185" height="278" viewBox="0 0 185 278">
        <rect width="185" height="278" fill="#f0f0f0"/>
        <g fill="#888" text-anchor="middle" font-family="Arial, sans-serif" font-size="14">
          <circle cx="92.5" cy="100" r="40" fill="none" stroke="#888" stroke-width="2"/>
          <path d="M92.5 140 L92.5 150 M92.5 150 L82.5 160 M92.5 150 L102.5 160 M60 200 C60 180 75 160 92.5 160 C110 160 125 180 125 200"/>
          <text x="92.5" y="230" font-size="12">No Profile</text>
        </g>
      </svg>
    SVG
  end
end