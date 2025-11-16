# frozen_string_literal: true

require_relative "cdn_optimizers"

# CDN configuration and asset URL helpers
class CDNConfig
  extend CDNOptimizers

  class << self
    def enabled?
      !cdn_base_url.nil? && !cdn_base_url.empty?
    end

    def cdn_base_url
      ENV.fetch("CDN_BASE_URL", nil)
    end

    def asset_url(path)
      return path unless enabled?

      # Remove leading slash if present
      clean_path = path.start_with?("/") ? path[1..] : path

      "#{cdn_base_url}/#{clean_path}"
    end

    def image_url(path, optimizations = {})
      base_url = enabled? ? cdn_base_url : ""

      # Remove leading slash if present
      clean_path = path.start_with?("/") ? path[1..] : path

      url = enabled? ? "#{base_url}/#{clean_path}" : path

      # Add optimization parameters if using supported CDN
      add_image_optimizations(url, optimizations)
    end

    def preload_hints
      return [] unless enabled?

      hints = []

      # DNS prefetch for CDN domain
      hints << build_dns_prefetch_hint(cdn_domain)

      # Preconnect to CDN for faster resource loading
      hints << build_preconnect_hint(cdn_domain)

      hints
    end

    def security_headers
      return {} unless enabled?

      {
        # Allow CDN domain in CSP
        "Content-Security-Policy" => build_csp_header,

        # DNS prefetch control
        "X-DNS-Prefetch-Control" => "on"
      }
    end

    private

    def cdn_domain
      return nil unless enabled?

      URI(cdn_base_url).host
    rescue URI::InvalidURIError
      nil
    end

    def add_image_optimizations(url, optimizations)
      return url if optimizations.empty? || !enabled?

      params = build_optimization_params(optimizations)
      return url if params.empty?

      separator = url.include?("?") ? "&" : "?"
      "#{url}#{separator}#{params.join("&")}"
    end

    def build_optimization_params(optimizations)
      params = []
      params << "w=#{optimizations[:width]}" if optimizations[:width]
      params << "q=#{optimizations[:quality]}" if optimizations[:quality]
      params << "f=auto" if optimizations[:auto_format]
      params << "dpr=#{optimizations[:dpr]}" if optimizations[:dpr]
      params
    end

    def build_dns_prefetch_hint(domain)
      return nil unless domain

      "<//#{domain}>; rel=dns-prefetch"
    end

    def build_preconnect_hint(domain)
      return nil unless domain

      "<//#{domain}>; rel=preconnect; crossorigin"
    end

    def build_csp_header
      # Basic CSP that allows CDN resources
      csp_parts = [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "font-src 'self' data:",
        "connect-src 'self' api.themoviedb.org"
      ]

      if cdn_domain
        # Allow resources from CDN
        csp_parts << "img-src 'self' #{cdn_domain} image.tmdb.org data:"
        csp_parts << "media-src 'self' #{cdn_domain}"
      else
        csp_parts << "img-src 'self' image.tmdb.org data:"
      end

      csp_parts.join("; ")
    end
  end
end
