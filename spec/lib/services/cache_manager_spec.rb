# frozen_string_literal: true

require "spec_helper"

RSpec.describe CacheManager do
  subject(:cache_manager) { described_class.new }

  before do
    # Clear cache before each test

    Cache.clear
  rescue StandardError
    nil
  end

  describe "#initialize" do
    it "creates a key builder instance" do
      expect(cache_manager.key_builder).to be_a(CacheKeyBuilder)
    end
  end

  describe "#fetch" do
    let(:cache_key) { "test_key" }
    let(:cache_value) { "test_value" }

    context "when cache miss" do
      it "executes block and caches result" do
        result = cache_manager.fetch(cache_key, ttl: 300) { cache_value }

        expect(result).to eq(cache_value)
        expect(Cache.get(cache_key)).to eq(cache_value)
      end

      it "uses TTL policy when provided" do
        allow(Cache).to receive(:set).and_call_original

        cache_manager.fetch(cache_key, policy: :actor_profile) { cache_value }

        expect(Cache).to have_received(:set).with(cache_key, cache_value, 1800)
      end
    end

    context "when cache hit" do
      before do
        Cache.set(cache_key, cache_value, 300)
      end

      it "returns cached value without executing block" do
        block_executed = false
        result = cache_manager.fetch(cache_key) do
          block_executed = true
          "new_value"
        end

        expect(result).to eq(cache_value)
        expect(block_executed).to be false
      end
    end

    context "when cache fails" do
      before do
        allow(Cache).to receive(:get).and_raise(StandardError.new("Cache error"))
        allow(StructuredLogger).to receive(:error)
      end

      it "executes block directly and logs error" do
        result = cache_manager.fetch(cache_key) { cache_value }

        expect(result).to eq(cache_value)
        expect(StructuredLogger).to have_received(:error).with(
          "Cache operation failed",
          hash_including(type: "cache_error", key: cache_key)
        )
      end

      it "returns nil when no block given" do
        result = cache_manager.fetch(cache_key)
        expect(result).to be_nil
      end
    end
  end

  describe "#fetch_multi" do
    let(:keys) { %w[key1 key2 key3] }
    let(:values) { { "key1" => "value1", "key2" => "value2", "key3" => "value3" } }

    context "when all keys are cache misses" do
      it "fetches all missing keys and caches them" do
        result = cache_manager.fetch_multi(keys) do |missing_keys|
          expect(missing_keys).to eq(keys)
          values
        end

        expect(result).to eq(values)

        # Verify all values were cached
        keys.each do |key|
          expect(Cache.get(key)).to eq(values[key])
        end
      end
    end

    context "when some keys are cached" do
      before do
        Cache.set("key1", "cached_value1", 300)
        Cache.set("key2", "cached_value2", 300)
      end

      it "only fetches missing keys" do
        result = cache_manager.fetch_multi(keys) do |missing_keys|
          expect(missing_keys).to eq(["key3"])
          { "key3" => "new_value3" }
        end

        expect(result).to eq({
                               "key1" => "cached_value1",
                               "key2" => "cached_value2",
                               "key3" => "new_value3"
                             })
      end
    end

    context "when cache fails" do
      before do
        allow(cache_manager).to receive(:get_multi).and_raise(StandardError.new("Cache error"))
        allow(StructuredLogger).to receive(:error)
      end

      it "executes block with all keys and logs error" do
        result = cache_manager.fetch_multi(keys) { |_all_keys| values }

        expect(result).to eq(values)
        expect(StructuredLogger).to have_received(:error).with(
          "Cache multi-fetch failed",
          hash_including(type: "cache_error", keys: keys)
        )
      end
    end
  end

  describe "#set" do
    let(:key) { "test_key" }
    let(:value) { "test_value" }

    it "sets value with specified TTL" do
      cache_manager.set(key, value, ttl: 600)
      expect(Cache.get(key)).to eq(value)
    end

    it "uses policy TTL when provided" do
      allow(Cache).to receive(:set).and_call_original

      cache_manager.set(key, value, policy: :actor_profile)

      expect(Cache).to have_received(:set).with(key, value, 1800)
    end
  end

  describe "#get and #get_multi" do
    before do
      Cache.set("key1", "value1", 300)
      Cache.set("key2", "value2", 300)
    end

    it "gets single value" do
      expect(cache_manager.get("key1")).to eq("value1")
    end

    it "returns nil for missing key" do
      expect(cache_manager.get("missing")).to be_nil
    end

    it "gets multiple values" do
      result = cache_manager.get_multi(%w[key1 key2 missing])
      expect(result).to eq({ "key1" => "value1", "key2" => "value2" })
    end
  end

  describe "#delete" do
    before do
      Cache.set("test_key", "test_value", 300)
    end

    it "deletes key from cache" do
      cache_manager.delete("test_key")
      expect(Cache.get("test_key")).to be_nil
    end
  end

  describe "#healthy?" do
    it "returns true when cache is working" do
      expect(cache_manager.healthy?).to be true
    end

    it "returns false when cache fails" do
      allow(Cache).to receive(:set).and_raise(StandardError.new("Cache error"))
      expect(cache_manager.healthy?).to be false
    end
  end

  describe "convenience methods" do
    let(:actor_id) { 12_345 }
    let(:actor_data) { { name: "Test Actor" } }

    describe "#cache_actor_profile" do
      it "caches actor profile with correct key and TTL" do
        result = cache_manager.cache_actor_profile(actor_id) { actor_data }

        expect(result).to eq(actor_data)

        expected_key = cache_manager.key_builder.actor_profile(actor_id)
        expect(Cache.get(expected_key)).to eq(actor_data)
      end
    end

    describe "#cache_actor_movies" do
      let(:movies) { [{ title: "Test Movie" }] }

      it "caches actor movies with correct key and TTL" do
        result = cache_manager.cache_actor_movies(actor_id) { movies }

        expect(result).to eq(movies)

        expected_key = cache_manager.key_builder.actor_movies(actor_id)
        expect(Cache.get(expected_key)).to eq(movies)
      end
    end

    describe "#cache_search_results" do
      let(:query) { "test query" }
      let(:results) { [{ name: "Test Result" }] }

      it "caches search results with correct key and TTL" do
        result = cache_manager.cache_search_results(query) { results }

        expect(result).to eq(results)

        expected_key = cache_manager.key_builder.search_results(query)
        expect(Cache.get(expected_key)).to eq(results)
      end
    end

    describe "#cache_actor_comparison" do
      let(:actor2_id) { 67_890 }
      let(:comparison) { { shared_movies: [] } }

      it "caches comparison with correct key and TTL" do
        result = cache_manager.cache_actor_comparison(actor_id, actor2_id) { comparison }

        expect(result).to eq(comparison)

        expected_key = cache_manager.key_builder.actor_comparison(actor_id, actor2_id)
        expect(Cache.get(expected_key)).to eq(comparison)
      end
    end
  end

  describe "batch operations" do
    let(:actor_ids) { [123, 456, 789] }

    describe "#batch_actor_profiles" do
      it "batches actor profile requests" do
        profiles = {
          cache_manager.key_builder.actor_profile(123) => { name: "Actor 1" },
          cache_manager.key_builder.actor_profile(456) => { name: "Actor 2" },
          cache_manager.key_builder.actor_profile(789) => { name: "Actor 3" }
        }

        result = cache_manager.batch_actor_profiles(actor_ids) do |missing_ids|
          expect(missing_ids).to eq(actor_ids)
          profiles
        end

        expect(result.values).to include({ name: "Actor 1" }, { name: "Actor 2" }, { name: "Actor 3" })
      end
    end

    describe "#batch_actor_names" do
      it "batches actor name requests" do
        names = {
          cache_manager.key_builder.actor_name(123) => "Actor 1",
          cache_manager.key_builder.actor_name(456) => "Actor 2",
          cache_manager.key_builder.actor_name(789) => "Actor 3"
        }

        result = cache_manager.batch_actor_names(actor_ids) do |missing_ids|
          expect(missing_ids).to eq(actor_ids)
          names
        end

        expect(result.values).to include("Actor 1", "Actor 2", "Actor 3")
      end
    end
  end

  describe "TTL policies" do
    it "defines appropriate TTL values" do
      expect(CacheManager::TTL_POLICIES[:actor_profile]).to eq(1800) # 30 minutes
      expect(CacheManager::TTL_POLICIES[:actor_movies]).to eq(600)    # 10 minutes
      expect(CacheManager::TTL_POLICIES[:search_results]).to eq(300)  # 5 minutes
      expect(CacheManager::TTL_POLICIES[:actor_comparison]).to eq(900) # 15 minutes
      expect(CacheManager::TTL_POLICIES[:actor_name]).to eq(1800)     # 30 minutes
      expect(CacheManager::TTL_POLICIES[:health_check]).to eq(60)     # 1 minute
      expect(CacheManager::TTL_POLICIES[:movie_details]).to eq(3600)  # 1 hour
    end
  end
end
