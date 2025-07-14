# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/config/cache"
require_relative "../../../lib/services/cache_cleaner"

RSpec.describe CacheCleaner do
  let(:cache) { Cache }
  let(:cleaner) { described_class.new(cache: cache, cleanup_interval: 1) }

  before do
    Cache.clear
  end

  after do
    cleaner.stop
    Cache.clear
  end

  describe "#initialize" do
    it "sets default values" do
      default_cleaner = described_class.new
      expect(default_cleaner.status[:cleanup_interval]).to eq(300)
    end

    it "accepts custom configuration" do
      custom_cleaner = described_class.new(cleanup_interval: 60, batch_size: 50)
      expect(custom_cleaner.status[:cleanup_interval]).to eq(60)
    end
  end

  describe "#start" do
    it "starts the cleanup thread" do
      cleaner.start
      expect(cleaner.status[:running]).to be true
    end

    it "doesn't start multiple threads" do
      cleaner.start
      thread1 = Thread.list.count
      cleaner.start
      thread2 = Thread.list.count
      expect(thread2).to eq(thread1)
    end
  end

  describe "#stop" do
    it "stops the cleanup thread" do
      cleaner.start
      expect(cleaner.status[:running]).to be true

      cleaner.stop
      expect(cleaner.status[:running]).to be false
    end
  end

  describe "#status" do
    it "returns cleaner status" do
      status = cleaner.status
      expect(status).to include(
        :running,
        :last_cleanup,
        :next_cleanup,
        :cleanup_interval
      )
    end
  end

  describe "#cleanup_now" do
    context "with MemoryCache" do
      before do
        # Force MemoryCache for testing
        allow(Cache).to receive(:production?).and_return(false)
        # Clear any existing cache instance
        Cache.instance_variable_set(:@initialize_cache, nil)
      end

      it "removes expired entries" do
        # Add entries with short TTL
        Cache.set("key1", "value1", 0.1)
        Cache.set("key2", "value2", 10)

        # Wait for first key to expire
        sleep 0.2

        result = cleaner.cleanup_now
        expect(result[:removed]).to eq(1)

        # Verify key1 is gone but key2 remains
        expect(Cache.get("key1")).to be_nil
        expect(Cache.get("key2")).to eq("value2")
      end

      it "respects batch size" do
        # Add many expired entries
        10.times do |i|
          Cache.set("expired#{i}", "value", 0.1)
        end

        sleep 0.2

        small_cleaner = described_class.new(cache: Cache, batch_size: 5)
        result = small_cleaner.cleanup_now
        expect(result[:removed]).to eq(5)
      end
    end

    context "with RedisCache" do
      it "returns appropriate message for Redis" do
        # Create a mock Redis cache that responds to cleanup_expired and clear
        redis_cache = instance_double(Cache::RedisCache,
                                      cleanup_expired: { removed: 0, message: "Redis handles TTL cleanup automatically" },
                                      clear: true)
        allow(Cache).to receive(:initialize_cache).and_return(redis_cache)

        result = cleaner.cleanup_now
        expect(result[:message]).to include("Redis handles TTL cleanup automatically")
        expect(result[:removed]).to eq(0)
      end
    end
  end

  describe "automatic cleanup" do
    it "performs cleanup at intervals" do
      # Force MemoryCache
      allow(Cache).to receive(:production?).and_return(false)
      Cache.instance_variable_set(:@initialize_cache, nil)

      # Add expired entry
      Cache.set("expired", "value", 0.1)
      sleep 0.2

      # Start cleaner with short interval
      cleaner.start

      # Wait for cleanup to run
      sleep 1.5

      # Entry should be cleaned up
      expect(Cache.get("expired")).to be_nil
    end
  end
end

RSpec.describe Cache::MemoryCache do
  let(:cache) { described_class.new }

  describe "#cleanup_expired" do
    it "removes expired entries" do
      # Add entries with different TTLs
      cache.set("valid", "value1", 10)
      cache.set("expired1", "value2", 0.1)
      cache.set("expired2", "value3", 0.1)

      sleep 0.2

      result = cache.cleanup_expired
      expect(result[:removed]).to eq(2)

      # Verify only valid entry remains
      expect(cache.get("valid")).to eq("value1")
      expect(cache.get("expired1")).to be_nil
      expect(cache.get("expired2")).to be_nil
    end

    it "respects batch size limit" do
      # Add many expired entries
      20.times do |i|
        cache.set("key#{i}", "value", 0.1)
      end

      sleep 0.2

      result = cache.cleanup_expired(10)
      expect(result[:removed]).to eq(10)
      expect(cache.size).to eq(10)
    end
  end

  describe "#expired_count" do
    it "counts expired entries without removing them" do
      cache.set("valid", "value", 10)
      cache.set("expired1", "value", 0.1)
      cache.set("expired2", "value", 0.1)

      sleep 0.2

      expect(cache.expired_count).to eq(2)
      expect(cache.size).to eq(3) # All entries still present
    end
  end
end

RSpec.describe Cache::RedisCache do
  # Skip Redis tests if Redis is not available
  before do
    skip "Redis not available" unless ENV["REDIS_URL"]
  end

  let(:cache) { described_class.new }

  describe "#cleanup_expired" do
    it "returns message about Redis auto-cleanup" do
      result = cache.cleanup_expired
      expect(result[:message]).to include("Redis handles TTL cleanup automatically")
      expect(result[:removed]).to eq(0)
    end
  end

  describe "#expired_count" do
    it "returns 0 as Redis doesn't expose expired keys" do
      expect(cache.expired_count).to eq(0)
    end
  end
end
