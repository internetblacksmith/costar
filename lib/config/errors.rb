# frozen_string_literal: true

# Custom error classes for better error handling
class APIError < StandardError
  attr_reader :code, :message

  def initialize(code, message)
    @code = code
    @message = message
    super(message)
  end
end

# Base TMDB error class
class TMDBError < APIError; end

# Specific TMDB error types
class TMDBTimeoutError < TMDBError
  def initialize(message = "TMDB API request timed out")
    super(504, message)
  end
end

class TMDBAuthError < TMDBError
  def initialize(message = "TMDB API authentication failed")
    super(401, message)
  end
end

class TMDBRateLimitError < TMDBError
  def initialize(message = "TMDB API rate limit exceeded")
    super(429, message)
  end
end

class TMDBNotFoundError < TMDBError
  def initialize(message = "Resource not found in TMDB")
    super(404, message)
  end
end

class TMDBServiceError < TMDBError
  def initialize(message = "TMDB service unavailable")
    super(503, message)
  end
end

# Validation errors
class ValidationError < StandardError; end

# Cache errors
class CacheError < StandardError; end

class CacheConnectionError < CacheError; end
class CacheSerializationError < CacheError; end
