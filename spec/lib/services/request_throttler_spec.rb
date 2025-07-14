# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/services/request_throttler"

RSpec.describe RequestThrottler do
  let(:throttler) { described_class.new(max_requests: 3, window_size: 1) }

  describe "#initialize" do
    it "sets default values" do
      default_throttler = described_class.new
      expect(default_throttler.status[:max_requests]).to eq(30)
      expect(default_throttler.status[:window_size]).to eq(10)
    end

    it "accepts custom configuration" do
      custom_throttler = described_class.new(max_requests: 5, window_size: 2)
      expect(custom_throttler.status[:max_requests]).to eq(5)
      expect(custom_throttler.status[:window_size]).to eq(2)
    end
  end

  describe "#throttle" do
    it "executes the block and returns the result" do
      result = throttler.throttle { "success" }
      expect(result).to eq("success")
    end

    it "raises any errors that occur in the block" do
      expect do
        throttler.throttle { raise StandardError, "test error" }
      end.to raise_error(StandardError, "test error")
    end

    it "respects rate limits" do
      # Execute max_requests quickly
      3.times do
        throttler.throttle { "ok" }
      end

      # The 4th request should be delayed
      start_time = Time.now
      throttler.throttle { "delayed" }
      elapsed_time = Time.now - start_time

      # Should have waited approximately until the window expires
      expect(elapsed_time).to be >= 0.9
    end

    it "processes requests with different priorities in order" do
      results = []
      threads = []

      # Fill up the rate limit
      3.times do
        throttler.throttle { sleep 0.1 }
      end

      # Queue requests with different priorities
      threads << Thread.new do
        throttler.throttle_low_priority { results << "low" }
      end

      threads << Thread.new do
        throttler.throttle_high_priority { results << "high" }
      end

      threads << Thread.new do
        throttler.throttle_medium_priority { results << "medium" }
      end

      # Wait for all threads
      threads.each(&:join)

      # High priority should be processed first
      expect(results.first).to eq("high")
    end
  end

  describe "#throttle_high_priority" do
    it "executes with high priority" do
      result = throttler.throttle_high_priority { "high priority result" }
      expect(result).to eq("high priority result")
    end
  end

  describe "#throttle_medium_priority" do
    it "executes with medium priority" do
      result = throttler.throttle_medium_priority { "medium priority result" }
      expect(result).to eq("medium priority result")
    end
  end

  describe "#throttle_low_priority" do
    it "executes with low priority" do
      result = throttler.throttle_low_priority { "low priority result" }
      expect(result).to eq("low priority result")
    end
  end

  describe "#status" do
    it "returns current throttler status" do
      status = throttler.status
      expect(status).to include(
        queue_size: 0,
        recent_requests: 0,
        window_size: 1,
        max_requests: 3,
        current_rate: 0.0
      )
    end

    it "updates status after requests" do
      throttler.throttle { "ok" }
      status = throttler.status
      expect(status[:recent_requests]).to eq(1)
      expect(status[:current_rate]).to eq(1.0)
    end
  end

  describe "thread safety" do
    it "handles concurrent requests safely" do
      results = []
      threads = []
      mutex = Mutex.new

      10.times do |i|
        threads << Thread.new do
          result = throttler.throttle { i }
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)
      expect(results.sort).to eq((0..9).to_a)
    end
  end

  describe "cleanup" do
    it "removes old requests from tracking" do
      # Make a request
      throttler.throttle { "ok" }
      expect(throttler.status[:recent_requests]).to eq(1)

      # Wait for window to expire
      sleep 1.2

      # Make another request to trigger cleanup
      throttler.throttle { "new" }

      # Should have only 1 request (the new one)
      expect(throttler.status[:recent_requests]).to eq(1)
    end
  end
end

RSpec.describe PriorityQueue do
  let(:queue) { described_class.new }

  describe "#push and #pop" do
    it "maintains priority order" do
      request1 = ThrottledRequest.new(2, -> { "low" })
      request2 = ThrottledRequest.new(0, -> { "high" })
      request3 = ThrottledRequest.new(1, -> { "medium" })

      queue.push(request1)
      queue.push(request2)
      queue.push(request3)

      # Should pop in priority order (0, 1, 2)
      expect(queue.pop.priority).to eq(0)
      expect(queue.pop.priority).to eq(1)
      expect(queue.pop.priority).to eq(2)
    end
  end

  describe "#size" do
    it "returns the number of items in queue" do
      expect(queue.size).to eq(0)

      queue.push(ThrottledRequest.new(1, -> { "test" }))
      expect(queue.size).to eq(1)

      queue.pop
      expect(queue.size).to eq(0)
    end
  end

  describe "#empty?" do
    it "returns true when queue is empty" do
      expect(queue.empty?).to be true

      queue.push(ThrottledRequest.new(1, -> { "test" }))
      expect(queue.empty?).to be false

      queue.pop
      expect(queue.empty?).to be true
    end
  end
end

RSpec.describe ThrottledRequest do
  let(:block) { -> { "result" } }
  let(:request) { described_class.new(1, block) }

  describe "#initialize" do
    it "sets priority and block" do
      expect(request.priority).to eq(1)
      expect(request.block).to eq(block)
    end
  end

  describe "#wait_for_completion and #complete!" do
    it "waits until request is completed" do
      completed = false

      thread = Thread.new do
        request.wait_for_completion
        completed = true
      end

      # Should still be waiting
      sleep 0.1
      expect(completed).to be false

      # Complete the request
      request.complete!
      thread.join

      expect(completed).to be true
    end
  end

  describe "result and error handling" do
    it "stores results" do
      request.result = "success"
      expect(request.result).to eq("success")
    end

    it "stores errors" do
      error = StandardError.new("test error")
      request.error = error
      expect(request.error).to eq(error)
    end
  end
end

