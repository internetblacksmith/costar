# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/dto/actor_search_request"

RSpec.describe ActorSearchRequest do
  describe "#initialize" do
    it "creates valid request with required fields" do
      request = described_class.new(query: "Tom Hanks", field: "actor1")
      expect(request.query).to eq("Tom Hanks")
      expect(request.field).to eq("actor1")
      expect(request.page).to eq(1)
      expect(request.limit).to eq(10)
    end

    it "creates valid request with optional fields" do
      request = described_class.new(
        query: "Tom Hanks",
        field: "actor2",
        page: 2,
        limit: 20
      )
      expect(request.page).to eq(2)
      expect(request.limit).to eq(20)
    end

    it "raises error for missing required fields" do
      expect { described_class.new(query: "Tom Hanks") }.to raise_error(
        BaseDTO::ValidationError,
        "Missing required fields: field"
      )
    end

    it "raises error for invalid field value" do
      expect { described_class.new(query: "Tom Hanks", field: "invalid") }.to raise_error(
        BaseDTO::ValidationError,
        "Invalid field: invalid. Must be one of: actor1, actor2"
      )
    end

    it "raises error for query too long" do
      long_query = "a" * 101
      expect { described_class.new(query: long_query, field: "actor1") }.to raise_error(
        BaseDTO::ValidationError,
        "Query too long (max 100 characters)"
      )
    end

    it "raises error for non-string query" do
      expect { described_class.new(query: 123, field: "actor1") }.to raise_error(
        BaseDTO::ValidationError,
        "Query must be a string"
      )
    end

    it "raises error for invalid page" do
      expect { described_class.new(query: "Tom", field: "actor1", page: 0) }.to raise_error(
        BaseDTO::ValidationError,
        "Page must be a positive integer"
      )
    end

    it "raises error for invalid limit" do
      expect { described_class.new(query: "Tom", field: "actor1", limit: 101) }.to raise_error(
        BaseDTO::ValidationError,
        "Limit must be a positive integer (max 100)"
      )
    end

    it "allows nil query for empty searches" do
      request = described_class.new(query: nil, field: "actor1")
      expect(request.query).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      request = described_class.new(query: "Tom Hanks", field: "actor1")
      expect(request.to_h).to eq({
                                   query: "Tom Hanks",
                                   field: "actor1",
                                   page: 1,
                                   limit: 10
                                 })
    end
  end
end
