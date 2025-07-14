# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/request_context"

# Ensure StructuredLogger is initialized
StructuredLogger.setup

RSpec.describe RequestContext do
  let(:request_env) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/api/actors/search",
      "QUERY_STRING" => "q=test",
      "HTTP_USER_AGENT" => "RSpec Test",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "192.168.1.1, 10.0.0.1"
    }
  end

  let(:request) { double("request", env: request_env, request_method: "GET", path_info: "/api/actors/search", params: { q: "test" }) }
  let(:context) { described_class.new(request) }

  describe "#initialize" do
    it "creates a unique request ID" do
      expect(context.request_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "captures request information" do
      expect(context.method).to eq("GET")
      expect(context.path).to eq("/api/actors/search")
      expect(context.params).to eq({ q: "test" })
      expect(context.user_agent).to eq("RSpec Test")
    end

    it "extracts user IP from forwarded headers" do
      expect(context.user_ip).to eq("192.168.1.1")
    end

    it "falls back to REMOTE_ADDR when no forwarded headers" do
      request_env.delete("HTTP_X_FORWARDED_FOR")
      expect(context.user_ip).to eq("127.0.0.1")
    end
  end

  describe ".current and .current=" do
    before do
      # Ensure clean state
      described_class.current = nil
    end

    after do
      # Clean up after test
      described_class.current = nil
    end

    it "manages thread-local storage" do
      expect(described_class.current).to be_nil

      described_class.current = context
      expect(described_class.current).to eq(context)

      described_class.current = nil
      expect(described_class.current).to be_nil
    end
  end

  describe "#with_context" do
    it "sets the context for the duration of the block" do
      result = context.with_context do |ctx|
        expect(described_class.current).to eq(ctx)
        "test result"
      end

      expect(result).to eq("test result")
      expect(described_class.current).to be_nil
    end

    it "restores previous context after block execution" do
      previous_context = described_class.new(request)
      described_class.current = previous_context

      context.with_context do
        expect(described_class.current).to eq(context)
      end

      expect(described_class.current).to eq(previous_context)
    end
  end

  describe "#add_metadata and #get_metadata" do
    it "stores and retrieves metadata" do
      context.add_metadata(:user_id, 123)
      context.add_metadata("status", "active")

      expect(context.get_metadata(:user_id)).to eq(123)
      expect(context.get_metadata(:status)).to eq("active")
      expect(context.get_metadata(:missing)).to be_nil
    end
  end

  describe "#duration_ms" do
    it "calculates duration in milliseconds" do
      allow(Time).to receive(:now).and_return(context.start_time + 0.5)
      expect(context.duration_ms).to be_within(1).of(500)
    end
  end

  describe "#log_context" do
    it "generates structured log context" do
      context.add_metadata(:actor_id, 456)
      log_context = context.log_context

      expect(log_context).to include(
        request_id: context.request_id,
        method: "GET",
        path: "/api/actors/search",
        user_ip: "192.168.1.1",
        metadata: { actor_id: 456 }
      )
      expect(log_context[:duration_ms]).to be_a(Float)
    end
  end

  describe "#log_event" do
    it "logs an event with request context" do
      expect(StructuredLogger).to receive(:info).with(
        "Search performed",
        hash_including(
          request_id: context.request_id,
          type: "search",
          query: "test"
        )
      )

      context.log_event("Search performed", type: "search", query: "test")
    end
  end

  describe "#log_error" do
    let(:error) { StandardError.new("Test error") }

    before do
      allow(error).to receive(:backtrace).and_return(%w[line1 line2 line3 line4 line5 line6])
    end

    it "logs an error with request context and error details" do
      expect(StructuredLogger).to receive(:error).with(
        "API Error",
        hash_including(
          request_id: context.request_id,
          error_class: "StandardError",
          error_message: "Test error",
          error_backtrace: %w[line1 line2 line3 line4 line5],
          type: "api_error"
        )
      )

      context.log_error("API Error", error, type: "api_error")
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      allow(context).to receive(:duration_ms).and_return(123.45)
      expect(context.to_s).to match(%r{#<RequestContext id=.+ method=GET path=/api/actors/search duration=123.45ms>})
    end
  end
end
