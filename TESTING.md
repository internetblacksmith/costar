# Testing Guide for ActorSync

This document outlines the testing strategy and provides instructions for running and maintaining tests in the ActorSync application.

## 🧪 Testing Stack

**Framework:** RSpec 3.12+  
**Request Testing:** Rack::Test  
**HTTP Mocking:** WebMock  
**Test Data:** FactoryBot + Faker  
**Coverage:** SimpleCov  
**Debugging:** Pry + Byebug  

## 📁 Test Structure

```
spec/
├── spec_helper.rb           # Main test configuration
├── support/
│   └── app.rb              # Test helpers and app definition
├── factories/              # FactoryBot factories
│   ├── actors.rb           # Actor test data
│   └── movies.rb           # Movie test data
├── lib/
│   ├── config/
│   │   └── cache_spec.rb   # Cache system tests
│   └── services/
│       ├── tmdb_service_spec.rb        # TMDB API service tests
│       └── timeline_builder_spec.rb    # Timeline logic tests
└── requests/
    └── api_spec.rb         # Integration tests for API endpoints
```

## 🚀 Running Tests

### All Tests
```bash
# Run complete test suite
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run with coverage report
bundle exec rspec --format html --out coverage/index.html
```

### Specific Test Files
```bash
# Run only unit tests
bundle exec rspec spec/lib/

# Run only integration tests
bundle exec rspec spec/requests/

# Run specific test file
bundle exec rspec spec/lib/services/tmdb_service_spec.rb

# Run specific test
bundle exec rspec spec/lib/services/tmdb_service_spec.rb:45
```

### Test Options
```bash
# Run only failed tests from last run
bundle exec rspec --only-failures

# Run tests matching a pattern
bundle exec rspec --grep "search_actors"

# Run tests with specific tag
bundle exec rspec --tag focus

# Randomize test order (default)
bundle exec rspec --order random
```

## 📊 Test Coverage

### Viewing Coverage Reports
```bash
# Generate and view coverage report
bundle exec rspec
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

### Coverage Targets
- **Current Target:** 60% minimum coverage
- **Goal:** 80% overall coverage
- **Critical Components:** 90%+ coverage for services

### Coverage Groups
- **Services** (`lib/services/`) - Core business logic
- **Configuration** (`lib/config/`) - Application configuration  
- **Application** (`app.rb`) - Main Sinatra application

## 🧩 Test Types

### Unit Tests (`spec/lib/`)
Test individual classes and methods in isolation:

**Cache Tests** (`spec/lib/config/cache_spec.rb`)
- Memory cache functionality
- TTL expiration behavior
- Thread safety
- Data type handling

**Configuration Policy Tests** (`spec/lib/config/configuration_policy_spec.rb`)
- Policy definition validation
- Required/optional field handling
- Type conversion testing
- Default value application
- Custom validation rules

**Configuration Validator Tests** (`spec/lib/config/configuration_validator_spec.rb`)
- Environment variable validation
- Type checking and conversion
- Error message clarity
- Edge case handling

**Service Tests** (`spec/lib/services/`)
- TMDB API integration (with mocked HTTP requests)
- Timeline building logic
- Error handling and validation
- Caching behavior

### Integration Tests (`spec/requests/`)
Test complete request/response cycles:

**API Endpoint Tests** (`spec/requests/api_spec.rb`)
- Health check endpoint
- Actor search functionality
- Movie retrieval
- Actor comparison timeline
- Error handling and edge cases

## 🏭 Test Factories

### Using Factories
```ruby
# Create actor test data
actor = attributes_for(:actor, :leonardo_dicaprio)
# => { id: 6193, name: "Leonardo DiCaprio", ... }

# Create movie test data
movie = attributes_for(:movie, :inception)
# => { id: 27205, title: "Inception", ... }

# Create random data
random_actor = attributes_for(:actor)
random_movie = attributes_for(:movie)
```

### Factory Traits
**Actors:**
- `:leonardo_dicaprio` - Real Leonardo DiCaprio data
- `:tom_hanks` - Real Tom Hanks data

**Movies:**  
- `:inception` - Real Inception movie data
- `:forrest_gump` - Real Forrest Gump data
- `:catch_me_if_you_can` - Real movie data

## 🌐 HTTP Mocking

### WebMock Setup
HTTP requests are automatically mocked in tests to ensure:
- Fast test execution
- Predictable test results
- No external API dependencies
- No rate limiting issues

### Mock Helpers
```ruby
# Mock actor search
mock_tmdb_actor_search('Leonardo', [actor_data])

