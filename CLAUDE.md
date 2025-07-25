# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MovieTogether is a production-ready web application for comparing actor filmographies in a timeline format. Built with a resilient Ruby/Sinatra backend, HTMX frontend, and comprehensive security hardening.

## Architecture

- **Backend**: Ruby with Sinatra framework + Resilient Service Layer
- **Frontend**: HTMX for dynamic interactions with comprehensive error handling
- **Caching**: Redis (production) / Memory (development) with connection pooling
- **Security**: Comprehensive hardening (rate limiting, input validation, security headers)
- **Monitoring**: Structured logging, Sentry error tracking, health checks
- **Testing**: RSpec test suite (441 examples) + Cucumber browser tests
- **Deployment**: Render.com with automated CI/CD

## Development Commands

### Quick Start (Recommended)
- **Start development**: `make dev` or `./scripts/dev`
- **Run tests**: `make test`
- **Code style**: `make lint`
- **Security scan**: `make security`
- **Environment validation**: `make validate-env`
- **Check outdated gems**: `make check-outdated`

### Manual Commands
- **Install dependencies**: `bundle install`
- **Run development server**: `./scripts/server` (auto-restart on file changes)
- **Run production server**: `bundle exec puma`
- **Test suite**: `bundle exec rspec`
- **Test with coverage**: `bundle exec rspec --format documentation`
- **Code style**: `bundle exec rubocop -A`
- **Security scan**: `bundle exec brakeman`
- **Dependency audit**: `bundle exec bundle-audit`

## Project Structure

```
movie_together/
├── app.rb                     # Main Sinatra application with security middleware
├── config.ru                 # Rack configuration
├── Gemfile                   # Ruby dependencies (Redis, Sentry, security gems)
├── render.yaml               # Production deployment configuration
├── lib/                      # Application logic
│   ├── services/             # Core business logic
│   │   ├── resilient_tmdb_client.rb  # Circuit breaker API client
│   │   ├── tmdb_service.rb           # TMDB API integration with caching
│   │   ├── actor_comparison_service.rb # Timeline comparison logic (refactored)
│   │   ├── timeline_builder.rb       # Performance-optimized rendering
│   │   ├── cache_cleaner.rb          # Background service for TTL cache cleanup
│   │   ├── request_throttler.rb       # Per-client request throttling
│   │   ├── input_sanitizer.rb        # Centralized input sanitization
│   │   ├── api_response_builder.rb   # Standardized API response formatting
│   │   ├── cache_manager.rb          # Centralized cache operations
│   │   ├── cache_key_builder.rb      # Standardized cache key generation
│   │   └── tmdb_fallback_provider.rb # Centralized fallback response provider
│   ├── controllers/          # Request handling
│   │   ├── api_controller.rb         # API routes with CORS and security
│   │   ├── api_handlers.rb           # Input validation and processing
│   │   ├── health_controller.rb      # Health check endpoints
│   │   ├── error_handler.rb          # Application-wide error handling
│   │   └── error_handler_tmdb.rb     # TMDB-specific error handlers
│   ├── config/               # Configuration and utilities
│   │   ├── cache.rb                  # Redis/Memory cache abstraction
│   │   ├── logger.rb                 # Structured JSON logging
│   │   ├── errors.rb                 # Custom error classes with hierarchy
│   │   ├── service_container.rb      # Dependency injection container
│   │   ├── service_initializer.rb    # Service registration and configuration
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
│   │   ├── dto_factory.rb            # DTO creation from API responses
│   │   └── health_check_result.rb    # Health check parameter object
│   └── middleware/           # Request processing pipeline
│       ├── request_logger.rb         # Request/response logging
│       ├── performance_headers.rb    # Caching optimization headers
│       ├── error_handler_module.rb   # Standardized error handling patterns
│       └── request_context_middleware.rb # Request lifecycle tracking
├── spec/                     # Test suite (441 examples, 0 failures)
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
│   ├── css/                  # Modular CSS architecture (ITCSS methodology)
│   │   ├── main.css          # Main entry point and imports
│   │   ├── base/             # Foundation styles
│   │   │   ├── reset.css     # Modern CSS reset
│   │   │   ├── variables.css # CSS custom properties & design tokens
│   │   │   └── typography.css # Typography system
│   │   ├── components/       # Component-specific styles
│   │   │   ├── header.css    # Header component
│   │   │   ├── search.css    # Search functionality
│   │   │   ├── timeline.css   # Timeline visualization
│   │   │   ├── movies.css    # Movie cards and lists
│   │   │   ├── loading.css   # Loading states
│   │   │   ├── footer.css    # Footer component
│   │   │   ├── actor-portrait.css # Actor portrait styling
│   │   │   └── mdc-overrides.css # Material Design overrides
│   │   ├── utilities/        # Utility classes and animations
│   │   │   ├── helpers.css   # Utility classes for common patterns
│   │   │   ├── animations.css # Animation keyframes and classes
│   │   │   └── performance.css # Performance optimization utilities
│   │   ├── responsive.css    # Responsive breakpoints and media queries
│   │   ├── modern-ui.css     # Modern UI enhancements
│   │   └── themes/           # Theme support (light/dark mode)
│   └── js/                   # JavaScript modules
│       ├── app.js            # Main application initialization
│       └── modules/          # Modular JavaScript components
│           ├── error-reporter.js    # Frontend error handling and reporting
│           ├── snackbar.js          # User notification system
│           ├── scroll-to-top.js     # Scroll behavior
│           ├── dom-manager.js       # DOM manipulation utilities
│           ├── event-manager.js     # Event handling and delegation
│           ├── analytics-tracker.js # Analytics tracking wrapper
│           ├── field-manager.js     # Form field state management
│           └── actor-search.js      # Actor search functionality (refactored)
└── docs/                     # Comprehensive documentation
    ├── SECURITY.md           # Security implementation details
    ├── ARCHITECTURE.md       # Technical architecture guide
    ├── DEPLOYMENT.md         # Production deployment guide
    └── TESTING.md            # Test suite documentation
```

