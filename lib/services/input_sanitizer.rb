# frozen_string_literal: true

##
# Centralized input sanitization service
#
# Provides reusable sanitization methods for user input across the application.
# All methods are designed to be safe, preserving international characters
# while removing potentially dangerous content.
#
# @example Basic usage
#   sanitizer = InputSanitizer.new
#   clean_query = sanitizer.sanitize_query("Robert Downey Jr.")
#   clean_id = sanitizer.sanitize_id("12345")
#   clean_field = sanitizer.sanitize_field_name("actor1")
#
# @example Chaining with validation
#   sanitizer = InputSanitizer.new
#   query = sanitizer.sanitize_query(params[:q])
#   if sanitizer.valid_query?(query)
#     # Process query
#   end
#
class InputSanitizer
  # Default maximum lengths (can be overridden by configuration)
  DEFAULT_MAX_QUERY_LENGTH = 100
  DEFAULT_MAX_NAME_LENGTH = 200
  MAX_ACTOR_ID = 999_999_999

  # Allowed field names for actor search
  ALLOWED_FIELD_NAMES = %w[actor1 actor2].freeze

  def initialize
    # Load configuration if available
    @max_input_length = if defined?(ConfigurationPolicy)
                          ConfigurationPolicy.get(:security, :max_input_length)
                        else
                          DEFAULT_MAX_NAME_LENGTH
                        end
  end

  def max_query_length
    [DEFAULT_MAX_QUERY_LENGTH, @max_input_length].min
  end

  def max_name_length
    @max_input_length
  end

  ##
  # Sanitizes search query input
  #
  # Removes dangerous characters while preserving international names
  # and common punctuation used in names.
  #
  # @param query [String, nil] Raw query input
  # @return [String, nil] Sanitized query or nil if invalid
  #
  def sanitize_query(query)
    return nil if query.nil?

    # Strip whitespace and enforce length limit
    sanitized = query.to_s.strip
    return nil if sanitized.empty?
    return nil if sanitized.length > max_query_length

    # Remove potentially dangerous characters but allow international names
    # Allow: letters (any language), numbers, spaces, apostrophes, hyphens, periods
    cleaned = sanitized.gsub(/[^\p{L}\p{N}\s'\-\.]/, "").strip
    cleaned.empty? ? nil : cleaned
  end

  ##
  # Sanitizes actor name input
  #
  # Similar to query sanitization but allows parentheses for name disambiguation
  # (e.g., "Chris Evans (I)")
  #
  # @param name [String, nil] Raw actor name input
  # @return [String, nil] Sanitized name or nil if invalid
  #
  def sanitize_name(name)
    return nil if name.nil?

    # Strip whitespace and enforce length limit
    sanitized = name.to_s.strip
    return nil if sanitized.empty?
    return nil if sanitized.length > max_name_length

    # Allow: letters, numbers, spaces, apostrophes, hyphens, periods, parentheses
    cleaned = sanitized.gsub(/[^\p{L}\p{N}\s'\-\.\(\)]/, "").strip
    cleaned.empty? ? nil : cleaned
  end

  ##
  # Sanitizes actor ID input
  #
  # Ensures actor IDs are positive integers within reasonable bounds.
  #
  # @param actor_id [String, Integer, nil] Raw actor ID input
  # @return [Integer, nil] Sanitized actor ID or nil if invalid
  #
  def sanitize_id(actor_id)
    return nil if actor_id.nil? || actor_id.to_s.strip.empty?

    # Actor IDs should be positive integers
    id_string = actor_id.to_s.strip
    return nil unless id_string.match?(/\A\d+\z/) # Only digits allowed

    parsed_id = id_string.to_i
    return nil if parsed_id <= 0 || parsed_id > MAX_ACTOR_ID

    parsed_id
  end

  ##
  # Sanitizes field name input
  #
  # Ensures only whitelisted field names are accepted.
  # Falls back to default field if invalid.
  #
  # @param field [String, nil] Raw field input
  # @return [String] Sanitized field name (defaults to "actor1")
  #
  def sanitize_field_name(field)
    return "actor1" if field.nil?

    # Only allow predefined field names
    ALLOWED_FIELD_NAMES.include?(field.to_s) ? field.to_s : "actor1"
  end

  ##
  # Checks if a sanitized query is valid
  #
  # @param query [String, nil] Sanitized query
  # @return [Boolean] true if query is valid
  #
  def valid_query?(query)
    !query.nil? && !query.empty?
  end

  ##
  # Checks if a sanitized ID is valid
  #
  # @param id [Integer, nil] Sanitized ID
  # @return [Boolean] true if ID is valid
  #
  def valid_id?(id)
    !id.nil? && id.is_a?(Integer) && id.positive?
  end

  ##
  # Checks if a sanitized name is valid
  #
  # @param name [String, nil] Sanitized name
  # @return [Boolean] true if name is valid
  #
  def valid_name?(name)
    !name.nil? && !name.empty?
  end

  ##
  # Sanitizes a generic text input
  #
  # Removes HTML/script tags and dangerous characters while preserving
  # readable text content.
  #
  # @param text [String, nil] Raw text input
  # @param max_length [Integer] Maximum allowed length
  # @return [String, nil] Sanitized text or nil if invalid
  #
  def sanitize_text(text, max_length: 500)
    return nil if text.nil?

    sanitized = text.to_s.strip
    return nil if sanitized.empty?

    # Remove HTML/script tags and truncate
    sanitized = sanitized.gsub(/<[^>]*>/, "")
                         .gsub(/[<>]/, "")
                         .strip
                         .slice(0, max_length)

    sanitized.empty? ? nil : sanitized
  end

  ##
  # Sanitizes an array of IDs
  #
  # Useful for batch operations or multiple selections.
  #
  # @param ids [Array<String, Integer>] Array of raw IDs
  # @param max_count [Integer] Maximum number of IDs allowed
  # @return [Array<Integer>] Array of valid, sanitized IDs
  #
  def sanitize_id_array(ids, max_count: 10)
    return [] unless ids.is_a?(Array)

    ids.first(max_count)
       .map { |id| sanitize_id(id) }
       .compact
       .uniq
  end

  ##
  # Sanitizes URL parameters by removing dangerous characters
  #
  # @param url [String, nil] Raw URL input
  # @return [String, nil] Sanitized URL or nil if invalid
  #
  def sanitize_url(url)
    return nil if url.nil?

    sanitized = url.to_s.strip
    return nil if sanitized.empty?

    # Basic URL sanitization - remove javascript: and data: schemes
    return nil if sanitized.match?(/\A(javascript|data):/i)

    # Remove angle brackets and quotes
    sanitized.gsub(/[<>"']/, "").strip
  end

  ##
  # Sanitizes a hash of parameters
  #
  # Applies appropriate sanitization to each parameter based on its key.
  #
  # @param params [Hash] Raw parameters
  # @param allowed_keys [Array<Symbol>] Whitelist of allowed parameter keys
  # @return [Hash] Sanitized parameters
  #
  def sanitize_params(params, allowed_keys:)
    return {} unless params.is_a?(Hash)

    sanitized = {}
    allowed_keys.each do |key|
      next unless params.key?(key) || params.key?(key.to_s)

      value = params[key] || params[key.to_s]
      sanitized[key] = case key.to_s
                       when /(_id|id)\z/
                         sanitize_id(value)
                       when /(name|query|q)\z/
                         sanitize_query(value)
                       when "field"
                         sanitize_field_name(value)
                       else
                         sanitize_text(value)
                       end
    end

    sanitized.compact
  end
end
