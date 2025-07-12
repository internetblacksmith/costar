# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cache do
  before do
    Cache.clear
  end

  describe ".get and .set" do
    it "stores and retrieves values" do
      Cache.set("test_key", "test_value")
      expect(Cache.get("test_key")).to eq("test_value")
    end

    it "returns nil for non-existent keys" do
      expect(Cache.get("non_existent")).to be_nil
    end

    it "respects TTL expiration" do
      Cache.set("test_key", "test_value", 0.1) # 0.1 second TTL
      expect(Cache.get("test_key")).to eq("test_value")

      sleep(0.2)
      expect(Cache.get("test_key")).to be_nil
    end

    it "overwrites existing values" do
      Cache.set("test_key", "original_value")
      Cache.set("test_key", "new_value")
      expect(Cache.get("test_key")).to eq("new_value")
    end
  end

  describe ".clear" do
    it "removes all cached values" do
      Cache.set("key1", "value1")
      Cache.set("key2", "value2")

      Cache.clear

      expect(Cache.get("key1")).to be_nil
      expect(Cache.get("key2")).to be_nil
    end
  end

  describe ".size" do
    it "returns the number of cached items" do
      expect(Cache.size).to eq(0)

      Cache.set("key1", "value1")
      expect(Cache.size).to eq(1)

      Cache.set("key2", "value2")
      expect(Cache.size).to eq(2)

      Cache.clear
      expect(Cache.size).to eq(0)
    end
  end

  describe ".healthy?" do
    it "returns true when cache is working" do
      expect(Cache.healthy?).to be true
    end
  end

  describe "memory cache behavior" do
    before do
      # Ensure we're testing the memory cache implementation
      allow(ENV).to receive(:fetch).with("RACK_ENV", "development").and_return("test")
    end

    it "uses memory cache in test environment" do
      # Memory cache should be thread-safe
      threads = []
      results = {}

      5.times do |i|
        threads << Thread.new do
          Cache.set("thread_key_#{i}", "thread_value_#{i}")
          results[i] = Cache.get("thread_key_#{i}")
        end
      end

      threads.each(&:join)

      5.times do |i|
        expect(results[i]).to eq("thread_value_#{i}")
      end
    end
  end

  describe "complex data types" do
    it "handles hashes" do
      data = { "name" => "John", "age" => 30, "skills" => %w[Ruby JavaScript] }
      Cache.set("user_data", data)
      expect(Cache.get("user_data")).to eq(data)
    end

    it "handles arrays" do
      data = [1, 2, 3, "test", { nested: true }]
      Cache.set("array_data", data)
      expect(Cache.get("array_data")).to eq(data)
    end

    it "handles nil values" do
      Cache.set("nil_value", nil)
      expect(Cache.get("nil_value")).to be_nil
    end
  end
end
