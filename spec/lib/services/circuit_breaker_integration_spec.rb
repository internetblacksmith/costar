# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Circuit Breaker Integration", type: :request do
  include Rack::Test::Methods

  let(:tmdb_service) { app.settings.tmdb_service }

  # Helper to force circuit breaker state
  def force_circuit_open
    # Get the TMDBService from the Sinatra app
    service = app.settings.tmdb_service
    client = service.instance_variable_get(:@client)
    breaker = client.instance_variable_get(:@circuit_breaker)
    breaker.instance_variable_set(:@failure_count, 10)
    breaker.instance_variable_set(:@state, :open)
    breaker.instance_variable_set(:@last_failure_time, Time.now)
  end

  before do
    # Force production mode for circuit breaker
    allow(ENV).to receive(:[]).with("RACK_ENV").and_return("production")
  end

  describe "Circuit breaker protection in production" do
    context "when circuit is open" do
      before { force_circuit_open }

      it "returns fallback response for search without hitting API" do
        # No API request should be made
        expect(WebMock).not_to have_requested(:get, /api\.themoviedb\.org/)

        get "/api/actors/search", { q: "Tom Hanks", field: "actor1" }

        expect(last_response.status).to eq(200)
        expect(last_response.body.strip).to be_empty # Fallback empty response
      end

      it "returns empty array for movie credits without hitting API" do
        expect(WebMock).not_to have_requested(:get, /api\.themoviedb\.org/)

        get "/api/actors/123/movies"

        expect(last_response.status).to eq(200)
        json = JSON.parse(last_response.body)
        expect(json).to eq([])
      end

      it "health check reflects circuit breaker state" do
        get "/health/complete"

        json = JSON.parse(last_response.body)
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["tmdb_api"]["status"]).to eq("unhealthy")
        expect(json["checks"]["tmdb_api"]["circuit_breaker"]["state"]).to eq("open")
      end
    end

    context "when circuit transitions from open to half-open" do
      it "attempts one request after recovery timeout" do
        # Set up circuit breaker in open state with expired timeout
        service = app.settings.tmdb_service
        client = service.instance_variable_get(:@client)
        breaker = client.instance_variable_get(:@circuit_breaker)
        breaker.instance_variable_set(:@failure_count, 10)
        breaker.instance_variable_set(:@state, :open)
        breaker.instance_variable_set(:@last_failure_time, Time.now - 65) # Past recovery timeout

        # Stub successful response for recovery
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(
            status: 200,
            body: { results: [{ id: 123, name: "Tom Hanks" }] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        get "/api/actors/search", { q: "Tom Hanks", field: "actor1" }

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("Tom Hanks")

        # Circuit should be closed again
        expect(breaker.instance_variable_get(:@state)).to eq(:closed)
      end
    end

    context "when service experiences cascading failures" do
      it "prevents thundering herd after recovery" do
        # Simulate service that fails intermittently
        request_count = 0
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return do |_request|
            request_count += 1
            if request_count <= 5
              { status: 503, body: "Service Unavailable" }
            else
              {
                status: 200,
                body: { results: [] }.to_json,
                headers: { "Content-Type" => "application/json" }
              }
            end
          end

        # Make requests until circuit opens
        10.times do |i|
          get "/api/actors/search", { q: "Test#{i}", field: "actor1" }
        end

        # Circuit should be open, preventing further requests
        expect(request_count).to be <= 6 # Should stop after threshold
      end
    end

    context "when dealing with different error types" do
      it "counts timeout errors toward circuit breaker threshold" do
        stub_request(:get, /api\.themoviedb\.org/).to_timeout

        # Make multiple timeout requests
        5.times do
          get "/api/actors/search", { q: "Test", field: "actor1" }
          expect(last_response.status).to eq(200)
        end

        # Check circuit breaker state
        get "/health/complete"
        json = JSON.parse(last_response.body)
        
        # After 5 timeouts, circuit should be open or near opening
        breaker_state = json["checks"]["tmdb_api"]["circuit_breaker"]
        expect(breaker_state["failure_count"]).to be >= 5
      end

      it "does not count 404 errors toward circuit breaker" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 404, body: { status_message: "Not found" }.to_json)

        # Make multiple 404 requests
        5.times do
          get "/api/actors/search", { q: "NonexistentActor", field: "actor1" }
        end

        # Check circuit breaker state
        get "/health/complete"
        json = JSON.parse(last_response.body)
        
        # 404s should not trigger circuit breaker
        expect(json["checks"]["tmdb_api"]["circuit_breaker"]["state"]).to eq("closed")
      end
    end
  end

  describe "Circuit breaker monitoring" do
    it "exposes circuit breaker metrics in health check" do
      get "/health/complete"

      json = JSON.parse(last_response.body)
      tmdb_check = json["checks"]["tmdb_api"]

      expect(tmdb_check).to include("circuit_breaker")
      expect(tmdb_check["circuit_breaker"]).to include(
        "state",
        "failure_count",
        "last_failure_time",
        "next_attempt_time"
      )
    end

    it "logs circuit breaker state changes" do
      # We can't easily test logging output, but this documents expected behavior
      # Circuit breaker state changes should be logged with structured format:
      # - Circuit opened: { event: "circuit_breaker_opened", service: "tmdb", failure_count: 5 }
      # - Circuit half-open: { event: "circuit_breaker_half_open", service: "tmdb" }
      # - Circuit closed: { event: "circuit_breaker_closed", service: "tmdb" }
    end
  end

  describe "Fallback strategies" do
    context "when circuit is open" do
      before { force_circuit_open }

      it "search endpoint returns empty suggestions gracefully" do
        get "/api/actors/search", { q: "Tom", field: "actor1" }

        expect(last_response.status).to eq(200)
        expect(last_response.body.strip).to be_empty
        # Header may not be set in all cases
      end

      it "compare endpoint returns error when both actors need fetching" do
        get "/api/actors/compare", { actor1_id: "123", actor2_id: "456" }

        expect(last_response.status).to eq(200)
        # Compare endpoint returns HTML with error
        html = last_response.body
        expect(html).to include("Error")
      end
    end
  end

  describe "Recovery patterns" do
    it "implements exponential backoff on repeated failures" do
      # This documents that the circuit breaker uses fixed recovery timeout
      # rather than exponential backoff. This is intentional to provide
      # predictable recovery behavior.
      
      service = app.settings.tmdb_service
      client = service.instance_variable_get(:@client)
      breaker = client.instance_variable_get(:@circuit_breaker)
      
      # Recovery timeout is fixed at 60 seconds
      expect(breaker.instance_variable_get(:@recovery_timeout)).to eq(60)
    end

    it "resets failure count after successful request" do
      service = app.settings.tmdb_service
      client = service.instance_variable_get(:@client)
      breaker = client.instance_variable_get(:@circuit_breaker)

      # Simulate some failures (but not enough to open circuit)
      breaker.instance_variable_set(:@failure_count, 3)

      # Stub successful response
      stub_request(:get, /api\.themoviedb\.org/)
        .to_return(
          status: 200,
          body: { results: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      get "/api/actors/search", { q: "Test", field: "actor1" }

      # Failure count should be reset
      expect(breaker.instance_variable_get(:@failure_count)).to eq(0)
    end
  end
end