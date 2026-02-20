# CoStar

[![CI](https://github.com/jabawack81/screen_thread/actions/workflows/ci.yml/badge.svg)](https://github.com/jabawack81/screen_thread/actions/workflows/ci.yml)
[![Deploy](https://github.com/jabawack81/screen_thread/actions/workflows/deploy.yml/badge.svg)](https://github.com/jabawack81/screen_thread/actions/workflows/deploy.yml)
[![Ruby](https://img.shields.io/badge/ruby-4.0.1-red.svg)](https://www.ruby-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A web application that discovers the connections between actors and movies. Find movies that two actors have appeared in together, or find actors who have appeared in two movies. Built with Ruby/Sinatra backend, HTMX frontend, and deployed via Kamal to a DigitalOcean VPS.

## Features

- **Actor Search**: Search for actors with autocomplete suggestions and input validation
- **Timeline Visualization**: View filmographies organized by year in a vertical timeline
- **Shared Movies Highlighting**: Common movies between actors are highlighted in red
- **Responsive Design**: Works on desktop and mobile devices
- **TMDB Integration**: Uses The Movie Database API with circuit breaker resilience
- **Redis Caching**: High-performance caching with connection pooling
- **Monitoring**: Structured logging, error tracking (Sentry), and health checks

## Prerequisites

- Ruby 4.0+
- Bundler (`gem install bundler`)
- Docker (for Redis and production deployment)
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) (secrets management)

## Getting Started

### 1. Clone and install dependencies

```bash
git clone <repository-url>
cd movie_together
make setup-dev
```

### 2. Set up Doppler for development

```bash
doppler login
doppler setup --project movie_together --config dev
```

Required secrets in the `dev` config:
- `TMDB_API_KEY` — get one at [TMDB API](https://www.themoviedb.org/settings/api)
- `SESSION_SECRET` — generate with `openssl rand -hex 32`
- `REDIS_URL` — `redis://localhost:6379` for local Redis

Optional:
- `SENTRY_DSN` — [Sentry](https://sentry.io) error tracking
- `POSTHOG_API_KEY` — [PostHog](https://posthog.com) analytics

### 3. Start Redis and run the app

```bash
make redis-start   # in a separate terminal
make dev           # starts development server with Doppler secrets
```

### 4. Open in browser

Visit `http://localhost:4567`

## Development Commands

```bash
make                 # Interactive menu
make dev             # Start development server (Doppler + Puma)
make test            # Run all tests (RSpec + Cucumber)
make test-rspec      # Run RSpec tests only
make test-cucumber   # Run Cucumber tests only
make lint            # Check code style (RuboCop)
make fix             # Auto-fix code style issues
make security        # Run security scans (Brakeman + bundler-audit)
make pre-commit      # Run all checks before committing
make help            # Show all available commands
```

## Architecture

### Core Services
- **TMDBService**: API integration with caching and standardized error handling
- **ResilientTMDBClient**: Circuit breaker pattern for API resilience
- **ActorComparisonService**: Timeline generation and movie analysis
- **TimelineBuilder**: Performance-optimized timeline rendering
- **SimpleRequestThrottler**: Synchronous request rate limiting
- **CacheCleaner**: Background service for automatic TTL-based cache cleanup

### Security & Performance
- **Rate Limiting**: Rack::Attack with Redis backend
- **Input Validation**: Comprehensive sanitization for all user inputs
- **Security Headers**: CSP, HSTS, X-Frame-Options, and more
- **CORS Protection**: Environment-based origin allowlisting
- **Caching**: Redis with connection pooling (production) / Memory (development)

### Monitoring & Reliability
- **Circuit Breaker**: Automatic API failure handling
- **Health Checks**: `/health/simple` and `/health/complete` endpoints
- **Error Tracking**: Sentry integration for production monitoring

## API Endpoints

### Core Application
- `GET /` - Main application page
- `GET /health/simple` - Basic health check (for load balancers)
- `GET /health/complete` - Comprehensive health check with dependencies

### Actor Search & Comparison API
- `GET /api/actors/search?q=query&field=actor1` - Search actors with validation
- `GET /api/actors/:id/movies` - Get actor filmography
- `GET /api/actors/compare?actor1_id=123&actor2_id=456&actor1_name=Name1&actor2_name=Name2` - Timeline comparison

All API endpoints include rate limiting, input validation, CORS headers, and structured error responses.

## Production Deployment

CoStar is deployed to a DigitalOcean VPS via [Kamal v2](https://kamal-deploy.org/) with Traefik reverse proxy for HTTPS.

**Live at:** `https://as.frenimies-lab.dev`

### Secrets management

Production secrets are stored in [Doppler](https://doppler.com) and fetched at deploy time by Kamal's native Doppler adapter (configured in `.kamal/secrets`). No `doppler run` wrapper is needed — Kamal handles it directly.

### Deploy

```bash
make deploy          # Deploy to production
make deploy-status   # Show deployment status
make deploy-logs     # Stream production logs
make deploy-rollback # Rollback to previous version
make deploy-setup    # First-time Kamal setup on new server
```

### Setting up deployment (first time)

```bash
make setup-deploy    # Checks prerequisites, installs Kamal, generates .kamal/secrets
```

Doppler must be configured with the `movie_together/prd` config containing all required secrets (see `config/deploy.yml` for the full list).

### CI/CD

GitHub Actions runs tests and security scans on every push. Deployment to production can be triggered via `make deploy` or through the GitHub Actions deploy workflow.

### Infrastructure

- **Host**: DigitalOcean VPS with Traefik reverse proxy
- **Registry**: GitHub Container Registry (ghcr.io)
- **Accessories**: Redis 7.4 (managed by Kamal on the VPS)
- **Domain**: `as.frenimies-lab.dev` (Cloudflare DNS, grey cloud / DNS only)

## Technology Stack

### Backend
- **Ruby 4.0+** with Sinatra framework
- **Redis** for high-performance caching
- **Puma** web server

### Frontend
- **HTMX** for dynamic interactions
- **ERB** templating
- **Modular CSS** with ITCSS methodology

### External Services
- **TMDB API v3** for movie data
- **Sentry** for error tracking
- **Doppler** for secrets management
- **PostHog** for product analytics

### Testing
- **RSpec** for unit/integration tests
- **Cucumber** for end-to-end BDD tests
- **VCR** + **WebMock** for API mocking
- **RuboCop** for code quality
- **Brakeman** for security scanning

## TMDB API Compliance

This application uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.

**Important**: This is a non-commercial personal project. For commercial use, you must obtain a commercial agreement with TMDB. Review [TMDB API Terms](https://www.themoviedb.org/api-terms-of-use) before deployment.

## License

MIT License

**Note**: While this code is MIT licensed, the TMDB API has its own terms of use that must be followed when using the application.
