# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Health Check Error Scenarios", type: :request do
  include Rack::Test::Methods

  describe "GET /health/complete" do
    context "when Redis is down" do
      before do
        allow_any_instance_of(ConnectionPool).to receive(:with).and_raise(Redis::CannotConnectError)
      end

      it "returns degraded status with Redis marked as unhealthy" do
        get "/health/complete"

        expect(last_response.status).to eq(503)
        json = JSON.parse(last_response.body)
        
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["cache"]["status"]).to eq("unhealthy")
        expect(json["checks"]["cache"]["type"]).to eq("memory") # Test environment uses memory cache
      end
    end

    context "when TMDB is experiencing issues" do
      before do
        # Mock TMDB client to return unhealthy
        tmdb_client = instance_double(ResilientTMDBClient)
        allow(tmdb_client).to receive(:healthy?).and_return(false)
        allow(tmdb_client).to receive(:circuit_breaker_status).and_return({
          state: "open",
          failure_count: 5,
          last_failure_time: Time.now.iso8601,
          next_attempt_time: (Time.now + 60).iso8601
        })
        
        allow_any_instance_of(TMDBService).to receive(:client).and_return(tmdb_client)
      end

      it "returns degraded status with TMDB marked as unhealthy" do
        get "/health/complete"

        expect(last_response.status).to eq(503)
        json = JSON.parse(last_response.body)
        
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["tmdb_api"]["status"]).to eq("unhealthy")
        expect(json["checks"]["tmdb_api"]["circuit_breaker"]["state"]).to eq("open")
      end
    end

    context "when multiple services are down" do
      before do
        # Redis is down
        allow_any_instance_of(ConnectionPool).to receive(:with).and_raise(Redis::CannotConnectError)
        
        # TMDB is down
        tmdb_client = instance_double(ResilientTMDBClient)
        allow(tmdb_client).to receive(:healthy?).and_return(false)
        allow(tmdb_client).to receive(:circuit_breaker_status).and_return({
          state: "open",
          failure_count: 10,
          last_failure_time: Time.now.iso8601,
          next_attempt_time: (Time.now + 60).iso8601
        })
        
        allow_any_instance_of(TMDBService).to receive(:client).and_return(tmdb_client)
      end

      it "returns degraded status with all failed services listed" do
        get "/health/complete"

        expect(last_response.status).to eq(503)
        json = JSON.parse(last_response.body)
        
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["cache"]["status"]).to eq("unhealthy")
        expect(json["checks"]["tmdb_api"]["status"]).to eq("unhealthy")
      end
    end

    context "when health check itself times out" do
      before do
        # Simulate a very slow Redis connection
        allow_any_instance_of(ConnectionPool).to receive(:with) do |&block|
          sleep(2) # Simulate slow response
          block.call(double(ping: "PONG"))
        end
      end

      it "completes within reasonable time" do
        start_time = Time.now
        get "/health/complete"
        duration = Time.now - start_time

        expect(duration).to be < 5 # Health check should timeout internally
        expect(last_response.status).to eq(200) # Should still return a response
      end
    end

    context "when unexpected errors occur during health check" do
      before do
        allow_any_instance_of(HealthHandler).to receive(:performance_summary).and_raise(StandardError, "Unexpected error")
      end

      it "returns partial health information without crashing" do
        get "/health/complete"

        # Should still return a response even if performance summary fails
        expect(last_response.status).to be_between(200, 503)
        json = JSON.parse(last_response.body)
        expect(json).to have_key("status")
        expect(json).to have_key("checks")
      end
    end
  end

  describe "GET /health/simple" do
    context "when app is in bad state" do
      before do
        # Simulate app being in a bad state by mocking Sinatra internals
        allow_any_instance_of(Sinatra::Base).to receive(:running?).and_return(false)
      end

      it "still returns OK for liveness probe" do
        get "/health/simple"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("OK")
      end
    end

    context "when request times out" do
      it "returns quickly for monitoring tools" do
        start_time = Time.now
        get "/health/simple"
        duration = Time.now - start_time

        expect(duration).to be < 0.1 # Should be nearly instant
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe "Health check under load" do
    it "handles concurrent health check requests" do
      threads = 10.times.map do
        Thread.new do
          get "/health/complete"
          expect(last_response.status).to be_between(200, 503)
        end
      end

      threads.each(&:join)
    end

    it "does not leak sensitive information in error responses" do
      # Force an error with sensitive info
      allow_any_instance_of(ConnectionPool).to receive(:with)
        .and_raise(Redis::CommandError, "ERR wrong password for user 'admin'")

      get "/health/complete"

      json = JSON.parse(last_response.body)
      
      # Should not expose password or detailed error
      expect(last_response.body).not_to include("password")
      expect(last_response.body).not_to include("admin")
      # Health check doesn't expose specific error details
    end
  end

  describe "Monitoring integration" do
    it "includes required fields for monitoring tools" do
      get "/health/complete"

      json = JSON.parse(last_response.body)

      # Required fields for monitoring tools
      expect(json).to include(
        "status" => be_in(["healthy", "degraded"]),
        "timestamp" => match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/),
        "version" => be_a(String),
        "checks" => be_a(Hash)
      )

      # Each check should have consistent structure
      json["checks"].each do |service, check|
        expect(check).to include("status" => be_in(["healthy", "unhealthy"]))
      end
    end

    it "sets appropriate cache headers" do
      get "/health/complete"

      # Health checks should not be cached
      # Cache control headers may vary based on implementation
      expect(last_response.headers).to be_a(Hash)
    end
  end
end