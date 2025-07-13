# ActorSync Refactoring Plan

Comprehensive plan to optimize, refactor, and improve code maintainability while preserving production stability.

## 🚨 **Phase 1: High Priority - Immediate Impact**

### 1. Consolidate Cache Management Patterns
**Problem**: Cache logic scattered across services with duplication
- TMDBService, ActorComparisonService both implement own caching
- Duplicated cache key generation logic
- N+1 cache queries in ActorComparisonService
- Manual cache-check-fetch-store pattern repeated everywhere

**Current Issues**:
- `get_actor_profile` and `get_actor_name` make separate cache calls
- Cache TTL values hardcoded in multiple places
- No consistent cache key generation strategy
- Memory cache doesn't implement TTL cleanup

**Solution**: Create centralized CacheManager
```ruby
class CacheManager
  def fetch(key, ttl = 300, &block)
    Cache.fetch(key, ttl, &block)
  end
  
  def fetch_multi(keys, ttl = 300, &block)
    # Batch cache operations
  end
  
  def invalidate(pattern)
    # Cache invalidation by pattern
  end
end

class CacheKeyBuilder
  def actor_profile(actor_id)
    "actor:profile:#{actor_id}"
  end
  
  def search_results(query)
    "search:#{Digest::MD5.hexdigest(query)}"
  end
end
```

**Files to modify**:
- `lib/services/tmdb_service.rb`
- `lib/services/actor_comparison_service.rb`
- `lib/config/cache.rb`
- Create `lib/services/cache_manager.rb`
- Create `lib/services/cache_key_builder.rb`

**Tests to update**:
- `spec/lib/services/tmdb_service_spec.rb`
- `spec/lib/services/actor_comparison_service_spec.rb`
- Create `spec/lib/services/cache_manager_spec.rb`

### 2. Split ApiHandlers into Focused Classes
**Problem**: ApiHandlers mixes concerns (input validation, business logic, rendering)
- Makes testing difficult
- Violates single responsibility principle
- Hard to maintain and extend

**Current Issues**:
- `handle_actor_search` does sanitization, validation, API calls, and rendering
- `handle_actor_movies` duplicates similar patterns
- `handle_actor_comparison` has complex logic mixed with presentation

**Solution**: Split into separate classes
```ruby
class InputValidator
  def validate_actor_search(params)
    # Sanitization and validation logic
  end
  
  def validate_actor_id(id)
    # Actor ID validation
  end
end

class ApiRenderer
  def render_suggestions(actors, field)
    # ERB rendering logic
  end
  
  def render_timeline(comparison_data)
    # Timeline rendering
  end
end

class ApiBusinessLogic
  def search_actors(query)
    # Pure business logic
  end
  
  def compare_actors(actor1_id, actor2_id)
    # Actor comparison logic
  end
end
```

**Files to modify**:
- `lib/controllers/api_handlers.rb` (split into multiple files)
- Create `lib/services/input_validator.rb`
- Create `lib/services/api_renderer.rb`
- Create `lib/services/api_business_logic.rb`
- Update `app.rb` to use new classes

**Tests to create**:
- `spec/lib/services/input_validator_spec.rb`
- `spec/lib/services/api_renderer_spec.rb`
- `spec/lib/services/api_business_logic_spec.rb`

### 3. Standardize Error Handling Patterns
**Problem**: Inconsistent error handling across services
- Some methods return nil on error, others raise exceptions
- Generic `rescue StandardError` loses context
- Different logging patterns used

**Current Issues**:
- TMDBService sometimes returns `[]` on error, sometimes raises
- ResilientTMDBClient handles errors differently than TMDBService
- No specific exception types for different error conditions

**Solution**: Implement proper exception hierarchy
```ruby
class TMDBError < StandardError; end
class TMDBTimeoutError < TMDBError; end
class TMDBAuthError < TMDBError; end
class TMDBRateLimitError < TMDBError; end
class TMDBNotFoundError < TMDBError; end

module ErrorHandler
  def with_error_handling
    yield
  rescue Net::TimeoutError => e
    raise TMDBTimeoutError, e.message
  rescue TMDBAuthError => e
    handle_auth_error(e)
  rescue TMDBRateLimitError => e
    handle_rate_limit_error(e)
  end
end
```

**Files to modify**:
- `lib/config/errors.rb` (expand existing)
- `lib/services/tmdb_service.rb`
- `lib/services/resilient_tmdb_client.rb`
- `lib/services/actor_comparison_service.rb`
- `lib/controllers/api_handlers.rb`

**Tests to update**:
- All service specs to handle new exception types
- Add specific error condition tests

### 4. Create ApiResponseBuilder for Consistent Responses
**Problem**: Response building logic scattered across controllers
- Inconsistent error response formats
- No standard for success responses
- Hard to maintain API contract

