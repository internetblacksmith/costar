# frozen_string_literal: true

require_relative "optimized_image_service"

# Enhanced service for handling movie poster URLs with performance optimization
class PosterService
  BASE_URL = "https://image.tmdb.org/t/p"

  # Legacy size mappings for backward compatibility
  POSTER_SIZES = {
    thumbnail: "w154",
    medium: "w342",
    large: "w500",
    original: "original"
  }.freeze

  class << self
    def poster_url(poster_path, size = :medium)
      # Use optimized image service for better performance
      OptimizedImageService.poster_url(poster_path, size: size)
    end

    def poster_urls(poster_path)
      # Use optimized responsive URLs
      OptimizedImageService.responsive_poster_urls(poster_path, sizes: %i[thumbnail medium large original])
    end

    def placeholder_url
      OptimizedImageService.default_poster_url
    end

    # New performance-optimized methods
    def srcset_string(poster_path, sizes: %i[thumbnail medium large])
      OptimizedImageService.srcset_string(poster_path, sizes: sizes)
    end

    def preload_urls(movie_list, size: :medium)
      OptimizedImageService.preload_image_urls(movie_list, size: size)
    end

    def responsive_image_attrs(poster_path, alt_text: "Movie poster", css_class: "poster-image")
      return fallback_image_attrs(alt_text, css_class) if poster_path.nil? || poster_path.empty?

      {
        src: poster_url(poster_path, :medium),
        srcset: srcset_string(poster_path),
        sizes: "(max-width: 768px) 154px, (max-width: 1024px) 185px, 342px",
        alt: alt_text,
        class: css_class,
        loading: "lazy",
        decoding: "async"
      }
    end

    private

    def all_placeholder_urls
      POSTER_SIZES.keys.to_h { |size| [size, placeholder_url] }
    end

    def fallback_image_attrs(alt_text, css_class)
      {
        src: placeholder_url,
        alt: alt_text,
        class: css_class,
        loading: "lazy"
      }
    end
  end
end
