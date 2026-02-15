# CoStar

A Sinatra web app that discovers connections between actors using TMDB data, showing shared movies in a visual timeline.

## Build Commands

```bash
make test           # Run all tests (RSpec + Cucumber)
make test-rspec     # Run RSpec tests only
make test-cucumber  # Run Cucumber tests only
make lint           # Check code style (RuboCop)
make security       # Run security scans (Brakeman + bundler-audit)
make dev            # Start development server (Doppler + Puma)
make pre-commit     # Run lint + tests + security
```

## Critical Rules

- Pin dependencies to exact versions (e.g., `"sinatra", "4.2.1"`) — see Gemfile header for update procedure
- Keep docs updated with every code change
- Keep Makefile updated — add new tasks as project evolves
- Never commit `.env.*` files (except `.env.example`) — secrets live in Doppler
- All TMDB API calls must go through `ResilientTMDBClient` (circuit breaker + caching)

## Detailed Guides

| Topic | Guide |
|-------|-------|
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Deployment | [DEPLOYMENT.md](DEPLOYMENT.md) |
| Secrets | [DEPLOYMENT_SECRETS.md](DEPLOYMENT_SECRETS.md) |
| Security | [SECURITY.md](SECURITY.md) |
| Testing | [TESTING.md](TESTING.md) |
| Cucumber BDD | [docs/CUCUMBER_TESTING.md](docs/CUCUMBER_TESTING.md) |