## Key Development Notes

### Data Transfer Objects (DTOs)
- **Type Safety**: Structured data objects with validation and serialization
- **API Consistency**: Standardized request/response formats across all endpoints
- **Validation**: Built-in input validation with clear error messages
- **Backward Compatibility**: Maintains compatibility with legacy hash-based systems
- **Factory Pattern**: DTOFactory converts API responses to typed objects
- **Dependency Injection**: ServiceContainer manages service lifecycle and dependencies

### Security Implementation
- **Input Validation**: All user inputs sanitized and validated
- **Rate Limiting**: Rack::Attack with Redis backend (30-120 req/min) + per-client throttling
- **Security Headers**: CSP, HSTS, X-Frame-Options, X-XSS-Protection
- **CORS**: Environment-based origin restrictions
- **HTTPS**: Enforced in production with Rack::SSL

### Caching Strategy
- **Redis**: Production caching with connection pooling
- **Memory**: Development caching for local testing
- **TTL Management**: Intelligent cache expiration (5-30 minutes) with automatic cleanup
- **Cache Keys**: MD5-hashed for consistency and security

### CSS Architecture & Design System
- **ITCSS Methodology**: Inverted Triangle CSS for scalable, maintainable stylesheets
- **Component-Based Organization**: Clear separation of concerns with isolated component styles
- **Design System**: CSS custom properties for theming, colors, spacing, and transitions
- **Utility-First Approach**: Helper classes for common patterns and rapid development
- **Performance Optimized**: Minimal specificity, efficient selectors, and optimized loading
- **Responsive Design**: Mobile-first approach with progressive enhancement
- **Theme Support**: Light/dark mode capability with CSS custom properties
- **Modern CSS Features**: CSS Grid, Custom Properties, animations, and modern selectors

### Architecture Patterns
### Configuration Management
- **Policy-Based Configuration**: ConfigurationPolicy defines validation rules and default values
- **Type-Safe Validation**: ConfigurationValidator ensures environment variables meet type and format requirements
- **Centralized Policies**: All configuration rules defined in one place for consistency
- **Runtime Validation**: Configuration validated at startup with clear error messages

- **Dependency Injection**: ServiceContainer manages service initialization and dependencies
- **Service Registration**: Centralized service configuration in ServiceInitializer
- **Response Standardization**: ApiResponseBuilder ensures consistent API responses
- **Error Handling Module**: Consistent error handling patterns with typed exceptions
- **Parameter Objects**: HealthCheckResult reduces method parameters in health checks
- **Fallback Provider**: TMDBFallbackProvider centralizes API fallback responses

