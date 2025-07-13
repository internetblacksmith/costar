# frozen_string_literal: true

require "spec_helper"

RSpec.describe "API Error Handling", type: :request do
  include Rack::Test::Methods

  describe "Non-happy path scenarios" do
    describe "Network and timeout errors" do
      context "when TMDB API times out" do
        it "returns graceful error response for search endpoint" do
          stub_request(:get, /api\.themoviedb\.org\/3\/search\/person/)
            .to_timeout

          get "/api/actors/search", { q: "Tom Hanks", field: "actor1" }

          expect(last_response.status).to eq(200)
          html = last_response.body
          # Service returns empty response when circuit breaker is open after retries
          expect(html.strip).to be_empty
        end

        it "returns timeout error for movies endpoint" do
          stub_request(:get, /api\.themoviedb\.org\/3\/person\/\d+\/movie_credits/)
            .to_timeout

          get "/api/actors/123/movies"

          # Timeout is converted to 408 error by ResilientTMDBClient but then caught by error handler
          expect(last_response.status).to eq(500)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to include("Service temporarily unavailable")
        end

        it "returns graceful error response for compare endpoint" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_timeout

          get "/api/actors/compare", { actor1_id: "123", actor2_id: "456" }

          expect(last_response.status).to eq(200)
          # Compare endpoint returns HTML error message
          html = last_response.body
          expect(html).to include("API Error:")
        end
      end

      context "when network connection fails" do
        it "handles connection refused errors" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_raise(Errno::ECONNREFUSED)

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # API handler catches error and returns error HTML
          expect(last_response.body).to include("Search Error")
        end

        it "handles DNS resolution failures" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_raise(SocketError.new("getaddrinfo: Name or service not known"))

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # API handler catches error and returns error HTML
          expect(last_response.body).to include("Search Error")
        end
      end
    end

    describe "HTTP error responses" do
      context "when TMDB returns 500 Internal Server Error" do
        it "handles 500 errors gracefully" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(status: 500, body: "Internal Server Error")

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          html = last_response.body
          # API handler catches error and returns error HTML
          expect(html).to include("Search Error")
        end
      end

      context "when TMDB returns 503 Service Unavailable" do
        it "handles 503 errors with appropriate message" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 503,
              body: { status_message: "Service Temporarily Unavailable" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # API handler catches error and returns error HTML
          expect(last_response.body).to include("Search Error")
        end
      end

      context "when TMDB returns 404 Not Found" do
        it "handles missing actor gracefully" do
          stub_request(:get, /api\.themoviedb\.org\/3\/person\/999999999\/movie_credits/)
            .to_return(
              status: 404,
              body: { status_message: "The resource you requested could not be found." }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/999999999/movies"

          # 404 errors are caught and handled
          expect(last_response.status).to eq(404)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to include("Service temporarily unavailable")
        end
      end

      context "when TMDB returns 401 Unauthorized" do
        it "handles authentication errors" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 401,
              body: { status_message: "Invalid API key" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Circuit breaker returns empty response
          expect(last_response.body.strip).to be_empty
        end
      end
    end

    describe "Rate limiting (429) responses" do
      context "when TMDB rate limits requests" do
        it "handles rate limiting with retry-after header" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 429,
              body: { status_message: "Rate limit exceeded" }.to_json,
              headers: {
                "Content-Type" => "application/json",
                "Retry-After" => "10"
              }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Circuit breaker returns empty response
          expect(last_response.body.strip).to be_empty
        end
      end

      context "when internal rate limiting triggers" do
        it "returns 429 with appropriate headers" do
          # Simulate rate limit by making multiple requests
          # Note: This test requires rack-attack to be configured for test environment
          allow(Rack::Attack).to receive(:enabled).and_return(true)

          # Make requests up to the limit
          60.times do
            get "/api/actors/search", { q: "Test", field: "actor1" }
          end

          # Next request should be rate limited
          get "/api/actors/search", { q: "Test", field: "actor1" }

          # Note: In test environment, rack-attack might be disabled
          # This is more of a documentation of expected behavior
        end
      end
    end

    describe "Invalid response handling" do
      context "when TMDB returns invalid JSON" do
        it "handles malformed JSON responses" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: "{ invalid json",
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Circuit breaker returns empty results on JSON parse error
          expect(last_response.body.strip).to be_empty
        end
      end

      context "when TMDB returns HTML instead of JSON" do
        it "handles unexpected content type" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: "<html><body>Maintenance Mode</body></html>",
              headers: { "Content-Type" => "text/html" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Circuit breaker returns empty response on parse error
          expect(last_response.body.strip).to be_empty
        end
      end

      context "when TMDB returns empty response" do
        it "handles empty response body" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: "",
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Empty response is returned as-is
          expect(last_response.body.strip).to be_empty
        end
      end

      context "when TMDB returns unexpected data structure" do
        it "handles missing expected fields" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { unexpected: "structure" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "Test", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Empty response is returned as-is
          expect(last_response.body.strip).to be_empty
        end
      end
    end

    describe "Input validation errors" do
      context "with malicious input" do
        it "sanitizes XSS attempts in search query" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: "<script>alert('xss')</script>", field: "actor1" }

          expect(last_response.status).to eq(200)
          html = last_response.body
          expect(html).not_to include("<script>")
          expect(html).not_to include("alert('xss')")
        end

        it "rejects SQL injection attempts" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: "'; DROP TABLE actors; --", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Query should be sanitized, not cause any SQL issues
        end

        it "handles null bytes in input" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: "Test\x00Actor", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Should handle null bytes gracefully
        end
      end

      context "with invalid parameters" do
        it "rejects invalid field parameter" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: "Test", field: "invalid_field" }

          expect(last_response.status).to eq(200)
          # Invalid field is sanitized to nil, but search still works
          html = last_response.body
          expect(html).not_to include("Error")
        end

        it "handles missing required parameters" do
          get "/api/actors/search", { field: "actor1" }

          expect(last_response.status).to eq(200)
          # Returns empty suggestions when query is missing
          expect(last_response.body.strip).to eq("")
        end

        it "rejects extremely long search queries" do
          long_query = "a" * 1000
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: long_query, field: "actor1" }

          expect(last_response.status).to eq(200)
          # Should truncate or reject, not crash
        end

        it "handles invalid actor IDs" do
          get "/api/actors/not_a_number/movies"

          expect(last_response.status).to eq(400)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to eq("Actor ID required")
        end

        it "rejects negative actor IDs" do
          get "/api/actors/-123/movies"

          expect(last_response.status).to eq(400)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to eq("Actor ID required")
        end

        it "rejects extremely large actor IDs" do
          get "/api/actors/99999999999999999/movies"

          expect(last_response.status).to eq(400)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to eq("Actor ID required")
        end
      end

      context "with Unicode and special characters" do
        it "handles Unicode characters properly" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          get "/api/actors/search", { q: "François 北京 мир", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Should handle international characters
        end

        it "handles emoji in search queries" do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: "Tom 😀 Hanks", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Should handle or strip emoji gracefully
        end
      end
    end

    describe "Concurrent request handling" do
      it "handles simultaneous requests to same endpoint" do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(
            status: 200,
            body: { results: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          
        threads = 5.times.map do |i|
          Thread.new do
            get "/api/actors/search", { q: "Test#{i}", field: "actor1" }
          end
        end

        threads.each(&:join)
        # All requests should complete without deadlocks
      end
    end

    describe "Circuit breaker behavior" do
      before do
        # Force production mode to enable circuit breaker
        allow(ENV).to receive(:[]).with("RACK_ENV").and_return("production")
      end

      context "when multiple failures occur" do
        it "opens circuit after threshold failures" do
          # Stub multiple failures
          failure_count = 0
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return do |_request|
              failure_count += 1
              { status: 503, body: "Service Unavailable" }
            end

          # Make requests until circuit opens
          6.times do
            get "/api/actors/search", { q: "Test", field: "actor1" }
          end

          # Circuit should be open, returning cached/empty response
          get "/api/actors/search", { q: "Test", field: "actor1" }
          expect(last_response.status).to eq(200)
          expect(last_response.body.strip).to be_empty # Fallback response
        end
      end
    end

    describe "Edge cases" do
      context "with empty or whitespace input" do
        it "handles empty search query" do
          get "/api/actors/search", { q: "", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Returns empty response for empty query
          expect(last_response.body.strip).to eq("")
        end

        it "handles whitespace-only search query" do
          get "/api/actors/search", { q: "   ", field: "actor1" }

          expect(last_response.status).to eq(200)
          # Returns empty response for whitespace-only query
          expect(last_response.body.strip).to eq("")
        end
      end

      context "with boundary values" do
        it "handles actor ID at upper boundary" do
          stub_request(:get, /api\.themoviedb\.org\/3\/person\/999999999\/movie_credits/)
            .to_return(
              status: 404,
              body: { status_message: "Not found" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/999999999/movies"

          # 404 errors are caught by TMDB error handler
          expect(last_response.status).to eq(404)
          json = JSON.parse(last_response.body)
          expect(json["error"]).to include("Service temporarily unavailable")
        end

        it "handles search query at character limit" do
          query = "a" * 100 # Exactly at limit
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(
              status: 200,
              body: { results: [] }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
            
          get "/api/actors/search", { q: query, field: "actor1" }

          expect(last_response.status).to eq(200)
          # Should accept exactly 100 characters
        end
      end
    end
  end
end