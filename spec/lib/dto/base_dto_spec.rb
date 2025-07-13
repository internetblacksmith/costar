# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/dto/base_dto"

# Test DTO class
class TestDTO < BaseDTO
  protected

  def required_fields
    %i[name age]
  end

  def optional_fields
    {
      email: nil,
      active: true
    }
  end
end

RSpec.describe BaseDTO do
  let(:valid_attributes) { { name: "John", age: 25 } }

  describe "#initialize" do
    it "assigns required fields" do
      dto = TestDTO.new(valid_attributes)
      expect(dto.name).to eq("John")
      expect(dto.age).to eq(25)
    end

    it "assigns optional fields with provided values" do
      dto = TestDTO.new(valid_attributes.merge(email: "john@example.com", active: false))
      expect(dto.email).to eq("john@example.com")
      expect(dto.active).to be false
    end

    it "assigns optional fields with defaults when not provided" do
      dto = TestDTO.new(valid_attributes)
      expect(dto.email).to be_nil
      expect(dto.active).to be true
    end

    it "ignores extra fields" do
      dto = TestDTO.new(valid_attributes.merge(extra_field: "ignored"))
      expect { dto.extra_field }.to raise_error(NoMethodError)
    end

    it "raises ValidationError for missing required fields" do
      expect { TestDTO.new(name: "John") }.to raise_error(
        BaseDTO::ValidationError,
        "Missing required fields: age"
      )
    end

    it "handles string keys" do
      dto = TestDTO.new("name" => "John", "age" => 25)
      expect(dto.name).to eq("John")
      expect(dto.age).to eq(25)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      dto = TestDTO.new(valid_attributes)
      expect(dto.to_h).to eq({
                               name: "John",
                               age: 25,
                               email: nil,
                               active: true
                             })
    end

    it "converts nested DTOs to hashes" do
      nested_dto = TestDTO.new(valid_attributes)
      parent_dto = TestDTO.new(name: "Parent", age: 50, email: nested_dto)

      result = parent_dto.to_h
      expect(result[:email]).to eq({
                                     name: "John",
                                     age: 25,
                                     email: nil,
                                     active: true
                                   })
    end

    it "converts arrays of DTOs to hashes" do
      dto1 = TestDTO.new(name: "John", age: 25)
      dto2 = TestDTO.new(name: "Jane", age: 30)
      parent_dto = TestDTO.new(name: "Parent", age: 50, email: [dto1, dto2])

      result = parent_dto.to_h
      expect(result[:email]).to eq([
                                     { name: "John", age: 25, email: nil, active: true },
                                     { name: "Jane", age: 30, email: nil, active: true }
                                   ])
    end
  end

  describe "#to_json" do
    it "returns JSON string" do
      dto = TestDTO.new(valid_attributes)
      json = dto.to_json
      parsed = JSON.parse(json)

      expect(parsed).to eq({
                             "name" => "John",
                             "age" => 25,
                             "email" => nil,
                             "active" => true
                           })
    end
  end

  describe "#==" do
    it "returns true for DTOs with same attributes" do
      dto1 = TestDTO.new(valid_attributes)
      dto2 = TestDTO.new(valid_attributes)
      expect(dto1).to eq(dto2)
    end

    it "returns false for DTOs with different attributes" do
      dto1 = TestDTO.new(valid_attributes)
      dto2 = TestDTO.new(valid_attributes.merge(age: 30))
      expect(dto1).not_to eq(dto2)
    end

    it "returns false for different DTO types" do
      dto = TestDTO.new(valid_attributes)
      expect(dto).not_to eq("not a dto")
    end
  end

  describe "#hash" do
    it "returns same hash for equal DTOs" do
      dto1 = TestDTO.new(valid_attributes)
      dto2 = TestDTO.new(valid_attributes)
      expect(dto1.hash).to eq(dto2.hash)
    end

    it "returns different hash for different DTOs" do
      dto1 = TestDTO.new(valid_attributes)
      dto2 = TestDTO.new(valid_attributes.merge(age: 30))
      expect(dto1.hash).not_to eq(dto2.hash)
    end
  end
end