### Error Handling
- **Standardized Error Types**: Specific error classes for different failure scenarios (TMDBTimeoutError, TMDBAuthError, TMDBRateLimitError, TMDBNotFoundError, TMDBServiceError)
- **Error Handling Module**: Consistent error handling patterns with `with_error_handling`, `with_tmdb_error_handling`, and `with_cache_error_handling` methods
- **Circuit Breaker**: ResilientTMDBClient prevents cascade failures
- **Structured Logging**: JSON logs with context and performance metrics
- **Sentry Integration**: Real-time error tracking and monitoring
- **Graceful Degradation**: Fallback responses for API failures and cache errors

### Testing Infrastructure
- **RSpec Framework**: 441 unit and integration tests (100% passing)
- **Cucumber Framework**: 12 end-to-end browser simulation scenarios (100% passing)
- **VCR Integration**: Dual-mode cassette system (record in dev, playback in CI)
- **Test Coverage**: 77.3% line coverage with comprehensive unit, integration, and E2E tests
- **Mocking**: WebMock for external API testing, VCR for consistent API responses
- **Test Data**: FactoryBot for consistent test fixtures
- **DTO Testing**: Comprehensive validation, serialization, and factory pattern tests

### Dependency Management
- **Version Pinning**: All gems pinned to exact versions for production stability
- **Security Monitoring**: Automated scanning with brakeman and bundle-audit
- **Update Strategy**: Intentional updates with thorough testing
- **Documentation**: Comprehensive gem management guide (GEM_MANAGEMENT.md)

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

#### Option 1: Doppler (Recommended)
1. Install Doppler CLI: `brew install doppler` or visit [docs.doppler.com](https://docs.doppler.com/docs/install-cli)
2. Login: `doppler login`
3. Setup project: `doppler setup`
4. Start development: `make dev`

#### Option 2: .env File (Fallback)
1. `cp .env.example .env`
2. Add your TMDB API key to `.env`
3. `bundle install`
4. `bundle exec rerun ruby app.rb`

### Production Deployment with Doppler

**IMPORTANT**: This project uses Doppler for environment variable management in production.

1. **Doppler Integration**: Environment variables (TMDB_API_KEY, SENTRY_DSN, etc.) are synced from Doppler
2. **render.yaml Configuration**: Do NOT define sensitive variables in render.yaml - they will be overridden by Doppler
3. **Render.com Setup**: 
   - Connect Doppler to your Render service via the Render dashboard
   - Go to Environment → Sync with Doppler
   - Select your Doppler project and config (usually "prd" for production)
4. **Variables managed by Doppler**:
   - `TMDB_API_KEY` - The Movie Database API key
   - `SENTRY_DSN` - Error tracking configuration
   - Any other sensitive configuration

#### Environment Validation
The application includes comprehensive environment validation that will:
- ✅ Check for required environment variables (TMDB_API_KEY)
- ⚠️  Warn about missing optional variables (PostHog, Sentry, Redis)
- 🛑 Fail fast in development if critical variables are missing
- 🔐 Automatically detect and prefer Doppler over .env files

## Production Readiness

### Current Status: Production Ready ✅
- **Security**: Comprehensive hardening complete
- **Infrastructure**: Redis, health checks, monitoring
- **Testing**: RSpec (441 examples) + Cucumber E2E tests
- **Code Quality**: RuboCop compliant, Brakeman secure
- **Performance**: Sub-second response times with caching
- **Monitoring**: Sentry integration, structured logging
- **Deployment**: Render.com configuration ready with CI/CD

### Key Features
- Circuit breaker pattern for API resilience
- Data Transfer Objects (DTOs) for type safety and validation
- Dependency injection with service container
- Rate limiting with Redis persistence and SimpleRequestThrottler (no threading issues)
- Input validation and sanitization
- Security headers and CORS protection
- Policy-based configuration management with validation
- Structured logging and error tracking
- Health check endpoints for monitoring with Git SHA tracking
- Performance optimization with caching
- Production testing script for deployment verification

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
5. **Documentation must be updated**: Update all affected .md files (README, CLAUDE, CONTEXT, etc.) to reflect code changes
6. Doppler environment variables up-to-date: `ruby scripts/check_doppler_environments.rb`

**IMPORTANT**: Documentation updates are MANDATORY for all code changes. This includes:
- Updating test counts when tests are added/removed
- Updating file structure sections when files are added/moved/deleted
- Updating feature descriptions when functionality changes
- Updating configuration sections when settings change

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

*This file reflects the current production-ready state of MovieTogether as of 2025-07-14*
