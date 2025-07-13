# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ActorSync is a production-ready web application for comparing actor filmographies in a timeline format. Built with a resilient Ruby/Sinatra backend, HTMX frontend, and comprehensive security hardening.

## Architecture

- **Backend**: Ruby with Sinatra framework + Resilient Service Layer
- **Frontend**: HTMX for dynamic interactions (no JavaScript framework)
- **Caching**: Redis (production) / Memory (development) with connection pooling
- **Security**: Comprehensive hardening (rate limiting, input validation, security headers)
- **Monitoring**: Structured logging, Sentry error tracking, health checks
- **Testing**: RSpec test suite (68 examples, 0 failures)
- **Deployment**: Render.com with automated CI/CD

## Development Commands

- **Install dependencies**: `bundle install`
- **Run development server**: `bundle exec rerun ruby app.rb`
- **Run production server**: `bundle exec puma`
- **Test suite**: `bundle exec rspec`
- **Test with coverage**: `bundle exec rspec --format documentation`
- **Code style**: `bundle exec rubocop -A`
- **Security scan**: `bundle exec brakeman`
- **Dependency audit**: `bundle exec bundle-audit`

## Project Structure

```
actorsync/
├── app.rb                     # Main Sinatra application with security middleware
├── config.ru                 # Rack configuration
├── Gemfile                   # Ruby dependencies (Redis, Sentry, security gems)
├── render.yaml               # Production deployment configuration
├── lib/                      # Application logic
│   ├── services/             # Core business logic
│   │   ├── resilient_tmdb_client.rb  # Circuit breaker API client
│   │   ├── tmdb_service.rb           # TMDB API integration with caching
│   │   ├── actor_comparison_service.rb # Timeline comparison logic
│   │   └── timeline_builder.rb       # Performance-optimized rendering
│   ├── controllers/          # Request handling
│   │   ├── api_controller.rb         # API routes with CORS and security
│   │   ├── api_handlers.rb           # Input validation and processing
│   │   └── health_controller.rb      # Health check endpoints
│   ├── config/               # Configuration and utilities
│   │   ├── cache.rb                  # Redis/Memory cache abstraction
│   │   ├── logger.rb                 # Structured JSON logging
│   │   └── errors.rb                 # Custom error classes
│   └── middleware/           # Request processing pipeline
│       ├── request_logger.rb         # Request/response logging
│       └── performance_headers.rb    # Caching optimization headers
├── spec/                     # Test suite (68 examples, 0 failures)
│   ├── lib/                  # Unit tests for services and components
│   ├── requests/             # Integration tests for API endpoints
│   └── support/              # Test helpers and mocking utilities
├── config/                   # Configuration files
│   ├── rack_attack.rb        # Rate limiting rules and security
│   └── sentry.rb             # Error tracking and monitoring setup
├── views/                    # ERB templates
│   ├── layout.erb            # Security-hardened main layout
│   ├── index.erb             # Actor search interface
│   ├── suggestions.erb       # Search suggestion partial
│   └── timeline.erb          # Timeline visualization
├── public/                   # Static assets
│   └── styles.css            # Modern responsive CSS
└── docs/                     # Comprehensive documentation
    ├── SECURITY.md           # Security implementation details
    ├── ARCHITECTURE.md       # Technical architecture guide
    ├── DEPLOYMENT.md         # Production deployment guide
    └── TESTING.md            # Test suite documentation
```

## Key Development Notes

### Security Implementation
- **Input Validation**: All user inputs sanitized and validated
- **Rate Limiting**: Rack::Attack with Redis backend (30-120 req/min)
- **Security Headers**: CSP, HSTS, X-Frame-Options, X-XSS-Protection
- **CORS**: Environment-based origin restrictions
- **HTTPS**: Enforced in production with Rack::SSL

### Caching Strategy
- **Redis**: Production caching with connection pooling
- **Memory**: Development caching for local testing
- **TTL Management**: Intelligent cache expiration (5-30 minutes)
- **Cache Keys**: MD5-hashed for consistency and security

### Error Handling
- **Circuit Breaker**: ResilientTMDBClient prevents cascade failures
- **Structured Logging**: JSON logs with context and performance metrics
- **Sentry Integration**: Real-time error tracking and monitoring
- **Graceful Degradation**: Fallback responses for API failures