# Mock actor movies
mock_tmdb_actor_movies(actor_id, [movie_data])

# Mock actor profile
mock_tmdb_actor_profile(actor_id, profile_data)
```

### Custom Mocking
```ruby
# Mock specific API responses
stub_request(:get, "https://api.themoviedb.org/3/search/person")
  .with(query: hash_including(query: "Leonardo"))
  .to_return(
    status: 200,
    body: { results: [actor_data] }.to_json,
    headers: { 'Content-Type' => 'application/json' }
  )
```

## 🐛 Debugging Tests

### Using Pry
```ruby
# Add debugging breakpoint in test
it 'does something' do
  binding.pry  # Execution stops here
  expect(result).to eq(expected)
end
```

### Test Debugging Commands
```bash
# Run single test with debugging
bundle exec rspec spec/path/to/test_spec.rb:line_number --format documentation

# Show test backtrace on failure
bundle exec rspec --backtrace

# Show warnings
bundle exec rspec --warnings
```

## 📝 Writing Tests

### Test Structure
```ruby
RSpec.describe ClassName do
  let(:subject) { ClassName.new }
  
  describe '#method_name' do
    context 'when condition' do
      it 'does expected behavior' do
        # Arrange
        setup_data
        
        # Act
        result = subject.method_name(params)
        
        # Assert
        expect(result).to eq(expected)
      end
    end
  end
end
```

### Best Practices

**1. Clear Test Names**
```ruby
# Good
it 'returns actor filmography when valid ID provided'

# Bad  
it 'works'
```

**2. Use Contexts for Conditions**
```ruby
describe '#search_actors' do
  context 'with valid query' do
    # happy path tests
  end
  
  context 'with empty query' do
    # error cases
  end
end
```

**3. Test Edge Cases**
- Empty inputs
- Invalid data
- Network failures
- Boundary conditions

**4. Mock External Dependencies**
```ruby
# Always mock HTTP requests
stub_request(:get, /api\.themoviedb\.org/)
  .to_return(status: 200, body: mock_data.to_json)
```

## 🔧 Common Issues

### Factory Errors
```bash
# Error: Defining methods in blocks is not supported
# Solution: Define methods outside factory blocks

# Error: Factory not found
# Solution: Ensure FactoryBot.find_definitions is called
```

### WebMock Errors
```bash
# Error: Real HTTP connections are disabled
# Solution: Add proper stub_request calls

# Error: No stub matched request
# Solution: Check URL patterns and parameters in stubs
```

### Coverage Issues
```bash
# Error: Coverage below minimum
# Solution: Add more tests or adjust minimum_coverage setting

# Missing coverage for specific lines
# Solution: Add tests that exercise those code paths
```

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Run tests
        run: bundle exec rspec
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

### Test Commands for CI
```bash
# Basic test run
bundle exec rspec --format progress

# With JUnit output for CI
bundle exec rspec --format RspecJunitFormatter --out test-results.xml

# Fail fast (stop on first failure)
bundle exec rspec --fail-fast
```

## 📈 Performance Testing

### Test Performance Monitoring
```ruby
# Example performance test
it 'processes large datasets efficiently' do
  start_time = Time.now
  
  result = subject.process_large_dataset(large_data)
  
  execution_time = Time.now - start_time
  expect(execution_time).to be < 1.0 # Should complete in under 1 second
end
```

### Slow Test Identification
```bash
# Show slowest tests
bundle exec rspec --profile 10
```

## 🔒 Security Testing

### Input Validation Tests
```ruby
it 'validates input parameters' do
  expect { service.search_actors('') }.to raise_error(ValidationError)
  expect { service.search_actors(nil) }.to raise_error(ValidationError)
end
```

### Error Handling Tests
```ruby
it 'handles API errors gracefully' do
  stub_request(:get, /api/).to_return(status: 500)
  
  expect { service.call }.to raise_error(TMDBError)
end
```

---

## 🎯 Next Steps

1. **Increase Coverage** - Add more tests to reach 80% coverage target
2. **Add Performance Tests** - Test with realistic data volumes
3. **Integration Testing** - Add end-to-end user journey tests
4. **Load Testing** - Test API endpoints under load
5. **Security Testing** - Add penetration testing for security vulnerabilities

For questions or issues with testing, refer to the RSpec documentation or create an issue in the project repository.