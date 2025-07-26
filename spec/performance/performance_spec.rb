# frozen_string_literal: true

require "spec_helper"
require "benchmark"

RSpec.describe "Performance", type: :request do
  describe "Page Load Times" do
    it "loads the homepage within acceptable time" do
      time = Benchmark.realtime do
        get "/"
      end

      expect(time).to be < 0.5 # 500ms
      expect(last_response.status).to eq(200)
    end

    it "loads timeline comparison within acceptable time" do
      time = Benchmark.realtime do
        get "/api/actors/compare?actor1_id=31&actor2_id=5344"
      end

      expect(time).to be < 1.0 # 1 second
      expect(last_response.status).to eq(200)
    end
  end

  describe "API Response Times" do
    it "responds to actor search quickly" do
      time = Benchmark.realtime do
        get "/api/actors/search?q=Tom&field=actor1"
      end

      expect(time).to be < 0.3 # 300ms
      expect(last_response.status).to eq(200)
    end
  end

  describe "Caching Performance" do
    it "serves cached responses faster than uncached" do
      # First request (uncached)
      uncached_time = Benchmark.realtime do
        get "/api/actors/search?q=TestActor&field=actor1"
      end

      # Second request (should be cached)
      cached_time = Benchmark.realtime do
        get "/api/actors/search?q=TestActor&field=actor1"
      end

      # Cached should be at least 50% faster
      expect(cached_time).to be < (uncached_time * 0.5)
    end
  end

  if defined?(GetProcessMem)
    describe "Memory Usage" do
      it "does not leak memory on repeated requests" do
        initial_memory = GetProcessMem.new.mb

        100.times do
          get "/"
        end

        final_memory = GetProcessMem.new.mb
        memory_increase = final_memory - initial_memory

        # Should not increase by more than 10MB for 100 requests
        expect(memory_increase).to be < 10
      end
    end
  end
end
