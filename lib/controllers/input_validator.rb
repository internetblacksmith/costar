# frozen_string_literal: true

##
# Input validation and sanitization for API endpoints
#
# Provides centralized input validation with security best practices
# and consistent error handling across all API endpoints.
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

    # Validate and sanitize query
    query = sanitize_search_query(params[:q])
    if query.nil? || query.empty?
      data[:query] = nil
      data[:field] = sanitize_field_name(params[:field])
      return ValidationResult.new(true, data, []) # Empty query is valid (returns empty results)
    end

    data[:query] = query
    data[:field] = sanitize_field_name(params[:field])

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

    actor_id = sanitize_actor_id(params[:id])
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
    actor1_id = sanitize_actor_id(params[:actor1_id])
    actor2_id = sanitize_actor_id(params[:actor2_id])

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
    data[:actor1_name] = sanitize_actor_name(params[:actor1_name])
    data[:actor2_name] = sanitize_actor_name(params[:actor2_name])

    valid = errors.empty?
    ValidationResult.new(valid, data, errors)
  end

  private

  ##
  # Sanitizes search query input
  #
  # @param query [String, nil] Raw query input
  # @return [String, nil] Sanitized query or nil if invalid
  #
  def sanitize_search_query(query)
    return nil if query.nil?

    # Strip whitespace and limit length
    sanitized = query.to_s.strip
    return nil if sanitized.empty?
    return nil if sanitized.length > 100 # Reasonable search query limit

    # Remove potentially dangerous characters but allow international names
    # Allow letters, numbers, spaces, apostrophes, hyphens, and periods
    sanitized.gsub(/[^\p{L}\p{N}\s'\-\.]/, "").strip
  end

  ##
  # Sanitizes field name input
  #
  # @param field [String, nil] Raw field input
  # @return [String] Sanitized field name
  #
  def sanitize_field_name(field)
    return "actor1" if field.nil?

    # Only allow predefined field names
    %w[actor1 actor2].include?(field.to_s) ? field.to_s : "actor1"
  end

  ##
  # Sanitizes actor ID input
  #
  # @param actor_id [String, Integer, nil] Raw actor ID input
  # @return [Integer, nil] Sanitized actor ID or nil if invalid
  #
  def sanitize_actor_id(actor_id)
    return nil if actor_id.nil? || actor_id.to_s.strip.empty?

    # Actor IDs should be positive integers
    id = actor_id.to_s.strip
    return nil unless id.match?(/\A\d+\z/) # Only digits

    parsed_id = id.to_i
    return nil if parsed_id <= 0 || parsed_id > 999_999_999 # Reasonable limits

    parsed_id
  end

  ##
  # Sanitizes actor name input
  #
  # @param name [String, nil] Raw actor name input
  # @return [String, nil] Sanitized actor name or nil if invalid
  #
  def sanitize_actor_name(name)
    return nil if name.nil?

    # Strip whitespace and limit length
    sanitized = name.to_s.strip
    return nil if sanitized.empty?
    return nil if sanitized.length > 200 # Reasonable name limit

    # Allow letters, numbers, spaces, apostrophes, hyphens, periods, and common punctuation
    # Remove potentially dangerous characters but preserve international names
    sanitized.gsub(/[^\p{L}\p{N}\s'\-\.\(\)]/, "").strip
  end
end
