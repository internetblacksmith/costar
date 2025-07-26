# frozen_string_literal: true

require "spec_helper"

RSpec.describe InputValidator do
  subject(:validator) { described_class.new }

  describe "#validate_actor_search" do
    context "with valid parameters" do
      it "validates search query with field" do
        params = { q: "Leonardo DiCaprio", field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to eq("Leonardo DiCaprio")
        expect(result.field).to eq("actor1")
        expect(result.errors).to be_empty
      end

      it "validates search query with actor2 field" do
        params = { q: "Tom Hanks", field: "actor2" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to eq("Tom Hanks")
        expect(result.field).to eq("actor2")
      end

      it "defaults to actor1 field when not provided" do
        params = { q: "Brad Pitt" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.field).to eq("actor1")
      end

      it "sanitizes query with special characters" do
        params = { q: "Jean-Claude Van Damme", field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to eq("Jean-Claude Van Damme")
      end
    end

    context "with empty or nil query" do
      it "handles empty query as valid" do
        params = { q: "", field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to be_nil
        expect(result.field).to eq("actor1")
      end

      it "handles nil query as valid" do
        params = { field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to be_nil
      end

      it "handles whitespace-only query as empty" do
        params = { q: "   ", field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to be_nil
      end
    end

    context "with invalid parameters" do
      it "sanitizes dangerous characters" do
        params = { q: "Actor<script>alert('xss')</script>", field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.query).to eq("Actorscriptalert'xss'script")
      end

      it "handles overly long queries" do
        params = { q: "a" * 150, field: "actor1" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be false
        expect(result.security_violation?).to be true
        expect(result.errors).to include(/Query too long/)
      end

      it "defaults invalid field names" do
        params = { q: "Actor", field: "invalid_field" }
        result = validator.validate_actor_search(params)

        expect(result.valid?).to be true
        expect(result.field).to eq("actor1")
      end
    end
  end

  describe "#validate_actor_id" do
    context "with valid actor ID" do
      it "validates numeric actor ID" do
        params = { id: "123456" }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be true
        expect(result.actor_id).to eq(123_456)
        expect(result.errors).to be_empty
      end

      it "validates integer actor ID" do
        params = { id: 789 }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be true
        expect(result.actor_id).to eq(789)
      end
    end

    context "with invalid actor ID" do
      it "rejects nil actor ID" do
        params = {}
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor ID is required and must be a valid integer")
      end

      it "rejects empty actor ID" do
        params = { id: "" }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor ID is required and must be a valid integer")
      end

      it "rejects non-numeric actor ID" do
        params = { id: "abc123" }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor ID is required and must be a valid integer")
      end

      it "rejects zero or negative actor ID" do
        params = { id: "0" }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor ID is required and must be a valid integer")
      end

      it "rejects overly large actor ID" do
        params = { id: "9999999999" }
        result = validator.validate_actor_id(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor ID is required and must be a valid integer")
      end
    end
  end

  describe "#validate_actor_comparison" do
    context "with valid parameters" do
      it "validates actor comparison with all parameters" do
        params = {
          actor1_id: "123",
          actor2_id: "456",
          actor1_name: "Leonardo DiCaprio",
          actor2_name: "Tom Hanks"
        }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be true
        expect(result.actor1_id).to eq(123)
        expect(result.actor2_id).to eq(456)
        expect(result.actor1_name).to eq("Leonardo DiCaprio")
        expect(result.actor2_name).to eq("Tom Hanks")
        expect(result.errors).to be_empty
      end

      it "validates with only required actor IDs" do
        params = { actor1_id: "789", actor2_id: "101112" }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be true
        expect(result.actor1_id).to eq(789)
        expect(result.actor2_id).to eq(101_112)
        expect(result.actor1_name).to be_nil
        expect(result.actor2_name).to be_nil
      end

      it "sanitizes actor names" do
        params = {
          actor1_id: "123",
          actor2_id: "456",
          actor1_name: "  Jean-Claude Van Damme  ",
          actor2_name: "Dwayne 'The Rock' Johnson"
        }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be true
        expect(result.actor1_name).to eq("Jean-Claude Van Damme")
        expect(result.actor2_name).to eq("Dwayne 'The Rock' Johnson")
      end
    end

    context "with missing required parameters" do
      it "rejects missing actor1_id" do
        params = { actor2_id: "456" }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor 1 ID is required")
      end

      it "rejects missing actor2_id" do
        params = { actor1_id: "123" }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor 2 ID is required")
      end

      it "rejects both missing actor IDs" do
        params = {}
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor 1 ID is required")
        expect(result.errors).to include("Actor 2 ID is required")
      end
    end

    context "with invalid parameters" do
      it "rejects invalid actor1_id format" do
        params = { actor1_id: "abc", actor2_id: "456" }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be false
        expect(result.errors).to include("Actor 1 ID is required")
      end

      it "filters dangerous characters from actor names" do
        params = {
          actor1_id: "123",
          actor2_id: "456",
          actor1_name: "Actor<script>",
          actor2_name: "Name&lt;tag&gt;"
        }
        result = validator.validate_actor_comparison(params)

        expect(result.valid?).to be true
        expect(result.actor1_name).to eq("Actorscript")
        expect(result.actor2_name).to eq("Namelttaggt")
      end
    end
  end

  describe "ValidationResult" do
    it "provides convenient accessor methods" do
      data = {
        query: "test query",
        field: "actor1",
        actor_id: 123,
        actor1_id: 456,
        actor2_id: 789,
        actor1_name: "Actor 1",
        actor2_name: "Actor 2"
      }
      result = InputValidator::ValidationResult.new(true, data, [])

      expect(result.query).to eq("test query")
      expect(result.field).to eq("actor1")
      expect(result.actor_id).to eq(123)
      expect(result.actor1_id).to eq(456)
      expect(result.actor2_id).to eq(789)
      expect(result.actor1_name).to eq("Actor 1")
      expect(result.actor2_name).to eq("Actor 2")
    end
  end
end
