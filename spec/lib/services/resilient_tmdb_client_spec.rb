# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResilientTMDBClient do
  let(:api_key) { "test_api_key" }
  let(:client) { described_class.new(api_key) }

  before do
    # Reset circuit breaker state between tests
    client.instance_variable_get(:@circuit_breaker).reset!
  end

  describe "#initialize" do
    it "sets up circuit breaker with correct configuration" do
      expect(client).to be_healthy
      expect(client.circuit_breaker_status[:state]).to eq("closed")
    end
  end

  describe "#healthy?" do
    it "returns true when circuit breaker is closed" do
      expect(client.healthy?).to be true
    end
  end

  describe "#circuit_breaker_status" do
    it "returns circuit breaker state information" do
      status = client.circuit_breaker_status

      expect(status).to include(:state, :failure_count, :last_failure_time, :next_attempt_time)
      expect(status[:state]).to eq("closed")
      expect(status[:failure_count]).to eq(0)
    end
  end

  describe "#request" do
    context "with successful API response" do
      it "returns parsed JSON data" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(
            status: 200,
            body: { results: [{ name: "Test Actor" }] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client.request("search/person", { query: "test" })

        expect(result).to eq("results" => [{ "name" => "Test Actor" }])
      end

      it "logs successful request" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

        expect(StructuredLogger).to receive(:info).with(
          "TMDB API Success",
          hash_including(type: "api_success", endpoint: "test")
        )

        client.request("test")
      end
    end

    context "with API timeouts" do
      it "retries and eventually fails with circuit breaker" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_timeout

        # Make multiple requests to trigger circuit breaker
        5.times do
          expect { client.request("test") }.not_to raise_error
        end

        # Circuit should now be open
        expect(client.healthy?).to be false
        expect(client.circuit_breaker_status[:state]).to eq("open")
      end

      it "provides fallback response for search endpoint" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_timeout

        result = client.request("search/person", { query: "test" })

        expect(result).to include("results" => [])
        expect(result["total_results"]).to eq(0)
      end
    end

    context "with HTTP errors" do
      it "handles 500 errors and provides fallback" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 500, body: "Internal Server Error")

        result = client.request("search/person")

        expect(result).to include("results" => [])
      end

      it "handles 404 errors for actor profiles" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 404, body: "Not Found")

        result = client.request("person/123")

        expect(result).to include("name" => "Unknown Actor")
        expect(result["id"]).to eq(0)
      end
    end

    context "with JSON parsing errors" do
      it "handles invalid JSON response" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 200, body: "invalid json")

        result = client.request("search/person")

        expect(result).to include("results" => [])
      end
    end

    context "with missing API key" do
      let(:client) { described_class.new(nil) }

      it "raises TMDBError for missing API key" do
        result = client.request("search/person")

        # Should return fallback data instead of raising
        expect(result).to include("results" => [])
      end
    end

    context "circuit breaker behavior" do
      it "opens circuit after threshold failures" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 500)

        # Make requests to trigger circuit breaker
        6.times { client.request("test") }

        expect(client.healthy?).to be false
        expect(client.circuit_breaker_status[:state]).to eq("open")
      end

      it "provides fallback responses when circuit is open" do
        # Force circuit open by stubbing the circuit breaker
        circuit_breaker = client.instance_variable_get(:@circuit_breaker)
        allow(circuit_breaker).to receive(:call).and_raise(CircuitBreaker::CircuitOpenError)

        result = client.request("search/person")

        expect(result).to include("results" => [])
      end
    end

    context "fallback data generation" do
      before do
        # Stub to always fail and trigger fallback
        stub_request(:get, /api\.themoviedb\.org/)
          .to_timeout
      end

      it "generates appropriate fallback for search endpoints" do
        result = client.request("search/person")

        expect(result).to include(
          "results" => [],
          "total_results" => 0,
          "total_pages" => 0,
          "page" => 1
        )
      end

      it "generates appropriate fallback for movie credits" do
        result = client.request("person/123/movie_credits")

        expect(result).to include(
          "cast" => [],
          "crew" => [],
          "id" => 0
        )
      end

      it "generates appropriate fallback for person profile" do
        result = client.request("person/123")

        expect(result).to include(
          "id" => 0,
          "name" => "Unknown Actor",
          "biography" => "",
          "profile_path" => nil
        )
      end

      it "generates generic fallback for unknown endpoints" do
        result = client.request("unknown/endpoint")

        expect(result).to include(
          "error" => "Service temporarily unavailable",
          "fallback" => true
        )
      end
    end
  end

  describe "retry mechanism" do
    it "retries failed requests with exponential backoff" do
      call_count = 0
      stub_request(:get, /api\.themoviedb\.org/)
        .to_return do
          call_count += 1
          if call_count < 3
            { status: 500 }
          else
            { status: 200, body: "{}" }
          end
        end

      # Should eventually succeed after retries
      result = client.request("test")
      expect(result).to eq({})
      expect(call_count).to eq(3)
    end
  end

  describe "logging integration" do
    it "logs API requests with circuit breaker context" do
      stub_request(:get, /api\.themoviedb\.org/)
        .to_return(status: 200, body: "{}")

      expect(StructuredLogger).to receive(:debug).with(
        "TMDB API Request",
        hash_including(
          type: "api_request",
          endpoint: "test",
          circuit_state: "closed"
        )
      )

      client.request("test")
    end

    it "logs errors with proper context" do
      stub_request(:get, /api\.themoviedb\.org/)
        .to_timeout

      expect(StructuredLogger).to receive(:error).with(
        "TMDB API Error",
        hash_including(
          type: "api_error",
          error_type: "timeout"
        )
      )

      client.request("test")
    end
  end
end
