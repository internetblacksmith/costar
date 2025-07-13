# frozen_string_literal: true

# CDN-specific optimization methods
module CDNOptimizers
  def cloudflare_optimizations(optimizations)
    params = []

    params << "width=#{optimizations[:width]}" if optimizations[:width]

    params << if optimizations[:quality]
                "quality=#{optimizations[:quality]}"
              else
                "quality=85" # Default quality
              end

    params << "format=auto"
    params
  end

  def cloudfront_optimizations(optimizations)
    # CloudFront optimizations would typically be handled by Lambda@Edge
    # or CloudFront Functions, so we just return the basic params
    params = []

    params << "w=#{optimizations[:width]}" if optimizations[:width]
    params << "q=#{optimizations[:quality]}" if optimizations[:quality]

    params
  end

  def fastly_optimizations(optimizations)
    params = []

    params << "width=#{optimizations[:width]}" if optimizations[:width]

    params << "quality=#{optimizations[:quality]}" if optimizations[:quality]

    params << "auto=format,compress"
    params
  end
end