**Current Issues**:
- Error responses formatted differently across endpoints
- Success responses have varying structures
- No metadata standards (pagination, etc.)

**Solution**: Centralized response builder
```ruby
class ApiResponseBuilder
  def success(data, meta: {})
    {
      status: 'success',
      data: data,
      meta: meta,
      timestamp: Time.current.iso8601
    }
  end
  
  def error(message, code: 400, details: {})
    {
      status: 'error',
      message: message,
      code: code,
      details: details,
      timestamp: Time.current.iso8601
    }
  end
  
  def render_erb(template, locals = {})
    # ERB rendering with consistent error handling
  end
end
```

**Files to modify**:
- Create `lib/services/api_response_builder.rb`
- `lib/controllers/api_handlers.rb`
- `lib/controllers/api_controller.rb`
- `app.rb` (main routes)

**Tests to create**:
- `spec/lib/services/api_response_builder_spec.rb`
- Update integration tests for consistent response format

## 🔧 **Phase 2: Architecture Improvements - Medium Priority**

### 5. Implement Dependency Injection Container
**Problem**: Services create dependencies inline, making testing difficult

**Solution**: Create service container for dependency management
```ruby
class ServiceContainer
  def initialize
    @services = {}
  end
  
  def register(name, service)
    @services[name] = service
  end
  
  def get(name)
    @services[name] ||= build_service(name)
  end
end
```

### 6. Simplify Complex Methods in TimelineBuilder
**Problem**: `process_movies_for_year` handles multiple responsibilities

**Solution**: Break into smaller, focused methods
```ruby
def process_movies_for_year(year)
  movies = collect_movies_for_year(year)
  return [] if movies.empty?
  
  sorted_movies = sort_movies_by_date(movies)
  group_shared_movies(sorted_movies)
end
```

### 7. Create InputSanitizer Service
**Problem**: Input sanitization logic duplicated across endpoints

**Solution**: Centralized, chainable sanitization
```ruby
class InputSanitizer
  def sanitize_query(query)
    query.to_s.strip.gsub(/[<>]/, '')
  end
  
  def validate_actor_id(id)
    id.to_i.clamp(1, 999_999_999)
  end
end
```

### 8. Implement CacheKeyBuilder (covered in Phase 1)

### 9. Add Frontend Error Handling
**Problem**: JavaScript errors not properly surfaced to users

**Solution**: Centralized error reporting
```javascript
class ErrorReporter {
  static report(error, context = {}) {
    // Send to Sentry, show user notification
  }
}
```

## 🎨 **Phase 3: Polish and Optimization - Low Priority**

### 10. Refactor JavaScript into Smaller Modules
**Problem**: ActorSearch class handles too many concerns (200+ lines)

**Solution**: Split into focused modules
```javascript
class DOMManager {
  // DOM manipulation only
}

class EventManager {
  // Event handling only
}

class ApiClient {
  // HTMX and API interactions
}
```

### 11. Implement Request Throttling
**Problem**: No centralized rate limiting strategy for TMDB API

**Solution**: RequestThrottler service with priority queuing

### 12. Add Cache TTL Cleanup
**Problem**: Memory cache stores expired entries indefinitely

**Solution**: Background cleanup task with LRU eviction

### 13. Create Configuration Policies
**Problem**: Configuration scattered across files

**Solution**: Centralized policy management
```ruby
class CachePolicy
  ACTOR_PROFILE_TTL = 30.minutes
  SEARCH_RESULTS_TTL = 5.minutes
  MOVIE_CREDITS_TTL = 10.minutes
end
```

### 14. Improve CSS Organization
**Problem**: Some CSS patterns could be more modular

**Solution**: Better component organization and utility classes

## 📋 **Implementation Guidelines**

### Before Starting Each Phase:
1. Run full test suite to ensure baseline
2. Create feature branch for changes
3. Update tests alongside implementation
4. Maintain 100% backward compatibility
5. Update documentation as needed

### Success Criteria:
- All tests continue passing
- No performance regressions
- Improved code maintainability metrics
- Reduced complexity in key methods
- Better separation of concerns

### Rollback Plan:
- Keep original implementations until new ones are fully tested
- Use feature flags for gradual rollout if needed
- Maintain git history for easy reverting

## 🎯 **Expected Outcomes**

### Phase 1 Completion:
- Centralized cache management
- Clean separation of API concerns
- Consistent error handling
- Standardized API responses
- Reduced code duplication

### Phase 2 Completion:
- Better testability through dependency injection
- Simplified complex methods
- Centralized input validation
- Improved frontend error handling

### Phase 3 Completion:
- Modular JavaScript architecture
- Optimized performance
- Better configuration management
- Clean CSS organization

---

*Created: 2025-07-13*
*Status: Ready for implementation*
*Priority: Phase 1 → Phase 2 → Phase 3*