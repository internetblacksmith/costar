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

class TMDBError < APIError; end

class ValidationError < StandardError; end
