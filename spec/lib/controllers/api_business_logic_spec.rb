# frozen_string_literal: true

require "spec_helper"

RSpec.describe ApiBusinessLogic do
  let(:tmdb_service) { double("TMDBService") }
  let(:comparison_service) { double("ActorComparisonService") }
  subject(:business_logic) { described_class.new(tmdb_service, comparison_service) }

  describe "#search_actors" do
    let(:query) { "Leonardo DiCaprio" }
    let(:actor_data) do
      [
        {
          id: 6193,
          name: "Leonardo DiCaprio",
          popularity: 45.8,
          profile_path: "/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg"
        }
      ]
    end

    context "when service call succeeds" do
      before do
        allow(tmdb_service).to receive(:search_actors).with(query).and_return(actor_data)
      end

      it "returns actor search results" do
        result = business_logic.search_actors(query)
        expect(result).to eq(actor_data)
      end

      it "calls tmdb_service with correct query" do
        business_logic.search_actors(query)
        expect(tmdb_service).to have_received(:search_actors).with(query)
      end
    end

    context "when TMDB error occurs" do
      let(:tmdb_error) { TMDBError.new(500, "API Error") }

      before do
        allow(tmdb_service).to receive(:search_actors).and_raise(tmdb_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and re-raises" do
        expect { business_logic.search_actors(query) }.to raise_error(TMDBError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Actor search failed",
          hash_including(
            type: "business_logic_error",
            operation: "search_actors",
            query: query,
            error: "API Error"
          )
        )
      end
    end

    context "when unexpected error occurs" do
      let(:unexpected_error) { StandardError.new("Unexpected error") }

      before do
        allow(tmdb_service).to receive(:search_actors).and_raise(unexpected_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and re-raises" do
        expect { business_logic.search_actors(query) }.to raise_error(StandardError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Unexpected error in actor search",
          hash_including(
            type: "business_logic_error",
            operation: "search_actors",
            query: query,
            error: "Unexpected error",
            error_class: "StandardError"
          )
        )
      end
    end
  end

  describe "#fetch_actor_movies" do
    let(:actor_id) { 6193 }
    let(:movies_data) do
      [
        {
          id: 27_205,
          title: "Inception",
          character: "Dom Cobb",
          release_date: "2010-07-16"
        }
      ]
    end

    context "when service call succeeds" do
      before do
        allow(tmdb_service).to receive(:get_actor_movies).with(actor_id).and_return(movies_data)
      end

      it "returns actor movies" do
        result = business_logic.fetch_actor_movies(actor_id)
        expect(result).to eq(movies_data)
      end

      it "calls tmdb_service with correct actor_id" do
        business_logic.fetch_actor_movies(actor_id)
        expect(tmdb_service).to have_received(:get_actor_movies).with(actor_id)
      end
    end

    context "when TMDB error occurs" do
      let(:tmdb_error) { TMDBError.new(404, "Actor not found") }

      before do
        allow(tmdb_service).to receive(:get_actor_movies).and_raise(tmdb_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and re-raises" do
        expect { business_logic.fetch_actor_movies(actor_id) }.to raise_error(TMDBError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Actor movies fetch failed",
          hash_including(
            type: "business_logic_error",
            operation: "fetch_actor_movies",
            actor_id: actor_id,
            error: "Actor not found"
          )
        )
      end
    end
  end

  describe "#compare_actors" do
    let(:actor1_id) { 6193 }
    let(:actor2_id) { 31 }
    let(:actor1_name) { "Leonardo DiCaprio" }
    let(:actor2_name) { "Tom Hanks" }
    let(:comparison_data) do
      {
        actor1_movies: [],
        actor2_movies: [],
        shared_movies: [],
        actor1_name: actor1_name,
        actor2_name: actor2_name
      }
    end

    context "when service call succeeds" do
      before do
        allow(comparison_service).to receive(:compare)
          .with(actor1_id, actor2_id, actor1_name, actor2_name)
          .and_return(comparison_data)
      end

      it "returns comparison data" do
        result = business_logic.compare_actors(actor1_id, actor2_id, actor1_name, actor2_name)
        expect(result).to eq(comparison_data)
      end

      it "calls comparison_service with correct parameters" do
        business_logic.compare_actors(actor1_id, actor2_id, actor1_name, actor2_name)
        expect(comparison_service).to have_received(:compare)
          .with(actor1_id, actor2_id, actor1_name, actor2_name)
      end

      it "works with nil actor names" do
        allow(comparison_service).to receive(:compare)
          .with(actor1_id, actor2_id, nil, nil)
          .and_return(comparison_data)

        result = business_logic.compare_actors(actor1_id, actor2_id)
        expect(result).to eq(comparison_data)
      end
    end

    context "when validation error occurs" do
      let(:validation_error) { ValidationError.new("Invalid actor IDs") }

      before do
        allow(comparison_service).to receive(:compare).and_raise(validation_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and re-raises" do
        expect do
          business_logic.compare_actors(actor1_id, actor2_id)
        end.to raise_error(ValidationError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Actor comparison validation failed",
          hash_including(
            type: "business_logic_error",
            operation: "compare_actors",
            actor1_id: actor1_id,
            actor2_id: actor2_id,
            error: "Invalid actor IDs"
          )
        )
      end
    end

    context "when TMDB error occurs" do
      let(:tmdb_error) { TMDBError.new(500, "Service unavailable") }

      before do
        allow(comparison_service).to receive(:compare).and_raise(tmdb_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and re-raises" do
        expect do
          business_logic.compare_actors(actor1_id, actor2_id)
        end.to raise_error(TMDBError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Actor comparison API failed",
          hash_including(
            type: "business_logic_error",
            operation: "compare_actors",
            error: "Service unavailable"
          )
        )
      end
    end

    context "when unexpected error occurs" do
      let(:unexpected_error) { StandardError.new("Memory error") }

      before do
        allow(comparison_service).to receive(:compare).and_raise(unexpected_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error with backtrace and re-raises" do
        expect do
          business_logic.compare_actors(actor1_id, actor2_id)
        end.to raise_error(StandardError)

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Unexpected error in actor comparison",
          hash_including(
            type: "business_logic_error",
            operation: "compare_actors",
            actor1_id: actor1_id,
            actor2_id: actor2_id,
            error: "Memory error",
            error_class: "StandardError",
            backtrace: anything
          )
        )
      end
    end
  end

  describe "#health_check" do
    context "when all services are healthy" do
      before do
        allow(tmdb_service).to receive(:healthy?).and_return(true)
      end

      it "returns positive health status" do
        result = business_logic.health_check

        expect(result).to eq({
                               tmdb_service: true,
                               comparison_service: true,
                               movie_comparison_service: true
                             })
      end
    end

    context "when tmdb_service is unhealthy" do
      before do
        allow(tmdb_service).to receive(:healthy?).and_return(false)
      end

      it "returns negative health status for tmdb_service" do
        result = business_logic.health_check

        expect(result).to eq({
                               tmdb_service: false,
                               comparison_service: true,
                               movie_comparison_service: true
                             })
      end
    end

    context "when health check fails with exception" do
      let(:health_error) { StandardError.new("Health check failed") }

      before do
        allow(tmdb_service).to receive(:healthy?).and_raise(health_error)
        allow(StructuredLogger).to receive(:error)
      end

      it "logs the error and returns failure status" do
        result = business_logic.health_check

        expect(result).to eq({
                               tmdb_service: false,
                               comparison_service: false,
                               movie_comparison_service: false,
                               error: "Health check failed"
                             })

        expect(StructuredLogger).to have_received(:error).with(
          "Business Logic: Health check failed",
          hash_including(
            type: "business_logic_error",
            operation: "health_check",
            error: "Health check failed"
          )
        )
      end
    end
  end
end
