# Cucumber + VCR Testing Guide

## Overview

ActorSync uses Cucumber for end-to-end browser simulation testing combined with VCR for reliable API recording and playback. This dual-mode setup ensures tests work consistently in both development and CI/CD environments while catching real-world issues that unit tests might miss.

## Why Cucumber + VCR?

Our RSpec test suite (429 examples, 0 failures) provides excellent unit and integration test coverage. However, it was missing critical real-world issues like the Rack::Attack 403 error because:

- RSpec tests mock the middleware stack
- Tests don't simulate real browser behavior (headers, user agents)
- No true end-to-end user flow testing

Cucumber addresses these gaps by:
- Testing through the full middleware stack (catches Rack::Attack issues)
- Simulating real browser requests with proper headers
- Testing complete user workflows end-to-end
- Using VCR for reliable TMDB API testing

## Architecture

### Browser Simulation

```ruby
class BrowserSimulatorDriver < Capybara::RackTest::Driver
  # Simulates real browser headers including:
  # - User-Agent (Chrome/Safari)
  # - Accept headers
  # - Security headers (Sec-Fetch-*)
  # - Cache-Control
end
```

### Dual-Mode VCR Configuration

1. **CI/CD Mode** (default)
   - Uses pre-recorded VCR cassettes only
   - Fails if cassettes are missing
   - Ensures consistent test results
   - No external API calls

2. **Development Mode**
   - Can record new cassettes
   - Flexible recording modes
   - Helpful error messages
   - Easy cassette management

## Quick Start

### Running Cucumber Tests

```bash
# Run all Cucumber tests
make test-cucumber

# Run specific feature
bundle exec cucumber features/actor_search.feature

# Run specific scenario
bundle exec cucumber features/actor_search.feature -n "Successful actor search"

# Record new VCR cassettes
make cucumber-record

# Run in CI mode (cassettes only)
CI=true bundle exec cucumber
```

### Writing New Features

1. Create a feature file in `features/`:

```gherkin
Feature: My New Feature
  As a user
  I want to do something
  So that I achieve a goal

  @vcr
  Scenario: Happy path
    Given I am on the home page
    When I perform an action
    Then I should see the expected result
```

2. Add step definitions in `features/step_definitions/`:

```ruby
When("I perform an action") do
  visit "/some/path"
  fill_in "field", with: "value"
  click_on "Submit"
end

Then("I should see the expected result") do
  expect(page).to have_content("Success")
  expect(page.status_code).to eq(200)
end
```

3. Run with VCR recording:

```bash
VCR_RECORD_MODE=new_episodes bundle exec cucumber features/my_new_feature.feature
```

## VCR Cassette Management

### Recording Modes

- `none`: Never record, only use existing cassettes (CI default)
- `once`: Record if cassette doesn't exist (development default)
- `new_episodes`: Record new interactions, keep existing
- `all`: Re-record everything (use with caution)

### Recording New Cassettes

```bash
# Record missing interactions only
VCR_RECORD_MODE=new_episodes bundle exec cucumber

# Re-record all cassettes (careful!)
VCR_RECORD_MODE=all bundle exec cucumber

# Record specific feature
VCR_RECORD_MODE=new_episodes bundle exec cucumber features/actor_search.feature
```

### Cassette Location

Cassettes are stored in `features/fixtures/vcr_cassettes/` organized by feature:

```
features/fixtures/vcr_cassettes/
├── actor_search/
│   ├── successful_actor_search_with_browser_headers.json
│   ├── search_with_special_characters.json
│   └── ...
└── actor_comparison/
    ├── compare_two_actors_with_common_movies.json
    └── ...
```

### Best Practices

1. **Commit Cassettes**: Always commit VCR cassettes to the repository
2. **Filter Sensitive Data**: API keys are automatically filtered
3. **Update When Needed**: Re-record cassettes when API responses change
4. **Review Changes**: Always review cassette diffs before committing

## Environment Configuration

### Development Setup

```bash
# Using Doppler (recommended)
doppler run -- bundle exec cucumber

# Using .env file
cp .env.example .env
# Add your TMDB_API_KEY to .env
bundle exec cucumber
```

### CI/CD Configuration

The CI pipeline automatically:
- Sets `CI=true` to enforce cassette-only mode
- Sets `VCR_MODE=ci` for strict cassette usage
- Runs both RSpec and Cucumber tests
- Generates JUnit XML reports

## Common Issues and Solutions

### Missing VCR Cassette in CI

**Error**: `Missing VCR cassette in CI: feature_name/scenario_name`

**Solution**: Record the cassette in development and commit it:
```bash
VCR_RECORD_MODE=new_episodes bundle exec cucumber features/feature_name.feature
git add features/fixtures/vcr_cassettes/
git commit -m "Add VCR cassettes for new scenarios"
```

### Unhandled HTTP Request

**Error**: `VCR::Errors::UnhandledHTTPRequestError`

**Solution**: 
1. Check if you're in a `@vcr` tagged scenario
2. Record the missing interaction:
   ```bash
   VCR_RECORD_MODE=new_episodes bundle exec cucumber
   ```

### 403 Forbidden Errors

**Error**: Response has status 403

**Possible Causes**:
- Rack::Attack rate limiting
- Missing browser headers
- Invalid API credentials

**Solution**: The browser simulator should handle this, but check:
- User-Agent header is present
- Rate limits aren't exceeded
- API key is valid

## Feature Examples

### Actor Search with Rate Limiting Test

```gherkin
@vcr
Scenario: Rapid successive searches (rate limit test)
  When I rapidly search for the following terms:
    | search_term |
    | Tom         |
    | Tom H       |
    | Tom Ha      |
  Then all searches should complete successfully
  And no rate limiting errors should occur
```

This scenario specifically tests that our browser simulation bypasses Rack::Attack blocks.

### Full User Flow Test

```gherkin
@vcr
Scenario: Full user flow with browser simulation
  When I search for "Tom" in the first actor field
  And I click on "Tom Hanks" from the suggestions
  And I search for "Meg" in the second actor field  
  And I click on "Meg Ryan" from the suggestions
  And I click "Compare"
  Then I should see the timeline comparison
```

This tests the complete user journey with all middleware active.

## Debugging Tips

### View Response Details

```ruby
Then("show me the response") do
  puts "Status: #{page.status_code}"
  puts "Headers: #{page.response_headers}"
  puts "Body: #{page.body[0..500]}"
end
```

### Check Current Path

```ruby
Then("show me where I am") do
  puts "Current path: #{current_path}"
  puts "Current URL: #{current_url}"
end
```

### Save Page for Inspection

```ruby
Then("save the page") do
  save_page("tmp/cucumber_debug.html")
  puts "Page saved to tmp/cucumber_debug.html"
end
```

## Continuous Integration

GitHub Actions runs Cucumber tests automatically:

```yaml
- name: Run Cucumber tests
  run: bundle exec cucumber --format progress --format junit --out tmp/cucumber_results.xml
  env:
    CI: true
    VCR_MODE: ci
```

Test results are uploaded as artifacts for debugging failures.

## Makefile Commands

```bash
make test           # Run all tests (RSpec + Cucumber)
make test-cucumber  # Run Cucumber tests only
make cucumber-record # Record new VCR cassettes
```

## Summary

The Cucumber + VCR setup provides:

1. **Real Browser Testing**: Catches middleware issues RSpec misses
2. **Reliable API Testing**: VCR ensures consistent test results
3. **Dual-Mode Flexibility**: Development recording, CI playback
4. **Complete Coverage**: End-to-end user flows with all components active

This combination ensures ActorSync works correctly in real-world conditions, not just in isolated test scenarios.