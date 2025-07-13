# frozen_string_literal: true

require_relative "../config/logger"

# Optimized image service for TMDB poster URLs with performance optimization
class OptimizedImageService
  # TMDB image configuration
  TMDB_IMAGE_BASE_URL = "https://image.tmdb.org/t/p/"

  # Available poster sizes (from smallest to largest)
  POSTER_SIZES = %w[w92 w154 w185 w342 w500 w780 original].freeze

  # Optimized sizes for different use cases
  SIZE_MAPPINGS = {
    thumbnail: "w92",     # For small thumbnails
    small: "w154",        # For actor portraits
    medium: "w185",       # Default size
    large: "w342",        # For detailed views
    xlarge: "w500",       # For hero images
    original: "original"  # Full resolution
  }.freeze

  # Default fallback image (SVG data URL)
  DEFAULT_POSTER_SVG = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxODUiIGhlaWdodD0iMjc4IiB2aWV3Qm94PSIwIDAgMTg1IDI3OCI+CiAgPHJlY3Qgd2lkdGg9IjE4NSIgaGVpZ2h0PSIyNzgiIGZpbGw9IiNmMGYwZjAiLz4KICA8ZyBmaWxsPSIjODg4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LWZhbWlseT0iQXJpYWwsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTQiPgogICAgPGNpcmNsZSBjeD0iOTIuNSIgY3k9IjEwMCIgcj0iNDAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzg4OCIgc3Ryb2tlLXdpZHRoPSIyIi8+CiAgICA8cGF0aCBkPSJNOTIuNSAxNDAgTDkyLjUgMTUwIE05Mi41IDE1MCBMODIuNSAxNjAgTTkyLjUgMTUwIEwxMDIuNSAxNjAgTTYwIDIwMCBDNjAgMTgwIDc1IDE2MCA5Mi41IDE2MCBDMTEwIDE2MCAxMjUgMTgwIDEyNSAyMDAiLz4KICAgIDx0ZXh0IHg9IjkyLjUiIHk9IjIzMCIgZm9udC1zaXplPSIxMiI+Tm8gUG9zdGVyPC90ZXh0PgogIDwvZz4KICA8L3N2Zz4K"

  def self.poster_url(poster_path, size: :medium, fallback: true)
    return default_poster_url if poster_path.nil? || poster_path.empty?

    # Get the appropriate size
    tmdb_size = SIZE_MAPPINGS[size] || SIZE_MAPPINGS[:medium]

    # Build the full URL
    url = "#{TMDB_IMAGE_BASE_URL}#{tmdb_size}#{poster_path}"

    # Add optimization parameters for supported CDNs
    optimized_url = add_optimization_params(url, size)

    # Cache the URL for performance
    cache_image_url(poster_path, size, optimized_url)

    optimized_url
  rescue StandardError => e
    StructuredLogger.error("Image URL Generation Error",
                           type: "image_error",
                           poster_path: poster_path,
                           size: size,
                           error: e.message)

    fallback ? default_poster_url : nil
  end

  def self.responsive_poster_urls(poster_path, sizes: %i[small medium large])
    return {} if poster_path.nil? || poster_path.empty?

    urls = {}
    sizes.each do |size|
      urls[size] = poster_url(poster_path, size: size, fallback: false)
    end

    # Remove any nil values
    urls.compact
  end

  def self.srcset_string(poster_path, sizes: %i[small medium large])
    urls = responsive_poster_urls(poster_path, sizes: sizes)
    return "" if urls.empty?

    srcset_parts = []
    urls.each do |size, url|
      width = size_to_width(size)
      srcset_parts << "#{url} #{width}w" if width
    end

    srcset_parts.join(", ")
  end

  def self.default_poster_url
    DEFAULT_POSTER_SVG
  end

  def self.preload_image_urls(movie_list, size: :medium)
    return [] if movie_list.nil? || movie_list.empty?

    urls = movie_list.filter_map do |movie|
      poster_path = movie["poster_path"] || movie[:poster_path]
      next unless poster_path

      poster_url(poster_path, size: size, fallback: false)
    end

    # Remove duplicates and limit to reasonable number
    urls.uniq.first(20)
  end

  def self.add_optimization_params(url, size)
    # Add query parameters for optimization if using a CDN
    # These would be configured based on your CDN provider

    case ENV.fetch("CDN_PROVIDER", "none").downcase
    when "cloudflare"
      add_cloudflare_optimization(url, size)
    when "cloudfront"
      add_cloudfront_optimization(url, size)
    when "fastly"
      add_fastly_optimization(url, size)
    else
      url
    end
  end

  def self.add_cloudflare_optimization(url, size)
    # Cloudflare Image Resizing parameters
    params = []

    case size
    when :thumbnail, :small
      params << "quality=85"
      params << "format=auto"
    when :medium, :large
      params << "quality=90"
      params << "format=auto"
    when :xlarge, :original
      params << "quality=95"
      params << "format=auto"
    end

    return url if params.empty?

    separator = url.include?("?") ? "&" : "?"
    "#{url}#{separator}#{params.join("&")}"
  end

  def self.add_cloudfront_optimization(url, _size)
    # Amazon CloudFront optimization
    # This would typically involve setting up CloudFront functions
    # For now, return the original URL
    url
  end

  def self.add_fastly_optimization(url, size)
    # Fastly Image Optimizer parameters
    params = []

    case size
    when :thumbnail
      params << "width=92"
      params << "quality=85"
    when :small
      params << "width=154"
      params << "quality=85"
    when :medium
      params << "width=185"
      params << "quality=90"
    when :large
      params << "width=342"
      params << "quality=90"
    when :xlarge
      params << "width=500"
      params << "quality=95"
    end

    params << "format=auto"

    return url if params.empty?

    separator = url.include?("?") ? "&" : "?"
    "#{url}#{separator}#{params.join("&")}"
  end

  def self.cache_image_url(poster_path, size, url)
    # Cache the generated URL for performance
    cache_key = "image_url:#{poster_path}:#{size}"
    Cache.set(cache_key, url, 3600) # Cache for 1 hour
  rescue StandardError => e
    # Don't fail if caching fails
    StructuredLogger.debug("Image URL Cache Error",
                           type: "cache_error",
                           cache_key: cache_key,
                           error: e.message)
  end

  def self.size_to_width(size)
    case size
    when :thumbnail then 92
    when :small then 154
    when :medium then 185
    when :large then 342
    when :xlarge then 500
    end
  end
end
