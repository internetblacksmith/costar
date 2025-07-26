# frozen_string_literal: true

require_relative "../services/input_sanitizer"

##
# Input validation for API endpoints
#
# Provides centralized input validation with security best practices
# and consistent error handling across all API endpoints.
# Uses InputSanitizer for all sanitization operations.
#
# @example Basic usage
#   validator = InputValidator.new
#   result = validator.validate_actor_search(params)
#   if result.valid?
#     query = result.query
#     field = result.field
#   else
#     errors = result.errors
#   end
#
class InputValidator
  def initialize
    @sanitizer = InputSanitizer.new
  end
  # Result object for validation operations
  ValidationResult = Struct.new(:valid?, :data, :errors) do
    def initialize(valid, data = {}, errors = [])
      super
    end

    def query
      data[:query]
    end

    def field
      data[:field]
    end

    def actor_id
      data[:actor_id]
    end

    def actor1_id
      data[:actor1_id]
    end

    def actor2_id
      data[:actor2_id]
    end

    def actor1_name
      data[:actor1_name]
    end

    def actor2_name
      data[:actor2_name]
    end

    def security_violation?
      data[:security_violation] == true
    end
  end

  ##
  # Validates actor search parameters
  #
  # @param params [Hash] Request parameters
  # @return [ValidationResult] Validation result with sanitized data
  #
  def validate_actor_search(params)
    errors = []
    data = {}

    # Check if input is too large before sanitizing
    raw_query = params[:q]
    if raw_query && raw_query.to_s.length > @sanitizer.max_query_length
      # For overly long queries in search (security concern), return invalid with error
      errors << "Query too long. Maximum length is #{@sanitizer.max_query_length} characters."
      data[:security_violation] = true # Flag for 400 status
      return ValidationResult.new(false, data, errors)
    end

    # Validate and sanitize query
    query = @sanitizer.sanitize_query(raw_query)
    if query.nil? || query.empty?
      data[:query] = nil
      data[:field] = @sanitizer.sanitize_field_name(params[:field])
      return ValidationResult.new(true, data, []) # Empty query is valid (returns empty results)
    end

    data[:query] = query
    data[:field] = @sanitizer.sanitize_field_name(params[:field])

    ValidationResult.new(true, data, errors)
  end

  ##
  # Validates actor ID parameter
  #
  # @param params [Hash] Request parameters
  # @return [ValidationResult] Validation result with sanitized actor ID
  #
  def validate_actor_id(params)
    errors = []
    data = {}

    actor_id = @sanitizer.sanitize_id(params[:id])
    if actor_id.nil?
      errors << "Actor ID is required and must be a valid integer"
      return ValidationResult.new(false, data, errors)
    end

    data[:actor_id] = actor_id
    ValidationResult.new(true, data, errors)
  end

  ##
  # Validates actor comparison parameters
  #
  # @param params [Hash] Request parameters
  # @return [ValidationResult] Validation result with sanitized actor data
  #
  def validate_actor_comparison(params)
    errors = []
    data = {}

    # Validate required actor IDs
    actor1_id = @sanitizer.sanitize_id(params[:actor1_id])
    actor2_id = @sanitizer.sanitize_id(params[:actor2_id])

    if actor1_id.nil?
      errors << "Actor 1 ID is required"
    else
      data[:actor1_id] = actor1_id
    end

    if actor2_id.nil?
      errors << "Actor 2 ID is required"
    else
      data[:actor2_id] = actor2_id
    end

    # Validate optional actor names
    data[:actor1_name] = @sanitizer.sanitize_name(params[:actor1_name])
    data[:actor2_name] = @sanitizer.sanitize_name(params[:actor2_name])

    valid = errors.empty?
    ValidationResult.new(valid, data, errors)
  end
end
