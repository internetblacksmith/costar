# Testing Setup Guide

## Quick Start

### Basic Testing (Memory Cache)
```bash
# Run all tests with memory cache
make test

# Run specific test
bundle exec rspec spec/path/to/test_spec.rb

# Run only previously failed tests
bundle exec rspec --only-failures

# Clean up any leftover test servers
make cleanup-servers
```

## Server Configuration
- **Development server**: Port 4567 (`make dev`)
- **Test server**: Port 45670 (automatically used by RSpec/Cucumber)
- **Redis**: Port 6379 (Docker test environment)

Tests can run simultaneously with the development server without port conflicts.

### Comprehensive Testing (With Redis)
```bash
# 1. Start Redis test environment
make test-setup

# 2. Run tests with Redis support (enables all Redis-dependent tests)
make test-with-redis

# 3. Stop Redis when done
make test-teardown
```

## What You Get With Redis

**Without Redis** (5 pending tests):
- Cache cleaner tests skip Redis-specific functionality
- Tests use memory cache fallback
- All core functionality still tested

**With Redis** (0 pending tests):
- Full cache functionality testing
- Redis connection pooling tests
- TTL and expiration behavior tests
- Production-like caching behavior

## Test Types

- **RSpec**: Unit and integration tests (~348 examples)
- **Cucumber**: End-to-end browser tests (13 scenarios)
- **VCR**: API response recording/playback for consistent testing

## Troubleshooting

### Redis Connection Issues
```bash
# Check if Redis is running
docker exec costar_redis_test redis-cli ping

# View Redis logs
docker-compose logs redis-test

# Reset Redis environment
make test-teardown && make test-setup
```

### VCR Cassette Issues
```bash
# Re-record VCR cassettes if API responses change
VCR_RECORD_MODE=new_episodes bundle exec rspec
VCR_RECORD_MODE=new_episodes bundle exec cucumber
```

The test suite automatically detects Redis availability and adjusts accordingly!