### Testing Infrastructure
- **RSpec Framework**: 68 examples with 100% pass rate
- **Test Coverage**: Unit tests, integration tests, security tests
- **Mocking**: WebMock for external API testing
- **Test Data**: FactoryBot for consistent test fixtures

## Environment Configuration

### Required Environment Variables
```bash
# Core configuration
TMDB_API_KEY=your_tmdb_api_key_here
RACK_ENV=development|production

# Production configuration
REDIS_URL=redis://localhost:6379
SENTRY_DSN=your_sentry_dsn_here
ALLOWED_ORIGINS=https://yourdomain.com

# Optional configuration
REDIS_POOL_SIZE=15
REDIS_POOL_TIMEOUT=5
CDN_BASE_URL=https://cdn.yourdomain.com
```

### Development Setup
1. `cp .env.example .env`
2. Add your TMDB API key to `.env`
3. `bundle install`
4. `bundle exec rerun ruby app.rb`

## Production Readiness

### Current Status: Production Ready ✅
- **Security**: Comprehensive hardening complete
- **Infrastructure**: Redis, health checks, monitoring
- **Testing**: 68 examples, 0 failures
- **Code Quality**: RuboCop compliant, Brakeman secure
- **Performance**: Sub-second response times with caching
- **Monitoring**: Sentry integration, structured logging
- **Deployment**: Render.com configuration ready

### Key Features
- Circuit breaker pattern for API resilience
- Rate limiting with Redis persistence
- Input validation and sanitization
- Security headers and CORS protection
- Structured logging and error tracking
- Health check endpoints for monitoring
- Performance optimization with caching

## API Endpoints

### Core Application
- `GET /` - Main application interface
- `GET /health/simple` - Basic health check
- `GET /health/complete` - Comprehensive dependency check

### Actor Search & Comparison API
- `GET /api/actors/search?q=query&field=actor1` - Search actors with validation
- `GET /api/actors/:id/movies` - Get actor filmography
- `GET /api/actors/compare?actor1_id=123&actor2_id=456` - Timeline comparison

All endpoints include:
- Rate limiting protection
- Input validation and sanitization
- CORS headers for browser compatibility
- Security headers for protection
- Structured error responses

## Performance Characteristics

- **Response Time**: Sub-second with Redis caching
- **API Efficiency**: 80% reduction in external API calls
- **Cache Hit Rate**: Optimized TTL for different data types
- **Error Rate**: <0.1% with circuit breaker protection
- **Scalability**: Connection pooling and stateless design

## Development Workflow

### Code Quality Standards
1. All tests must pass: `bundle exec rspec`
2. Code style compliance: `bundle exec rubocop -A`
3. Security scan clean: `bundle exec brakeman`
4. No dependency vulnerabilities: `bundle exec bundle-audit`
5. Doppler environment variables up-to-date: `ruby scripts/check_doppler_environments.rb`

### Git Workflow
- Feature branches with descriptive names
- Clean commit history with logical separation
- Conventional commit format recommended
- Include Claude Code attribution in commits
- Comprehensive testing before merge

### Deployment Process
1. Tests pass locally and in CI
2. Security scans complete successfully  
3. Code review and approval
4. Merge to main branch
5. Automatic deployment to Render.com

## Project Context & Documentation

### Comprehensive Documentation Available
- **README.md**: Complete project overview and setup
- **CONTEXT.md**: Current status and architecture decisions
- **SECURITY.md**: Detailed security implementation
- **ARCHITECTURE.md**: Technical architecture and design patterns
- **DEPLOYMENT.md**: Production deployment guide
- **TESTING.md**: Test suite documentation and guidelines
- **PRODUCTION_READINESS_CHECKLIST.md**: Deployment readiness tracking

### Key Resources
- All documentation is up-to-date with current implementation
- Test suite provides comprehensive coverage examples
- Security implementation serves as reference for best practices
- Architecture documentation explains design decisions

## Important Development Principles

1. **Security First**: All features implemented with security considerations
2. **Test-Driven**: Comprehensive test coverage for reliability
3. **Performance Aware**: Caching and optimization built-in
4. **Monitoring Ready**: Structured logging and error tracking
5. **Production Ready**: All code meets production standards
6. **Documentation Complete**: Implementation fully documented

---

*This file reflects the current production-ready state of ActorSync as of 2025-07-13*