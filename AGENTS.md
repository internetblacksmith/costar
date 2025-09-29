# Agent Development Guide

## Build/Test Commands
- **Run all tests**: `make test` or `bundle exec rspec && bundle exec cucumber`
- **Run single test file**: `bundle exec rspec spec/path/to/test_spec.rb`
- **Run single test**: `bundle exec rspec spec/path/to/test_spec.rb:123` (line number)
- **Run only failed tests**: `bundle exec rspec --only-failures` (requires previous run)
- **Run with coverage**: `bundle exec rspec --format documentation`
- **Lint code**: `make lint` or `bundle exec rubocop -A`
- **Security scan**: `make security` or `bundle exec brakeman && bundle exec bundle-audit`
- **Start dev server**: `make dev` or `./scripts/dev`

## Redis Test Environment
- **Setup Redis**: `make test-setup` (starts Docker Redis for comprehensive testing)
- **Run tests with Redis**: `make test-with-redis` (all Redis-dependent tests will pass)
- **Teardown Redis**: `make test-teardown` (stops Docker containers)
- **Auto-detection**: Tests automatically detect Redis on localhost:6379

## Code Style
- **Ruby version**: 3.0+, use `# frozen_string_literal: true` header
- **Strings**: Double quotes `"text"` (enforced by RuboCop)
- **Imports**: Use `require_relative` for local files, group by type
- **Naming**: snake_case for methods/variables, PascalCase for classes
- **Line length**: Max 800 chars (relaxed for this project)
- **Methods**: Max 30 lines, complexity <8
- **Error handling**: Use custom error classes, include ErrorHandlerModule for consistent patterns
- **DTOs**: Use typed data objects with validation, factory pattern for API responses
- **Services**: Dependency injection via ServiceContainer, single responsibility
- **Testing**: RSpec for unit/integration, Cucumber for E2E, VCR for API mocking