# VCR Cassettes

This directory contains recorded HTTP interactions for tests using VCR.

## Recording New Cassettes

To record new cassettes with real TMDB API responses:

1. Set your TMDB API key in the environment:
   ```bash
   export TMDB_API_KEY=your_actual_api_key
   ```

2. Delete the existing cassette(s) you want to re-record:
   ```bash
   rm spec/fixtures/vcr_cassettes/actor_search_*.json
   ```

3. Run the tests to record new cassettes:
   ```bash
   bundle exec rspec spec/integration/actor_search_flow_spec.rb
   ```

4. The cassettes will be created with the API responses, and VCR will automatically filter out your API key, replacing it with `<TMDB_API_KEY>`

## Important Notes

- VCR cassettes are committed to the repository to ensure consistent test runs
- Sensitive data (API keys) are automatically filtered by VCR configuration
- If the TMDB API response format changes, delete and re-record the cassettes
- The cassettes use JSON format for better readability

## Current Cassettes

- `actor_search_tom.json` - Search results for "Tom"
- `actor_search_lupita.json` - Search results for "Lupita" 
- `actor_search_field_params.json` - Tests field parameter handling
- `actor_search_no_results.json` - Empty search results