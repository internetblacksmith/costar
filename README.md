# 🎬 MovieTogether

[![CI](https://github.com/jabawack81/movie_together/actions/workflows/ci.yml/badge.svg)](https://github.com/jabawack81/movie_together/actions/workflows/ci.yml)
[![Deploy](https://github.com/jabawack81/movie_together/actions/workflows/deploy.yml/badge.svg)](https://github.com/jabawack81/movie_together/actions/workflows/deploy.yml)
[![Ruby](https://img.shields.io/badge/ruby-3.4.2-red.svg)](https://www.ruby-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A production-ready web application that visualizes actor filmographies in a timeline format, highlighting movies that two actors have appeared in together. Built with a resilient Ruby/Sinatra backend and HTMX frontend with comprehensive security hardening.

## Features

- **Actor Search**: Search for actors with autocomplete suggestions and input validation
- **Timeline Visualization**: View filmographies organized by year in a vertical timeline
- **Shared Movies Highlighting**: Common movies between actors are highlighted in red
- **Responsive Design**: Works on desktop and mobile devices with optimized performance
- **TMDB Integration**: Uses The Movie Database API with circuit breaker resilience
- **Production Security**: Rate limiting, CORS protection, input sanitization, and security headers
- **Redis Caching**: High-performance caching with connection pooling
- **Monitoring**: Structured logging, error tracking (Sentry for backend and frontend), and health checks
- **CI/CD Ready**: Comprehensive test suite and automated deployment

## Prerequisites

- Ruby 3.0+ installed
- Bundler gem installed (`gem install bundler`)
- Redis server (for production caching)

## Quick Setup

1. **Clone and Install Dependencies**:
   ```bash
   git clone <repository-url>
   cd movie_together
   bundle install
   ```

2. **Configure Environment**:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and add your configuration:
   ```
   TMDB_API_KEY=your_tmdb_api_key_here
   SENTRY_DSN=your_sentry_dsn_here (optional)
   REDIS_URL=redis://localhost:6379 (production)
   ```

3. **Get API Keys**:
   - **TMDB API**: Visit [TMDB API](https://www.themoviedb.org/settings/api) for film data
   - **Sentry** (optional): Visit [Sentry](https://sentry.io) for error tracking

4. **Run the Application**:
   ```bash
   # Development with auto-reload
   bundle exec rerun ruby app.rb
   
   # Production
   bundle exec puma
   ```

5. **Open in Browser**: `http://localhost:4567`

## Architecture

ActorSync features a resilient, production-ready architecture:

### Core Services
- **TMDBService**: API integration with caching and standardized error handling
- **ResilientTMDBClient**: Circuit breaker pattern for API resilience
- **ActorComparisonService**: Timeline generation and movie analysis
- **TimelineBuilder**: Performance-optimized timeline rendering
- **SimpleRequestThrottler**: Synchronous request rate limiting without threading
- **CacheCleaner**: Background service for automatic TTL-based cache cleanup
- **ConfigurationPolicy**: Policy-based configuration management with validation
- **ConfigurationValidator**: Environment variable validation with type checking

### Security & Performance
- **Rate Limiting**: Rack::Attack with Redis backend
- **Input Validation**: Comprehensive sanitization for all user inputs
- **Security Headers**: CSP, HSTS, X-Frame-Options, and more
- **CORS Protection**: Environment-based origin allowlisting
- **Caching**: Redis with connection pooling (production) / Memory (development) with automatic TTL cleanup

### Monitoring & Reliability
- **Circuit Breaker**: Automatic API failure handling
- **Structured Logging**: Comprehensive request/error tracking
- **Health Checks**: `/health/simple` and `/health/complete` endpoints
- **Error Tracking**: Sentry integration for production monitoring

## Project Structure

```
actorsync/
├── app.rb                     # Main Sinatra application
├── config.ru                 # Rack configuration  
├── Gemfile                   # Ruby dependencies
├── render.yaml               # Render.com deployment config
├── lib/                      # Application services and logic
│   ├── services/             # Core business logic
│   │   ├── tmdb_service.rb           # TMDB API integration
│   │   ├── resilient_tmdb_client.rb  # Circuit breaker client
│   │   ├── actor_comparison_service.rb # Timeline comparison
│   │   ├── timeline_builder.rb       # Performance-optimized rendering
│   │   ├── cache_cleaner.rb          # Background service for TTL cache cleanup
│   │   ├── simple_request_throttler.rb # Synchronous request throttling
│   │   ├── input_sanitizer.rb        # Centralized input sanitization
│   │   ├── api_response_builder.rb   # Standardized API response formatting
│   │   ├── cache_manager.rb          # Centralized cache operations
│   │   └── cache_key_builder.rb      # Standardized cache key generation
│   ├── controllers/          # Request handlers
│   │   ├── api_controller.rb         # API routes with CORS
│   │   ├── api_handlers.rb           # Input validation & processing
│   │   ├── health_controller.rb      # Health check endpoints
│   │   ├── error_handler.rb          # Application-wide error handling
│   │   ├── error_handler_tmdb.rb     # TMDB-specific error handlers
│   │   └── input_validator.rb        # Input validation service
│   ├── config/               # Configuration and utilities
│   │   ├── cache.rb                  # Redis/Memory cache abstraction
│   │   ├── logger.rb                 # Structured logging
│   │   ├── errors.rb                 # Custom error classes with hierarchy
│   │   ├── service_container.rb      # Dependency injection container
│   │   ├── service_initializer.rb    # Service registration and initialization
│   │   ├── configuration_policy.rb   # Policy-based configuration system
│   │   ├── configuration_validator.rb # Environment variable validation
│   │   └── request_context.rb        # Thread-local request context management
│   ├── dto/                  # Data Transfer Objects
│   │   ├── base_dto.rb               # Base DTO with validation and serialization
│   │   ├── actor_dto.rb              # Actor data structure
│   │   ├── movie_dto.rb              # Movie data structure
│   │   ├── search_results_dto.rb     # Search results wrapper
│   │   ├── comparison_result_dto.rb  # Timeline comparison results
│   │   ├── actor_search_request.rb   # Search request validation
│   │   ├── actor_comparison_request.rb # Comparison request validation
│   │   └── dto_factory.rb            # DTO creation from API responses
│   └── middleware/           # Request processing
│       ├── request_logger.rb         # Request/response logging
│       ├── performance_headers.rb    # Caching optimization
│       ├── error_handler_module.rb   # Standardized error handling patterns
│       └── request_context_middleware.rb # Request lifecycle tracking
├── views/                    # ERB templates
│   ├── layout.erb            # Main layout with security headers
│   ├── index.erb             # Home page
│   ├── suggestions.erb       # Actor search suggestions
│   └── timeline.erb          # Timeline visualization
├── public/                   # Static assets
│   ├── css/                  # Modular CSS architecture
│   │   ├── main.css          # Main entry point and imports
│   │   ├── base/             # Foundation styles (reset, variables, typography)
│   │   ├── components/       # Component-specific styles
│   │   ├── utilities/        # Utility classes and animations
│   │   ├── responsive.css    # Responsive breakpoints
│   │   └── modern-ui.css     # Modern UI enhancements
│   ├── js/                   # JavaScript modules
│   │   ├── app.js            # Main application initialization
│   │   └── modules/          # Modular JavaScript components
│   └── errors/               # Custom error pages
├── spec/                     # RSpec test suite (441 examples, 0 failures)
│   ├── lib/                  # Service and component tests
│   ├── requests/             # API integration tests
│   └── support/              # Test helpers and mocks
├── features/                 # Cucumber end-to-end tests
│   ├── step_definitions/     # Test step implementations
│   ├── support/              # Test configuration and helpers
│   └── *.feature             # Feature specifications
├── config/                   # Configuration files
│   ├── rack_attack.rb        # Rate limiting configuration
│   └── sentry.rb             # Error tracking setup
└── docs/                     # Documentation
    ├── SECURITY.md           # Security implementation details
    ├── ARCHITECTURE.md       # Technical architecture guide
    ├── DEPLOYMENT.md         # Production deployment guide
    └── TESTING.md            # Test suite documentation
```

## API Endpoints

### Core Application
- `GET /` - Main application page
- `GET /health/simple` - Basic health check (for load balancers)
- `GET /health/complete` - Comprehensive health check with dependencies

### Actor Search & Comparison API
- `GET /api/actors/search?q=query&field=actor1` - Search actors with validation
- `GET /api/actors/:id/movies` - Get actor filmography
- `GET /api/actors/compare?actor1_id=123&actor2_id=456&actor1_name=Name1&actor2_name=Name2` - Timeline comparison

All API endpoints include:
- Rate limiting (30-120 requests/minute depending on endpoint)
- Input validation and sanitization
- CORS headers
- Security headers
- Structured error responses

## Development

### Running Tests
```bash
# Run all tests (RSpec + Cucumber)
make test

# Run RSpec unit/integration tests only
make test-rspec
# or
bundle exec rspec

# Run Cucumber end-to-end tests only
make test-cucumber
# or
bundle exec cucumber

# Run with coverage
bundle exec rspec --format documentation

# Test production endpoints
make prod-test
# or with verbose output
make prod-test-verbose

# Run specific RSpec test file
bundle exec rspec spec/requests/api_spec.rb

# Run specific Cucumber feature
bundle exec cucumber features/actor_comparison.feature
```

### Code Quality
```bash
# Check code style
bundle exec rubocop

# Auto-fix style issues
bundle exec rubocop -A

# Security scan
bundle exec brakeman

# Dependency security scan
bundle exec bundle-audit
```

### Development Server
```bash
# Auto-reloading development server
bundle exec rerun ruby app.rb

# Manual restart
bundle exec ruby app.rb
```

## Production Deployment

MovieTogether is production-ready with automated CI/CD pipeline:

### Automated Deployment Pipeline (GitHub Actions + Kamal)

The application features a complete CI/CD workflow that:

1. **Continuous Integration** - Every push/PR
   - Runs 487+ RSpec unit & integration tests
   - Runs 7 Cucumber end-to-end tests
   - Security scans (Brakeman, Bundle Audit)
   - RuboCop code quality checks

2. **Continuous Deployment** - On merge to main
   - Builds Docker image and pushes to GitHub Container Registry
   - Deploys via Kamal to DigitalOcean VPS
   - Requires manual approval (GitHub Environment)
   - Auto-rollback on deployment failure
   - Slack notifications

See `CI_CD_SETUP.md` for complete setup and `DEPLOYMENT.md` for detailed instructions.

### Infrastructure Requirements
- **Ruby 3.0+** runtime
- **Redis** for caching and rate limiting
- **Reverse proxy** (Traefik) for HTTPS termination and routing
- **Docker** for containerization

### Environment Variables
```bash
# Required
RACK_ENV=production
TMDB_API_KEY=your_tmdb_api_key

# Recommended
SENTRY_DSN=your_sentry_dsn
REDIS_URL=redis://localhost:6379
REDIS_POOL_SIZE=15
ALLOWED_ORIGINS=https://yourdomain.com
SESSION_SECRET=your_session_secret

# Optional
CDN_BASE_URL=https://cdn.yourdomain.com
CDN_PROVIDER=cloudflare
```

See `DEPLOYMENT.md` for detailed production setup instructions.

## Security Features

ActorSync implements comprehensive security hardening:

### Input Protection
- **Query Sanitization**: Removes dangerous characters while preserving international names
- **Parameter Validation**: Type checking and range limits for all inputs
- **Field Whitelisting**: Only approved field names accepted

### Request Protection  
- **Per-Client Throttling**: Individual client rate limiting by method
- **Rate Limiting**: Tiered limits by endpoint complexity
- **CORS Policy**: Environment-based origin restrictions
- **User Agent Filtering**: Blocks suspicious bots and scrapers

### Response Security
- **Security Headers**: CSP, HSTS, X-Frame-Options, X-XSS-Protection
- **Content Validation**: All responses include security headers
- **HTTPS Enforcement**: Automatic redirection in production

See `SECURITY.md` for complete security implementation details.

## Technology Stack

### Backend
- **Ruby 3.0+** with Sinatra framework
- **Redis** for high-performance caching
- **Puma** web server for production
- **Circuit Breaker** pattern for API resilience

### Frontend  
- **HTMX** for dynamic interactions without JavaScript
- **Modular CSS Architecture** with ITCSS methodology and design system
- **ERB** templating with security-focused layouts

### CSS Architecture
- **ITCSS Methodology** for scalable, maintainable stylesheets
- **Design System** with CSS custom properties for theming
- **Component-Based** organization with clear separation of concerns
- **Utility-First** approach with helper classes for common patterns
- **Responsive Design** with mobile-first approach
- **Performance Optimized** with minimal specificity and efficient selectors
- **Theme Support** with light/dark mode capability
- **Modern Features** including CSS Grid, Custom Properties, and animations

### External Services
- **TMDB API v3** for movie data
- **Sentry** for error tracking and monitoring
- **Render.com** for hosting (Redis included)

### Development & Testing
- **RSpec** test framework (441 examples, 0 failures) for unit/integration tests
- **Cucumber** for end-to-end browser simulation tests
- **VCR** for reliable API testing in both RSpec and Cucumber
- **WebMock** for API mocking in tests
- **RuboCop** for code quality
- **Brakeman** for security scanning
- **SimpleCov** for test coverage

## Performance

- **Sub-second response times** with Redis caching
- **80% API call reduction** through intelligent caching
- **Circuit breaker protection** prevents cascade failures
- **Connection pooling** for database efficiency
- **Gzip compression** for reduced bandwidth
- **Performance headers** for browser caching

## Monitoring

### Health Checks
- `/health/simple` - Basic uptime check
- `/health/complete` - Full dependency validation

### Logging
- **Structured JSON logging** for all requests
- **Performance metrics** for response times
- **Error tracking** with full context
- **Cache performance** monitoring

### Alerting
- **Sentry integration** for error notifications
- **Circuit breaker** status monitoring
- **Rate limiting** threshold alerts

## TMDB API Compliance

This application uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.

**Important**: This is a non-commercial personal project. For commercial use, you must obtain a commercial agreement with TMDB.

### Commercial Use Requirements
According to TMDB terms, the following require a commercial license:
- Adding advertising or monetization
- Charging user fees or subscriptions  
- Generating revenue through the application
- Using TMDB content for commercial recommendations

**Terms of Use**: Review [TMDB API Terms](https://www.themoviedb.org/api-terms-of-use) before deployment.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `bundle exec rspec`
5. Check code style: `bundle exec rubocop -A`
6. Submit a pull request

## License

MIT License

**Note**: While this code is MIT licensed, the TMDB API has its own terms of use that must be followed when using the application.