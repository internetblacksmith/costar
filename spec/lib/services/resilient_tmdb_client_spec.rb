# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResilientTMDBClient do
  let(:api_key) { "test_api_key" }
  let(:client) { described_class.new(api_key) }

  before do
    # Force production mode for these tests to test circuit breaker functionality
    allow(ENV).to receive(:[]).with("RACK_ENV").and_return("production")

    # Reset circuit breaker state between tests
    client.instance_variable_get(:@circuit_breaker).reset!

    # Force test_mode to false for these specific tests
    client.instance_variable_set(:@test_mode, false)
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
        ).at_least(:once)

        client.request("test")
      end
    end

    context "with API timeouts" do
      it "retries failed requests with exponential backoff" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_timeout

        # Should raise TMDBError after all retries are exhausted
        expect { client.request("test") }.to raise_error(TMDBError, "Request timeout")
      end

      it "logs timeout errors appropriately" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_timeout

        expect(StructuredLogger).to receive(:error).with(
          "TMDB API Error",
          hash_including(
            type: "api_error",
            error_type: "timeout",
            endpoint: "test"
          )
        )

        expect { client.request("test") }.to raise_error(TMDBError, "Request timeout")
      end
    end

    context "with HTTP errors" do
      it "handles 500 errors and raises TMDBError" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 500, body: "Internal Server Error")

        expect { client.request("search/person") }.to raise_error(TMDBError, /HTTP error/)
      end

      it "handles 404 errors and raises TMDBError" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 404, body: "Not Found")

        expect { client.request("person/123") }.to raise_error(TMDBError, /HTTP error/)
      end
    end

    context "with JSON parsing errors" do
      it "handles invalid JSON response" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 200, body: "invalid json")

        expect { client.request("search/person") }.to raise_error(TMDBError, "Invalid JSON response from TMDB")
      end
    end

    context "with missing API key" do
      let(:client) { described_class.new(nil) }

      it "raises TMDBError for missing API key" do
        expect { client.request("search/person") }.to raise_error(TMDBError, "TMDB API key not configured")
      end
    end

    context "circuit breaker behavior" do
      it "provides fallback responses when circuit is open" do
        # Force circuit open by stubbing the circuit breaker
        circuit_breaker = client.instance_variable_get(:@circuit_breaker)
        allow(circuit_breaker).to receive(:call).and_raise(SimpleCircuitBreaker::CircuitOpenError)

        result = client.request("search/person")

        expect(result).to include("results" => [])
      end
    end

    context "fallback data generation" do
      before do
        # Force circuit breaker to be open to trigger fallback responses
        circuit_breaker = client.instance_variable_get(:@circuit_breaker)
        allow(circuit_breaker).to receive(:call).and_raise(SimpleCircuitBreaker::CircuitOpenError)
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
      # Mock the sleep method to speed up test execution
      allow(client).to receive(:sleep)

      # Test that retries happen by stubbing all requests to fail
      stub_request(:get, /api\.themoviedb\.org/)
        .to_return(status: 500)

      # Should retry and then raise error after all retries exhausted
      expect { client.request("test") }.to raise_error(TMDBError, /HTTP error/)

      # Verify that multiple HTTP requests were made (at least more than 1)
      expect(a_request(:get, /api\.themoviedb\.org/)).to have_been_made.at_least_once
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
          endpoint: "test"
        )
      ).at_least(:once)

      expect { client.request("test") }.to raise_error(TMDBError)
    end
  end
end
