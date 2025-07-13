# frozen_string_literal: true

# Base class for all Data Transfer Objects
# Provides common functionality for DTOs including validation and serialization
class BaseDTO
  class ValidationError < StandardError; end

  def initialize(attributes = {})
    @attributes = {}
    assign_attributes(attributes)
    validate!
  end

  # Convert DTO to hash representation
  def to_h
    @attributes.transform_values do |value|
      if value.nil?
        nil
      elsif value.is_a?(Array)
        value.map { |v| v.respond_to?(:to_h) ? v.to_h : v }
      elsif value.respond_to?(:to_h) && !value.is_a?(Hash)
        value.to_h
      else
        value
      end
    end
  end

  # Convert DTO to JSON string
  def to_json(*args)
    to_h.to_json(*args)
  end

  # Check equality based on attributes
  def ==(other)
    return false unless other.is_a?(self.class)

    to_h == other.to_h
  end

  alias eql? ==

  def hash
    to_h.hash
  end

  protected

  # Override in subclasses to define required fields
  def required_fields
    []
  end

  # Override in subclasses to define optional fields with defaults
  def optional_fields
    {}
  end

  # Override in subclasses to add custom validation
  def validate!
    validate_required_fields!
  end

  private

  def assign_attributes(attributes)
    symbolized_attrs = attributes.transform_keys(&:to_sym)

    # Assign required fields
    required_fields.each do |field|
      @attributes[field] = symbolized_attrs[field]
      define_accessor(field)
    end

    # Assign optional fields with defaults
    optional_fields.each do |field, default|
      @attributes[field] = symbolized_attrs.fetch(field, default)
      define_accessor(field)
    end

    # Ignore any extra fields (strict mode)
  end

  def define_accessor(field)
    singleton_class.class_eval do
      attr_reader field
    end
    instance_variable_set("@#{field}", @attributes[field])
  end

  def validate_required_fields!
    missing_fields = required_fields.select { |field| @attributes[field].nil? }
    return if missing_fields.empty?

    raise ValidationError, "Missing required fields: #{missing_fields.join(", ")}"
  end
end
