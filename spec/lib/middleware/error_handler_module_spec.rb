# frozen_string_literal: true

require "spec_helper"
require "net/http"
require "redis"

RSpec.describe ErrorHandlerModule do
  let(:test_class) do
    Class.new do
      include ErrorHandlerModule
    end
  end

  let(:instance) { test_class.new }

  # Helper to create mock HTTP error with response
  def mock_http_error(code, message)
    response = double("response", code: code.to_s, message: message)
    Net::HTTPError.new("HTTP #{code}: #{message}", response)
  end

  describe "#with_error_handling" do
    context "when a timeout error occurs" do
      it "raises TMDBTimeoutError" do
        expect do
          instance.with_error_handling do
            raise Net::ReadTimeout, "Connection timed out"
          end
        end.to raise_error(TMDBTimeoutError, /Request timed out/)
      end
    end

    context "when an authentication error occurs" do
      it "raises TMDBAuthError" do
        expect do
          instance.with_error_handling do
            raise mock_http_error(401, "Unauthorized")
          end
        end.to raise_error(TMDBAuthError, /Authentication failed/)
      end
    end

    context "when a rate limit error occurs" do
      it "raises TMDBRateLimitError" do
        expect do
          instance.with_error_handling do
            raise mock_http_error(429, "Too Many Requests")
          end
        end.to raise_error(TMDBRateLimitError, /Rate limit exceeded/)
      end
    end

    context "when a not found error occurs" do
      it "raises TMDBNotFoundError" do
        expect do
          instance.with_error_handling do
            raise mock_http_error(404, "Not Found")
          end
        end.to raise_error(TMDBNotFoundError, /Resource not found/)
      end
    end

    context "when a service unavailable error occurs" do
      it "raises TMDBServiceError" do
        expect do
          instance.with_error_handling do
            raise mock_http_error(503, "Service Unavailable")
          end
        end.to raise_error(TMDBServiceError, /Service unavailable/)
      end
    end

    context "when an unexpected error occurs" do
      it "re-raises the original error" do
        expect do
          instance.with_error_handling do
            raise "Unexpected error"
          end
        end.to raise_error(RuntimeError, "Unexpected error")
      end
    end

    context "with context information" do
      it "logs errors with context" do
        expect(StructuredLogger).to receive(:error).with(
          "Network timeout",
          hash_including(error: match(/Connection timed out/), context: { operation: "test" })
        )

        expect do
          instance.with_error_handling(context: { operation: "test" }) do
            raise Net::ReadTimeout, "Connection timed out"
          end
        end.to raise_error(TMDBTimeoutError)
      end
    end
  end

  describe "#with_tmdb_error_handling" do
    it "includes operation name in context" do
      expect(StructuredLogger).to receive(:error).with(
        "Network timeout",
        hash_including(context: hash_including(operation: "search_actors"))
      )

      expect do
        instance.with_tmdb_error_handling("search_actors") do
          raise Net::ReadTimeout, "Timeout"
        end
      end.to raise_error(TMDBTimeoutError)
    end

    it "wraps unexpected errors in TMDBError" do
      expect do
        instance.with_tmdb_error_handling("test_operation") do
          raise "Unexpected error"
        end
      end.to raise_error(TMDBError, /TMDB operation failed/)
    end

    it "allows TMDB errors to bubble up unchanged" do
      expect do
        instance.with_tmdb_error_handling("test_operation") do
          raise TMDBNotFoundError, "Actor not found"
        end
      end.to raise_error(TMDBNotFoundError, "Actor not found")
    end
  end

  describe "#with_cache_error_handling" do
    context "when a Redis error occurs" do
      it "raises CacheConnectionError" do
        expect(StructuredLogger).to receive(:error).with(
          "Redis error",
          hash_including(error: "Connection refused")
        )

        expect do
          instance.with_cache_error_handling do
            raise Redis::CannotConnectError, "Connection refused"
          end
        end.to raise_error(CacheConnectionError, /Cache connection failed/)
      end
    end

    context "when a serialization error occurs" do
      it "raises CacheSerializationError" do
        expect(StructuredLogger).to receive(:error).with(
          "Cache serialization error",
          hash_including(error: "Invalid JSON")
        )

        expect do
          instance.with_cache_error_handling do
            raise JSON::ParserError, "Invalid JSON"
          end
        end.to raise_error(CacheSerializationError, /Failed to serialize cache data/)
      end
    end

    context "when an unexpected error occurs" do
      it "returns nil for graceful degradation" do
        expect(StructuredLogger).to receive(:error).with(
          "Unknown cache error",
          hash_including(error: "Something went wrong")
        )

        result = instance.with_cache_error_handling do
          raise "Something went wrong"
        end

        expect(result).to be_nil
      end
    end

    context "when specific cache errors occur" do
      it "lets them bubble up" do
        expect do
          instance.with_cache_error_handling do
            raise CacheConnectionError, "Specific cache error"
          end
        end.to raise_error(CacheConnectionError, "Specific cache error")
      end
    end
  end
end
