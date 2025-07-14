# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/services/input_sanitizer"

RSpec.describe InputSanitizer do
  let(:sanitizer) { described_class.new }

  describe "#sanitize_query" do
    context "with valid input" do
      it "preserves clean text" do
        expect(sanitizer.sanitize_query("Robert Downey Jr")).to eq("Robert Downey Jr")
      end

      it "preserves international characters" do
        expect(sanitizer.sanitize_query("Gérard Depardieu")).to eq("Gérard Depardieu")
        expect(sanitizer.sanitize_query("Björk")).to eq("Björk")
        expect(sanitizer.sanitize_query("渡辺謙")).to eq("渡辺謙")
      end

      it "preserves allowed punctuation" do
        expect(sanitizer.sanitize_query("O'Brien")).to eq("O'Brien")
        expect(sanitizer.sanitize_query("Anne-Marie")).to eq("Anne-Marie")
        expect(sanitizer.sanitize_query("Jr.")).to eq("Jr.")
      end

      it "trims whitespace" do
        expect(sanitizer.sanitize_query("  Tom Hanks  ")).to eq("Tom Hanks")
      end

      it "removes dangerous characters" do
        expect(sanitizer.sanitize_query("Tom<script>alert('xss')</script>Hanks")).to eq("Tomscriptalert'xss'scriptHanks")
        expect(sanitizer.sanitize_query("Robert'); DROP TABLE--")).to eq("Robert' DROP TABLE--")
      end
    end

    context "with invalid input" do
      it "returns nil for nil input" do
        expect(sanitizer.sanitize_query(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(sanitizer.sanitize_query("")).to be_nil
        expect(sanitizer.sanitize_query("   ")).to be_nil
      end

      it "returns nil for strings exceeding max length" do
        long_query = "a" * 101
        expect(sanitizer.sanitize_query(long_query)).to be_nil
      end

      it "returns nil if all characters are removed" do
        expect(sanitizer.sanitize_query("<>{}[]")).to be_nil
      end
    end
  end

  describe "#sanitize_name" do
    context "with valid input" do
      it "preserves clean names" do
        expect(sanitizer.sanitize_name("Chris Evans")).to eq("Chris Evans")
      end

      it "preserves parentheses for disambiguation" do
        expect(sanitizer.sanitize_name("Chris Evans (I)")).to eq("Chris Evans (I)")
      end

      it "handles complex names" do
        expect(sanitizer.sanitize_name("Jean-Claude Van Damme")).to eq("Jean-Claude Van Damme")
        expect(sanitizer.sanitize_name("Samuel L. Jackson")).to eq("Samuel L. Jackson")
      end
    end

    context "with invalid input" do
      it "returns nil for nil input" do
        expect(sanitizer.sanitize_name(nil)).to be_nil
      end

      it "returns nil for strings exceeding max length" do
        long_name = "a" * 201
        expect(sanitizer.sanitize_name(long_name)).to be_nil
      end
    end
  end

  describe "#sanitize_id" do
    context "with valid input" do
      it "accepts integer input" do
        expect(sanitizer.sanitize_id(123)).to eq(123)
      end

      it "accepts string input" do
        expect(sanitizer.sanitize_id("456")).to eq(456)
      end

      it "trims whitespace from strings" do
        expect(sanitizer.sanitize_id("  789  ")).to eq(789)
      end

      it "accepts maximum allowed ID" do
        expect(sanitizer.sanitize_id(999_999_999)).to eq(999_999_999)
      end
    end

    context "with invalid input" do
      it "returns nil for nil input" do
        expect(sanitizer.sanitize_id(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(sanitizer.sanitize_id("")).to be_nil
        expect(sanitizer.sanitize_id("   ")).to be_nil
      end

      it "returns nil for non-numeric strings" do
        expect(sanitizer.sanitize_id("abc")).to be_nil
        expect(sanitizer.sanitize_id("12a34")).to be_nil
      end

      it "returns nil for zero or negative IDs" do
        expect(sanitizer.sanitize_id(0)).to be_nil
        expect(sanitizer.sanitize_id(-1)).to be_nil
      end

      it "returns nil for IDs exceeding maximum" do
        expect(sanitizer.sanitize_id(1_000_000_000)).to be_nil
      end
    end
  end

  describe "#sanitize_field_name" do
    it "accepts valid field names" do
      expect(sanitizer.sanitize_field_name("actor1")).to eq("actor1")
      expect(sanitizer.sanitize_field_name("actor2")).to eq("actor2")
    end

    it "defaults to actor1 for invalid input" do
      expect(sanitizer.sanitize_field_name(nil)).to eq("actor1")
      expect(sanitizer.sanitize_field_name("")).to eq("actor1")
      expect(sanitizer.sanitize_field_name("actor3")).to eq("actor1")
      expect(sanitizer.sanitize_field_name("invalid")).to eq("actor1")
    end
  end

  describe "#valid_query?" do
    it "returns true for valid queries" do
      expect(sanitizer.valid_query?("Tom Hanks")).to be true
    end

    it "returns false for invalid queries" do
      expect(sanitizer.valid_query?(nil)).to be false
      expect(sanitizer.valid_query?("")).to be false
    end
  end

  describe "#valid_id?" do
    it "returns true for valid IDs" do
      expect(sanitizer.valid_id?(123)).to be true
    end

    it "returns false for invalid IDs" do
      expect(sanitizer.valid_id?(nil)).to be false
      expect(sanitizer.valid_id?(0)).to be false
      expect(sanitizer.valid_id?(-1)).to be false
      expect(sanitizer.valid_id?("123")).to be false
    end
  end

  describe "#valid_name?" do
    it "returns true for valid names" do
      expect(sanitizer.valid_name?("Tom Hanks")).to be true
    end

    it "returns false for invalid names" do
      expect(sanitizer.valid_name?(nil)).to be false
      expect(sanitizer.valid_name?("")).to be false
    end
  end

  describe "#sanitize_text" do
    it "removes HTML tags" do
      expect(sanitizer.sanitize_text("<p>Hello <b>world</b></p>")).to eq("Hello world")
    end

    it "removes script tags" do
      expect(sanitizer.sanitize_text("Hello<script>alert('xss')</script>World")).to eq("Helloalert('xss')World")
    end

    it "respects max length" do
      long_text = "a" * 600
      expect(sanitizer.sanitize_text(long_text).length).to eq(500)
      expect(sanitizer.sanitize_text(long_text, max_length: 100).length).to eq(100)
    end

    it "returns nil for empty input after sanitization" do
      expect(sanitizer.sanitize_text("<><>")).to be_nil
    end
  end

  describe "#sanitize_id_array" do
    it "sanitizes array of IDs" do
      input = ["123", 456, "789", "abc", nil, 0]
      expect(sanitizer.sanitize_id_array(input)).to eq([123, 456, 789])
    end

    it "removes duplicates" do
      input = ["123", "123", 456, "456"]
      expect(sanitizer.sanitize_id_array(input)).to eq([123, 456])
    end

    it "respects max count" do
      input = (1..20).to_a
      expect(sanitizer.sanitize_id_array(input, max_count: 5)).to eq([1, 2, 3, 4, 5])
    end

    it "returns empty array for invalid input" do
      expect(sanitizer.sanitize_id_array(nil)).to eq([])
      expect(sanitizer.sanitize_id_array("not an array")).to eq([])
    end
  end

  describe "#sanitize_url" do
    it "allows valid URLs" do
      expect(sanitizer.sanitize_url("https://example.com")).to eq("https://example.com")
      expect(sanitizer.sanitize_url("http://example.com/path?param=value")).to eq("http://example.com/path?param=value")
    end

    it "removes dangerous schemes" do
      expect(sanitizer.sanitize_url("javascript:alert('xss')")).to be_nil
      expect(sanitizer.sanitize_url("data:text/html,<script>alert('xss')</script>")).to be_nil
    end

    it "removes dangerous characters" do
      expect(sanitizer.sanitize_url("https://example.com/<script>")).to eq("https://example.com/script")
      expect(sanitizer.sanitize_url('https://example.com/"onclick="alert()')).to eq("https://example.com/onclick=alert()")
    end

    it "returns nil for nil or empty input" do
      expect(sanitizer.sanitize_url(nil)).to be_nil
      expect(sanitizer.sanitize_url("")).to be_nil
      expect(sanitizer.sanitize_url("   ")).to be_nil
    end
  end

  describe "#sanitize_params" do
    let(:allowed_keys) { %i[actor_id name query field] }

    it "sanitizes parameters based on key patterns" do
      params = {
        actor_id: "123",
        name: "Tom<script>Hanks",
        query: "search query",
        field: "actor1"
      }

      result = sanitizer.sanitize_params(params, allowed_keys: allowed_keys)

      expect(result).to eq({
                             actor_id: 123,
                             name: "TomscriptHanks",
                             query: "search query",
                             field: "actor1"
                           })
    end

    it "handles string keys" do
      params = {
        "actor_id" => "456",
        "name" => "Brad Pitt"
      }

      result = sanitizer.sanitize_params(params, allowed_keys: allowed_keys)

      expect(result[:actor_id]).to eq(456)
      expect(result[:name]).to eq("Brad Pitt")
    end

    it "removes nil values" do
      params = {
        actor_id: nil,
        name: "",
        query: "valid"
      }

      result = sanitizer.sanitize_params(params, allowed_keys: allowed_keys)

      expect(result).to eq({ query: "valid" })
    end

    it "ignores non-whitelisted keys" do
      params = {
        actor_id: "123",
        evil_param: "<script>alert('xss')</script>"
      }

      result = sanitizer.sanitize_params(params, allowed_keys: allowed_keys)

      expect(result).to eq({ actor_id: 123 })
      expect(result).not_to have_key(:evil_param)
    end

    it "returns empty hash for invalid input" do
      expect(sanitizer.sanitize_params(nil, allowed_keys: allowed_keys)).to eq({})
      expect(sanitizer.sanitize_params("not a hash", allowed_keys: allowed_keys)).to eq({})
    end
  end
end

