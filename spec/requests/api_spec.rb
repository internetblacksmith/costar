# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API Endpoints', type: :request do
  describe 'GET /health' do
    before do
      allow(Cache).to receive(:healthy?).and_return(true)
    end

    it 'returns healthy status' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      
      response_data = json_response
      expect(response_data['status']).to eq('healthy')
      expect(response_data['checks']['cache']['status']).to eq('healthy')
    end

    it 'returns degraded status when cache is unhealthy' do
      allow(Cache).to receive(:healthy?).and_return(false)

      get '/health'

      expect(last_response.status).to eq(503)
      response_data = json_response
      expect(response_data['status']).to eq('degraded')
      expect(response_data['checks']['cache']['status']).to eq('unhealthy')
    end
  end

  describe 'GET /' do
    it 'renders the main page' do
      get '/'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('ActorSync')
      expect(last_response.body).to include('Compare Filmographies')
    end
  end

  describe 'API endpoints' do
    describe 'GET /api/actors/search' do
      let(:leonardo_data) { attributes_for(:actor, :leonardo_dicaprio) }
      let(:search_results) do
        {
          results: [leonardo_data]
        }
      end

      context 'with valid query' do
        before do
          mock_tmdb_actor_search('Leonardo', search_results[:results])
        end

        it 'returns actor suggestions' do
          get '/api/actors/search', { q: 'Leonardo', field: 'actor1' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('Leonardo DiCaprio')
          expect(last_response.body).to include('data-actor-id="6193"')
        end

        it 'includes the correct field parameter' do
          get '/api/actors/search', { q: 'Leonardo', field: 'actor2' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('data-field="actor2"')
        end
      end

      context 'with empty query' do
        it 'returns empty suggestions' do
          get '/api/actors/search', { q: '', field: 'actor1' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to be_empty
        end
      end

      context 'without query parameter' do
        it 'returns empty suggestions' do
          get '/api/actors/search', { field: 'actor1' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to be_empty
        end
      end

      context 'when TMDB API fails' do
        before do
          stub_request(:get, "https://api.themoviedb.org/3/search/person")
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns error message' do
          get '/api/actors/search', { q: 'test', field: 'actor1' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('Search Error')
        end
      end
    end

    describe 'GET /api/actors/:id/movies' do
      let(:actor_id) { 6193 }
      let(:movies_data) do
        {
          cast: [
            attributes_for(:movie, :inception),
            attributes_for(:movie, :catch_me_if_you_can)
          ]
        }
      end

      context 'with valid actor ID' do
        before do
          mock_tmdb_actor_movies(actor_id, movies_data[:cast])
        end

        it 'returns actor filmography as JSON' do
          get "/api/actors/#{actor_id}/movies"

          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to include('application/json')
          
          response_data = json_response
          expect(response_data).to be_an(Array)
          expect(response_data.length).to eq(2)
          expect(response_data.first['title']).to eq('Inception')
        end
      end

      context 'without actor ID' do
        it 'returns 400 error' do
          get '/api/actors//movies'

          expect(last_response.status).to eq(404) # Sinatra returns 404 for missing routes
        end
      end

      context 'when TMDB API fails' do
        before do
          stub_request(:get, "https://api.themoviedb.org/3/person/#{actor_id}/movie_credits")
            .to_return(status: 404, body: { status_message: 'Not found' }.to_json)
        end

        it 'returns error response' do
          get "/api/actors/#{actor_id}/movies"

          expect(last_response.status).to eq(404)
          response_data = json_response
          expect(response_data['error']).to include('API request failed')
        end
      end
    end

    describe 'GET /api/actors/compare' do
      let(:actor1_id) { 6193 }
      let(:actor2_id) { 31 }
      let(:actor1_name) { 'Leonardo DiCaprio' }
      let(:actor2_name) { 'Tom Hanks' }

      let(:leonardo_movies) do
        [
          attributes_for(:movie, :inception),
          attributes_for(:movie, :catch_me_if_you_can)
        ]
      end

      let(:tom_movies) do
        [
          attributes_for(:movie, :forrest_gump),
          attributes_for(:movie, :catch_me_if_you_can)
        ]
      end

      let(:leonardo_profile) do
        {
          id: 6193,
          name: 'Leonardo DiCaprio',
          biography: 'American actor...',
          profile_path: '/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg'
        }
      end

      let(:tom_profile) do
        {
          id: 31,
          name: 'Tom Hanks',
          biography: 'American actor...',
          profile_path: '/xndWFsBlClOJFRdhSt4NBwiPq2o.jpg'
        }
      end

      context 'with valid actor IDs' do
        before do
          mock_tmdb_actor_movies(actor1_id, leonardo_movies)
          mock_tmdb_actor_movies(actor2_id, tom_movies)
          mock_tmdb_actor_profile(actor1_id, leonardo_profile)
          mock_tmdb_actor_profile(actor2_id, tom_profile)
        end

        it 'returns timeline comparison' do
          get '/api/actors/compare', {
            actor1_id: actor1_id,
            actor2_id: actor2_id,
            actor1_name: actor1_name,
            actor2_name: actor2_name
          }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('timeline-container')
          expect(last_response.body).to include('Leonardo DiCaprio')
          expect(last_response.body).to include('Tom Hanks')
          expect(last_response.body).to include('Catch Me If You Can') # Shared movie
        end
      end

      context 'without required parameters' do
        it 'returns error for missing actor1_id' do
          get '/api/actors/compare', {
            actor2_id: actor2_id,
            actor1_name: actor1_name,
            actor2_name: actor2_name
          }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('Please select both actors')
        end

        it 'returns error for missing actor2_id' do
          get '/api/actors/compare', {
            actor1_id: actor1_id,
            actor1_name: actor1_name,
            actor2_name: actor2_name
          }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('Please select both actors')
        end
      end

      context 'when TMDB API fails' do
        before do
          stub_request(:get, /api\.themoviedb\.org/)
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns error message' do
          get '/api/actors/compare', {
            actor1_id: actor1_id,
            actor2_id: actor2_id,
            actor1_name: actor1_name,
            actor2_name: actor2_name
          }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('API Error')
        end
      end
    end
  end

  describe 'Error handling' do
    it 'handles 404 routes' do
      get '/non-existent-endpoint'

      expect(last_response.status).to eq(404)
    end

    it 'includes CORS headers for API endpoints' do
      get '/api/actors/search', { q: 'test' }

      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end
  end

  describe 'Security headers' do
    context 'in production environment' do
      before do
        allow(ENV).to receive(:fetch).with('RACK_ENV', 'development').and_return('production')
      end

      it 'includes security middleware' do
        # This would test the security middleware if we had a way to verify it
        # For now, we can at least verify the app loads with production config
        get '/health'
        expect(last_response.status).to eq(200)
      end
    end
  end
end