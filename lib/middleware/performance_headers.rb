# frozen_string_literal: true

# Middleware for adding performance-related HTTP headers
class PerformanceHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Add performance headers based on content type and request
    add_performance_headers(headers, env)

    [status, headers, response]
  end

  private

  def add_performance_headers(headers, env)
    request_path = env["PATH_INFO"]
    content_type = headers["Content-Type"]

    # Add general performance headers
    add_general_headers(headers)

    # Add content-specific headers
    if static_asset?(request_path)
      add_static_asset_headers(headers, request_path)
    elsif api_endpoint?(request_path)
      add_api_headers(headers)
    elsif html_response?(content_type)
      add_html_headers(headers)
    end
  end

  def add_general_headers(headers)
    # DNS prefetch for external resources
    headers["X-DNS-Prefetch-Control"] = "on"

    # Enable resource timing API
    headers["Timing-Allow-Origin"] = "*"
  end

  def add_static_asset_headers(headers, path)
    # Long-term caching for static assets
    headers["Cache-Control"] = if immutable_asset?(path)
                                 "public, max-age=31536000, immutable" # 1 year
                               else
                                 "public, max-age=86400" # 1 day
                               end

    # ETags for conditional requests
    headers["ETag"] = generate_etag(path) unless headers["ETag"]

    # Compression hints
    return unless compressible_asset?(path)

    headers["Vary"] = "Accept-Encoding"
  end

  def add_api_headers(headers)
    # Short caching for API responses
    headers["Cache-Control"] = "public, max-age=300" # 5 minutes

    # Enable CORS preflight caching
    headers["Access-Control-Max-Age"] = "86400"

    # ETags for API responses
    headers["ETag"] = generate_api_etag unless headers["ETag"]
  end

  def add_html_headers(headers)
    # Resource hints for better performance
    preload_hints = build_preload_hints
    headers["Link"] = preload_hints unless preload_hints.empty?

    # DNS prefetch for external domains
    dns_prefetch = build_dns_prefetch_hints
    headers["X-DNS-Prefetch"] = dns_prefetch unless dns_prefetch.empty?

    # Short caching for HTML responses
    headers["Cache-Control"] = "public, max-age=60" # 1 minute
  end

  def static_asset?(path)
    path.match?(/\.(css|js|png|jpg|jpeg|gif|svg|woff|woff2|ico)$/)
  end

  def immutable_asset?(path)
    # Assets with hashes in filename are immutable
    path.match?(/\.[a-f0-9]{8,}\.(css|js)$/) ||
      path.match?(/\.(woff|woff2)$/)
  end

  def compressible_asset?(path)
    path.match?(/\.(css|js|svg|json)$/)
  end

  def api_endpoint?(path)
    path.start_with?("/api/")
  end

  def html_response?(content_type)
    content_type&.include?("text/html")
  end

  def generate_etag(path)
    # Simple ETag based on file path and modification time
    # In production, this could be based on actual file content hash
    content_hash = Digest::MD5.hexdigest("#{path}-#{Time.now.to_i / 3600}")
    "\"#{content_hash}\""
  end

  def generate_api_etag
    # Simple ETag for API responses
    "\"#{Time.now.to_i / 300}\"" # Changes every 5 minutes
  end

  def build_preload_hints
    # Build resource preload hints for critical resources
    hints = []

    # Don't preload main.css since it uses @import statements which delay usage
    # The browser warning occurs because @import creates additional network requests
    # after the preloaded CSS file is downloaded but before it's "used"

    # Preload critical JavaScript
    hints << "</js/app.js>; rel=preload; as=script"

    # Preload important fonts
    hints << "</fonts/roboto.woff2>; rel=preload; as=font; type=font/woff2; crossorigin" if font_available?

    hints.join(", ")
  end

  def build_dns_prefetch_hints
    # DNS prefetch for external domains
    domains = [
      "image.tmdb.org",
      "api.themoviedb.org"
    ]

    # Add CDN domains if configured
    cdn_domain = ENV.fetch("CDN_DOMAIN", nil)
    domains << cdn_domain if cdn_domain

    domains.map { |domain| "<//#{domain}>; rel=dns-prefetch" }.join(", ")
  end

  def font_available?
    # Check if font files exist
    File.exist?(File.join("public", "fonts", "roboto.woff2"))
  end
end
