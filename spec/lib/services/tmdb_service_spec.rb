# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TMDBService do
  let(:service) { TMDBService.new }
  let(:api_key) { 'test_api_key' }

  before do
    allow(ENV).to receive(:fetch).with('TMDB_API_KEY').and_return(api_key)
  end

  describe '#search_actors' do
    context 'with valid query' do
      let(:query) { 'Leonardo DiCaprio' }
      let(:mock_response) do
        {
          results: [
            attributes_for(:actor, :leonardo_dicaprio),
            {
              id: 123,
              name: 'Leonardo Nam',
              popularity: 5.2,
              profile_path: '/test.jpg'
            }
          ]
        }
      end

      before do
        stub_request(:get, "https://api.themoviedb.org/3/search/person")
          .with(
            query: hash_including(
              api_key: api_key,
              query: query
            )
          )
          .to_return(
            status: 200,
            body: mock_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns actor search results' do
        results = service.search_actors(query)
        
        expect(results).to be_an(Array)
        expect(results.length).to eq(2)
        expect(results.first['name']).to eq('Leonardo DiCaprio')
        expect(results.first['id']).to eq(6193)
      end

      it 'caches the results' do
        # First call
        service.search_actors(query)
        
        # Second call should use cache (no HTTP request)
        expect do
          results = service.search_actors(query)
          expect(results.first['name']).to eq('Leonardo DiCaprio')
        end.not_to change { WebMock::RequestRegistry.instance.requested_signatures.count }
      end
    end

    context 'with empty query' do
      it 'raises ValidationError' do
        expect { service.search_actors('') }.to raise_error(ValidationError, /Query cannot be empty/)
      end

      it 'raises ValidationError for nil query' do
        expect { service.search_actors(nil) }.to raise_error(ValidationError, /Query cannot be empty/)
      end
    end

    context 'with API error' do
      let(:query) { 'test' }

      before do
        stub_request(:get, "https://api.themoviedb.org/3/search/person")
          .to_return(status: 401, body: { status_message: 'Invalid API key' }.to_json)
      end

      it 'raises TMDBError' do
        expect { service.search_actors(query) }.to raise_error(TMDBError, /API request failed/)
      end
    end
  end

  describe '#get_actor_movies' do
    let(:actor_id) { 6193 }
    let(:mock_movies) do
      {
        cast: [
          attributes_for(:movie, :inception),
          attributes_for(:movie, :catch_me_if_you_can)
        ]
      }
    end

    before do
      stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}/movie_credits")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: mock_movies.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns actor filmography' do
      movies = service.get_actor_movies(actor_id)
      
      expect(movies).to be_an(Array)
      expect(movies.length).to eq(2)
      expect(movies.first['title']).to eq('Inception')
      expect(movies.first['character']).to eq('Dom Cobb')
    end

    it 'caches the results' do
      # First call
      service.get_actor_movies(actor_id)
      
      # Second call should use cache
      expect do
        movies = service.get_actor_movies(actor_id)
        expect(movies.first['title']).to eq('Inception')
      end.not_to change { WebMock::RequestRegistry.instance.requested_signatures.count }
    end

    context 'with invalid actor ID' do
      before do
        stub_request(:get, "https://api.themoviedb.org/3/person/999999/movie_credits")
          .to_return(status: 404, body: { status_message: 'The resource you requested could not be found.' }.to_json)
      end

      it 'raises TMDBError' do
        expect { service.get_actor_movies(999999) }.to raise_error(TMDBError)
      end
    end
  end

  describe '#get_actor_profile' do
    let(:actor_id) { 6193 }
    let(:mock_profile) do
      {
        id: 6193,
        name: 'Leonardo DiCaprio',
        biography: 'Leonardo Wilhelm DiCaprio is an American actor...',
        birthday: '1974-11-11',
        place_of_birth: 'Los Angeles, California, USA',
        profile_path: '/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg'
      }
    end

    before do
      stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: mock_profile.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns actor profile' do
      profile = service.get_actor_profile(actor_id)
      
      expect(profile['name']).to eq('Leonardo DiCaprio')
      expect(profile['birthday']).to eq('1974-11-11')
      expect(profile['place_of_birth']).to eq('Los Angeles, California, USA')
    end

    it 'caches the results' do
      # First call
      service.get_actor_profile(actor_id)
      
      # Second call should use cache
      expect do
        profile = service.get_actor_profile(actor_id)
        expect(profile['name']).to eq('Leonardo DiCaprio')
      end.not_to change { WebMock::RequestRegistry.instance.requested_signatures.count }
    end
  end

  describe 'error handling' do
    context 'when network request fails' do
      before do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_raise(StandardError.new('Network error'))
      end

      it 'raises TMDBError for search_actors' do
        expect { service.search_actors('test') }.to raise_error(TMDBError)
      end

      it 'raises TMDBError for get_actor_movies' do
        expect { service.get_actor_movies(123) }.to raise_error(TMDBError)
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_request(:get, /api\.themoviedb\.org/)
          .to_return(status: 200, body: 'invalid json')
      end

      it 'raises TMDBError' do
        expect { service.search_actors('test') }.to raise_error(TMDBError)
      end
    end
  end
end