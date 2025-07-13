# frozen_string_literal: true

require "spec_helper"

RSpec.describe ApiResponseBuilder do
  let(:app) { double("app") }
  let(:request) { double("request", xhr?: false, content_type: nil) }
  let(:builder) { described_class.new(app) }

  before do
    allow(app).to receive(:request).and_return(request)
    allow(app).to receive(:content_type)
    allow(app).to receive(:status)
  end

  describe "#success" do
    it "builds a successful JSON response" do
      data = { actors: [{ id: 1, name: "Actor 1" }] }

      expect(app).to receive(:content_type).with(:json)
      result = JSON.parse(builder.success(data))

      expect(result["status"]).to eq("success")
      expect(result["data"]).to eq({ "actors" => [{ "id" => 1, "name" => "Actor 1" }] })
      expect(result["timestamp"]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes metadata when provided" do
      data = { results: [] }
      meta = { page: 1, total_pages: 5 }

      result = JSON.parse(builder.success(data, meta: meta))

      expect(result["meta"]).to eq({ "page" => 1, "total_pages" => 5 })
    end

    it "excludes metadata when empty" do
      data = { results: [] }

      result = JSON.parse(builder.success(data))

      expect(result).not_to have_key("meta")
    end
  end

  describe "#error" do
    it "builds an error JSON response" do
      expect(app).to receive(:status).with(400)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.error("Bad request"))

      expect(result["status"]).to eq("error")
      expect(result["message"]).to eq("Bad request")
      expect(result["code"]).to eq(400)
      expect(result["timestamp"]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "uses custom status code when provided" do
      expect(app).to receive(:status).with(404)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.error("Not found", code: 404))

      expect(result["code"]).to eq(404)
    end

    it "includes details when provided" do
      details = { field: "actor_id", value: "invalid" }

      result = JSON.parse(builder.error("Validation failed", details: details))

      expect(result["details"]).to eq({ "field" => "actor_id", "value" => "invalid" })
    end

    it "excludes details when empty" do
      result = JSON.parse(builder.error("Error message"))

      expect(result).not_to have_key("details")
    end
  end

  describe "#validation_error" do
    it "builds a validation error response" do
      errors = ["Actor ID is required", "Actor ID must be numeric"]

      expect(app).to receive(:status).with(400)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.validation_error(errors))

      expect(result["status"]).to eq("error")
      expect(result["message"]).to eq("Validation failed")
      expect(result["details"]["errors"]).to eq(errors)
    end

    it "uses custom status code when provided" do
      expect(app).to receive(:status).with(422)

      builder.validation_error(["Invalid data"], code: 422)
    end
  end

  describe "#render_erb" do
    it "renders an ERB template" do
      locals = { actors: [], field: "actor1" }

      expect(app).to receive(:erb).with(:suggestions, locals: locals).and_return("<html>content</html>")

      result = builder.render_erb(:suggestions, locals)

      expect(result).to eq("<html>content</html>")
    end

    context "when template rendering fails" do
      before do
        allow(app).to receive(:erb).and_raise(StandardError.new("Template error"))
      end

      it "returns JSON error for XHR requests" do
        allow(request).to receive(:xhr?).and_return(true)

        expect(app).to receive(:status).with(500)
        expect(app).to receive(:content_type).with(:json)

        result = JSON.parse(builder.render_erb(:broken_template))

        expect(result["status"]).to eq("error")
        expect(result["message"]).to eq("Template rendering failed")
      end

      it "returns HTML error for regular requests" do
        expect(app).to receive(:status).with(500)

        result = builder.render_erb(:broken_template)

        expect(result).to eq("An error occurred while rendering the page")
      end
    end
  end

  describe "#render_format" do
    let(:json_data) { { actors: [{ id: 1, name: "Actor" }] } }
    let(:locals) { { actors: json_data[:actors] } }

    context "for XHR requests" do
      before { allow(request).to receive(:xhr?).and_return(true) }

      it "returns JSON response" do
        expect(app).to receive(:content_type).with(:json)

        result = JSON.parse(builder.render_format(
                              html_template: :suggestions,
                              json_data: json_data,
                              locals: locals
                            ))

        expect(result["status"]).to eq("success")
        expect(result["data"]).to eq({ "actors" => [{ "id" => 1, "name" => "Actor" }] })
      end
    end

    context "for JSON content type requests" do
      before { allow(request).to receive(:content_type).and_return("application/json") }

      it "returns JSON response" do
        expect(app).to receive(:content_type).with(:json)

        result = JSON.parse(builder.render_format(
                              html_template: :suggestions,
                              json_data: json_data,
                              locals: locals
                            ))

        expect(result["status"]).to eq("success")
      end
    end

    context "for regular HTML requests" do
      it "renders ERB template" do
        expect(app).to receive(:erb).with(:suggestions, locals: locals).and_return("<html>content</html>")

        result = builder.render_format(
          html_template: :suggestions,
          json_data: json_data,
          locals: locals
        )

        expect(result).to eq("<html>content</html>")
      end
    end
  end

  describe "#handle_api_error" do
    it "handles ValidationError" do
      error = ValidationError.new("Field1 is invalid, Field2 is required")

      expect(app).to receive(:status).with(400)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Validation failed")
      expect(result["details"]["errors"]).to eq(["Field1 is invalid", "Field2 is required"])
    end

    it "handles TMDBNotFoundError" do
      error = TMDBNotFoundError.new

      expect(app).to receive(:status).with(404)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Resource not found")
      expect(result["code"]).to eq(404)
    end

    it "handles TMDBAuthError" do
      error = TMDBAuthError.new

      expect(app).to receive(:status).with(401)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Authentication failed")
      expect(result["code"]).to eq(401)
    end

    it "handles TMDBRateLimitError" do
      error = TMDBRateLimitError.new

      expect(app).to receive(:status).with(429)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Rate limit exceeded")
      expect(result["details"]["retry_after"]).to eq(60)
    end

    it "handles TMDBTimeoutError" do
      error = TMDBTimeoutError.new

      expect(app).to receive(:status).with(504)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Request timed out")
      expect(result["details"]["message"]).to eq("Please try again")
    end

    it "handles TMDBServiceError" do
      error = TMDBServiceError.new

      expect(app).to receive(:status).with(503)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Service temporarily unavailable")
      expect(result["details"]["message"]).to eq("Please try again later")
    end

    it "handles generic TMDBError" do
      error = TMDBError.new(500, "Generic TMDB error")

      expect(app).to receive(:status).with(500)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("External service error")
    end

    it "handles CacheError without failing the request" do
      error = CacheConnectionError.new("Redis connection failed")

      expect(StructuredLogger).to receive(:error).with(
        "Cache error",
        hash_including(error: "Redis connection failed", error_class: "CacheConnectionError")
      )

      result = builder.handle_api_error(error)

      expect(result).to be_nil
    end

    it "handles unexpected errors" do
      error = RuntimeError.new("Unexpected error")

      expect(StructuredLogger).to receive(:error).with(
        "Unexpected API error",
        hash_including(error: "Unexpected error", error_class: "RuntimeError")
      )
      expect(app).to receive(:status).with(500)
      expect(app).to receive(:content_type).with(:json)

      result = JSON.parse(builder.handle_api_error(error))

      expect(result["message"]).to eq("Internal server error")
      expect(result["code"]).to eq(500)
    end
  end
end
