# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/middleware/request_context_middleware"
require_relative "../../../lib/config/request_context"

# Ensure StructuredLogger is initialized
StructuredLogger.setup

RSpec.describe RequestContextMiddleware do
  let(:app) { double("app") }
  let(:middleware) { described_class.new(app) }
  let(:env) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/api/actors/search",
      "QUERY_STRING" => "q=test",
      "HTTP_USER_AGENT" => "RSpec Test",
      "REMOTE_ADDR" => "127.0.0.1"
    }
  end

  describe "#call" do
    it "creates a RequestContext for each request" do
      expect(app).to receive(:call).with(env) do
        expect(RequestContext.current).not_to be_nil
        expect(RequestContext.current.method).to eq("GET")
        expect(RequestContext.current.path).to eq("/api/actors/search")
        [200, {}, ["OK"]]
      end

      status, _, body = middleware.call(env)
      expect(status).to eq(200)
      expect(body).to eq(["OK"])
    end

    it "cleans up RequestContext after request completion" do
      expect(app).to receive(:call).with(env).and_return([200, {}, ["OK"]])

      middleware.call(env)
      expect(RequestContext.current).to be_nil
    end

    it "adds request ID to response headers in development" do
      allow(ENV).to receive(:fetch).with("RACK_ENV", "development").and_return("development")
      expect(app).to receive(:call).with(env).and_return([200, {}, ["OK"]])

      _, headers, = middleware.call(env)

      expect(headers).to have_key("X-Request-ID")
      expect(headers["X-Request-ID"]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      expect(headers).to have_key("X-Request-Duration")
      expect(headers["X-Request-Duration"]).to match(/\d+(\.\d+)?ms/)
    end

    it "does not add request headers in production" do
      allow(ENV).to receive(:fetch).with("RACK_ENV", "development").and_return("production")
      expect(app).to receive(:call).with(env).and_return([200, {}, ["OK"]])

      _, headers, = middleware.call(env)

      expect(headers).not_to have_key("X-Request-ID")
      expect(headers).not_to have_key("X-Request-Duration")
    end

    context "when an error occurs" do
      let(:error) { StandardError.new("Test error") }

      it "logs the error with request context" do
        expect(app).to receive(:call).with(env).and_raise(error)

        expect_any_instance_of(RequestContext).to receive(:log_error).with(
          "Request failed with unhandled exception",
          error,
          type: "request_error",
          status: 500
        )

        expect { middleware.call(env) }.to raise_error(error)
      end

      it "cleans up RequestContext even when error occurs" do
        expect(app).to receive(:call).with(env).and_raise(error)

        expect { middleware.call(env) }.to raise_error(error)
        expect(RequestContext.current).to be_nil
      end
    end

    it "logs request start and completion" do
      expect(app).to receive(:call).with(env).and_return([200, {}, ["OK"]])

      expect_any_instance_of(RequestContext).to receive(:log_event).with(
        "Request started",
        hash_including(
          type: "request_start",
          url: ":///api/actors/search?q=test",
          query_string: "q=test"
        )
      )

      expect_any_instance_of(RequestContext).to receive(:log_request_completion)

      middleware.call(env)
    end
  end
end
