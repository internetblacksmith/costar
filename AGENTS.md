# Agent Development Guide

## ⚠️ Important: Keep Makefile Updated

**The Makefile must be kept in sync with the project's actual tooling.** When updating Gemfile dependencies, dev workflows, or tooling:
1. Always update the corresponding Makefile targets
2. Test Makefile commands before committing (`make dev`, `make test`, `make lint`, `make deploy`)
3. Check if gems are actually in the Gemfile before referencing them in Makefile
4. Document changes in this AGENTS.md file

**Last Updated**: December 29, 2025 - Ruby 4.0.0 upgrade, gem version pinning

## ⚠️ Important: Gem Version Pinning Policy

**All gems MUST be pinned to exact versions for production stability and reproducible builds.**

### Rules:
1. **Always pin to exact versions**: Use `gem "name", "x.y.z"` format (not `>=`, `~>`, or unpinned)
2. **Pin to latest patch version**: When adding or updating gems, use the latest available version
3. **Update process**:
   - Run `bundle outdated` to see available updates
   - Update version in Gemfile
   - Run `bundle update <gem-name>`
   - Run full test suite before committing
4. **Document updates**: Update the "Last updated" comment in Gemfile header

### Why exact pinning?
- Reproducible builds across environments
- Prevents unexpected breakages from transitive dependency updates
- Makes security audits easier
- Ensures CI/CD and production use identical versions

## Build/Test Commands
- **Run all tests**: `make test` or `bundle exec rspec && bundle exec cucumber`
- **Run single test file**: `bundle exec rspec spec/path/to/test_spec.rb`
- **Run single test**: `bundle exec rspec spec/path/to/test_spec.rb:123` (line number)
- **Run only failed tests**: `bundle exec rspec --only-failures` (requires previous run)
- **Run with coverage**: `bundle exec rspec --format documentation`
- **Lint code**: `make lint` or `bundle exec rubocop -A`
- **Security scan**: `make security` or `bundle exec brakeman && bundle exec bundle-audit`
- **Start dev server**: `make dev` or `./scripts/dev` (runs on port 4567)
- **Clean up test servers**: `make cleanup-servers` (kills leftover Capybara/test servers)

## Server Ports
- **Development server**: Port 4567 (`make dev`)
- **Test server**: Port 45670 (RSpec/Cucumber tests)
- **Redis**: Port 6379 (Docker test environment)

## Redis Test Environment
- **Setup Redis**: `make test-setup` (starts Docker Redis for comprehensive testing)
- **Run tests with Redis**: `make test-with-redis` (all Redis-dependent tests will pass)
- **Teardown Redis**: `make test-teardown` (stops Docker containers)
- **Auto-detection**: Tests automatically detect Redis on localhost:6379

## Code Style
- **Ruby version**: 4.0+, use `# frozen_string_literal: true` header
- **Strings**: Double quotes `"text"` (enforced by RuboCop)
- **Imports**: Use `require_relative` for local files, group by type
- **Naming**: snake_case for methods/variables, PascalCase for classes
- **Line length**: Max 800 chars (relaxed for this project)
- **Methods**: Max 30 lines, complexity <8
- **Error handling**: Use custom error classes, include ErrorHandlerModule for consistent patterns
- **DTOs**: Use typed data objects with validation, factory pattern for API responses
- **Services**: Dependency injection via ServiceContainer, single responsibility
- **Testing**: RSpec for unit/integration, Cucumber for E2E, VCR for API mocking