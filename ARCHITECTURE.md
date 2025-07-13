# ActorSync Architecture Documentation

This document provides a comprehensive overview of ActorSync's production-ready architecture, design patterns, and implementation details.

## 🏗️ System Architecture Overview

ActorSync is built with a resilient, layered architecture that emphasizes security, performance, and maintainability:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend Layer                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   HTMX Client   │  │  Modern CSS     │  │  ERB Templates  │ │
│  │   Dynamic UI    │  │  Responsive     │  │  Server-side    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Security Middleware                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Rack::Attack   │  │   Rack::SSL     │  │ Rack::Protection│ │
│  │ Rate Limiting   │  │ HTTPS Enforce   │  │ Security Headers│ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Application Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ API Controllers │  │  Input Handlers │  │ Health Checks   │ │
│  │ CORS & Routing  │  │  Validation     │  │ Monitoring      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Service Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Resilient TMDB  │  │   TMDB Service  │  │ Comparison Svc  │ │
│  │ Circuit Breaker │  │   Caching       │  │ Timeline Logic  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Redis Cache    │  │ Structured Log  │  │ Error Tracking  │ │
│  │ Connection Pool │  │ Performance     │  │ Sentry Monitor  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      External Services                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   TMDB API      │  │   Sentry API    │  │   Redis Server  │ │
│  │  Movie Data     │  │ Error Tracking  │  │ Cache Storage   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🧩 Core Components

### 1. Frontend Layer

#### HTMX-Powered Dynamic UI
```erb
<!-- views/index.erb -->
<form hx-get="/api/actors/search" 
      hx-trigger="input changed delay:300ms"
      hx-target="#suggestions">
  <input type="text" name="q" placeholder="Search actors...">
</form>
```

**Key Features:**
- Server-side rendering with dynamic updates
- No JavaScript framework dependencies
- Progressive enhancement approach
- SEO-friendly implementation

#### Responsive CSS Architecture
```css
/* public/styles.css - Component-based structure */
:root {
  --primary-color: #1976d2;
  --spacing-unit: 8px;
  --border-radius: 4px;
}

.timeline-container {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--spacing-unit);
}

@media (max-width: 768px) {
  .timeline-container {
    grid-template-columns: 1fr;
  }
}
```

**Architecture Principles:**
- Mobile-first responsive design
- CSS custom properties for theming
- Component-based organization
- Performance-optimized loading

### 2. Security Middleware Stack

#### Rate Limiting (Rack::Attack)
```ruby
# config/rack_attack.rb
class Rack::Attack
  # Redis-backed rate limiting
  cache.store = Redis.new(url: ENV.fetch("REDIS_URL"))
  
  # Endpoint-specific throttling
  throttle("search/ip", limit: 60, period: 60) do |req|
    req.ip if req.path.start_with?("/api/actors/search")
  end
  
  throttle("compare/ip", limit: 30, period: 60) do |req|
    req.ip if req.path.start_with?("/api/actors/compare")
  end
end
```

**Security Features:**
- Redis persistence for distributed rate limiting
- Endpoint-specific limits based on computational cost
- IP-based throttling with development exemptions
- Custom error responses with retry headers

#### Input Validation Pipeline
```ruby
# lib/controllers/api_handlers.rb
class ApiHandlers
  def handle_actor_search
    query = sanitize_search_query(params[:q])
    field = sanitize_field_name(params[:field])
    
    return render_empty_suggestions(field) if query.nil? || query.empty?
    search_actors(query, field)
  end
  
  private
  
  def sanitize_search_query(query)
    return nil if query.nil?
    sanitized = query.to_s.strip
    return nil if sanitized.empty? || sanitized.length > 100
    sanitized.gsub(/[^\p{L}\p{N}\s'\-\.]/, "").strip
  end
end
```

**Validation Strategy:**
- Early validation at controller entry points
- Unicode-aware character filtering
- Length and format restrictions
- Fail-fast error handling

### 3. Application Layer

#### Controller Architecture
```ruby
# lib/controllers/api_controller.rb
module APIController
  module ClassMethods
    def api_routes
      namespace "/api" do
        before { configure_cors_headers }
        
        options "*" do
          response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
          response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
          200
        end
        
        get "/actors/search" { ApiHandlers.new(self).handle_actor_search }
        get "/actors/:id/movies" { ApiHandlers.new(self).handle_actor_movies }
        get "/actors/compare" { ApiHandlers.new(self).handle_actor_comparison }
      end
    end
  end
end
```

**Design Patterns:**
- Module-based controller organization
- Dependency injection for handlers
- CORS preflight handling
- Centralized error handling

#### Health Check System
```ruby
# lib/controllers/health_controller.rb
module HealthController
  def health_check_endpoint
    get "/health/complete" do
      health_status = HealthHandler.new(self).comprehensive_check
      status health_status[:status] == "healthy" ? 200 : 503
      content_type :json
      health_status.to_json
    end
    
    get "/health/simple" do
      content_type :json
      { status: "ok" }.to_json
    end
  end
end
```

**Health Check Features:**
- Comprehensive dependency validation
- Simple endpoint for load balancers
- Redis connectivity verification
- TMDB API health validation

### 4. Service Layer

#### Resilient TMDB Client
```ruby
# lib/services/resilient_tmdb_client.rb
class ResilientTMDBClient
  CIRCUIT_BREAKER_THRESHOLD = 5
  CIRCUIT_BREAKER_TIMEOUT = 60
  CIRCUIT_BREAKER_EXPECTED_ERRORS = [Net::OpenTimeout, Net::HTTPError, TMDBError].freeze
  
  def initialize(api_key)
    @api_key = api_key
    @circuit_breaker = SimpleCircuitBreaker.new(
      threshold: CIRCUIT_BREAKER_THRESHOLD,
      timeout: CIRCUIT_BREAKER_TIMEOUT,
      exceptions: CIRCUIT_BREAKER_EXPECTED_ERRORS
    )
  end
  
  def request(endpoint, params = {})
    @circuit_breaker.call do
      execute_with_retry(endpoint, params)
    end
  rescue SimpleCircuitBreaker::CircuitOpenError => e
    handle_circuit_open_error(endpoint, e)
  end
end
```

**Resilience Patterns:**
- Circuit breaker for automatic failure detection
- Exponential backoff retry mechanism
- Graceful degradation with fallback responses
- Performance monitoring and alerting

#### Caching Strategy
```ruby
# lib/services/tmdb_service.rb
class TMDBService
  def search_actors(query)
    cache_key = "actors:search:#{Digest::MD5.hexdigest(query.downcase)}"
    
    Cache.get(cache_key) || begin
      results = @client.request("search/person", query: query)
      processed = TMDBDataProcessor.process_actor_search_results(results)
      Cache.set(cache_key, processed, 1800) # 30 minutes
      processed
    end
  rescue StandardError => e
    StructuredLogger.error("Actor search failed", error: e.message, query: query)
    []
  end
end
```

**Caching Architecture:**
- Redis-backed persistent caching
- Intelligent cache key generation
- TTL optimization for different data types
- Cache warming and invalidation strategies

#### Timeline Processing
```ruby
# lib/services/timeline_builder.rb
class TimelineBuilder
  def build_timeline(actor1_movies, actor2_movies)
    start_time = Time.now
    
    all_years = extract_years(actor1_movies, actor2_movies)
    shared_movies = find_shared_movies(actor1_movies, actor2_movies)
    
    timeline = all_years.map do |year|
      build_year_data(year, actor1_movies, actor2_movies, shared_movies)
    end
    
    duration = (Time.now - start_time) * 1000
    StructuredLogger.info("Timeline built", duration_ms: duration, years: all_years.size)
    
    timeline
  end
end
```

**Performance Optimizations:**
- Efficient data structure usage
- Minimal memory allocation
- Performance monitoring integration
- Algorithmic complexity optimization

### 5. Infrastructure Layer

#### Redis Cache Architecture
```ruby
# lib/config/cache.rb
class Cache
  class RedisCache
    def initialize
      pool_size = ENV.fetch("REDIS_POOL_SIZE", "10").to_i
      pool_timeout = ENV.fetch("REDIS_POOL_TIMEOUT", "5").to_i
      
      @pool = ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
        Redis.new(
          url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
          reconnect_attempts: 3,
          connect_timeout: 3,
          read_timeout: 3,
          write_timeout: 3,
          tcp_keepalive: 60
        )
      end
    end
    
    def get(key)
      @pool.with do |redis|
        data = redis.get(cache_key(key))
        return nil unless data
        
        entry = JSON.parse(data, symbolize_names: true)
        return nil if entry[:expires_at] < Time.now.to_f
        
        entry[:value]
      end
    rescue Redis::BaseError, JSON::ParserError => e
      StructuredLogger.error("Cache Get Error", error: e.message, key: key)
      nil
    end
  end
end
```

**Infrastructure Features:**
- Connection pooling for scalability
- Automatic failover and reconnection
- Environment-based configuration
- Comprehensive error handling

#### Structured Logging
```ruby
# lib/config/logger.rb
class StructuredLogger
  def self.info(message, context = {})
    log_entry = {
      level: "INFO",
      message: message,
      timestamp: Time.now.iso8601,
      environment: ENV.fetch("RACK_ENV", "development")
    }.merge(context)
    
    STDOUT.puts log_entry.to_json
  end
end
```

**Logging Strategy:**
- JSON-structured logs for machine parsing
- Contextual information inclusion
- Performance metrics integration
- Error tracking correlation

## 🔄 Data Flow Architecture

### Request Processing Pipeline

1. **Request Reception**
   ```
   Client Request → Rack::Attack (Rate Limiting) → Rack::SSL (HTTPS)
   ```

2. **Security Processing**
   ```
   HTTPS Check → CORS Validation → Input Sanitization → Authorization
   ```

3. **Business Logic**
   ```
   Controller → Handler → Service → External API → Cache
   ```

4. **Response Generation**
   ```
   Data Processing → Template Rendering → Security Headers → Client Response
   ```

### Caching Flow
```
Request → Cache Check → [HIT: Return Cached] / [MISS: API Call → Process → Cache → Return]
```

**Cache Strategy:**
- Read-through caching for API responses
- Write-behind for performance optimization
- TTL-based expiration management
- Cache warming for popular queries

### Error Flow
```
Error Occurrence → Circuit Breaker Check → Fallback Response → Logging → Monitoring Alert
```

**Error Handling:**
- Graceful degradation strategies
- User-friendly error messages
- Comprehensive error logging
- Real-time monitoring integration

## 🏛️ Design Patterns

### 1. Circuit Breaker Pattern
```ruby
@circuit_breaker.call do
  execute_api_request
end
rescue SimpleCircuitBreaker::CircuitOpenError
  return_fallback_response
end
```

**Benefits:**
- Prevents cascade failures
- Automatic failure detection
- Graceful degradation
- System recovery assistance

### 2. Repository Pattern
```ruby
class TMDBService
  def initialize(client = ResilientTMDBClient.new(ENV['TMDB_API_KEY']))
    @client = client
  end
  
  def search_actors(query)
    # Abstracted data access logic
  end
end
```

**Advantages:**
- Testability improvement
- Dependency injection support
- Data source abstraction
- Interface consistency

### 3. Factory Pattern
```ruby
class Cache
  def self.initialize_cache
    @initialize_cache ||= if production?
                            RedisCache.new
                          else
                            MemoryCache.new
                          end
  end
end
```

**Use Cases:**
- Environment-based implementation selection
- Configuration-driven object creation
- Testing flexibility
- Runtime adaptation

### 4. Middleware Pattern
```ruby
# app.rb - Middleware stack
use Rack::Attack
use Rack::Deflater
use Rack::SSL
use Rack::Protection
use RequestLogger
use Sentry::Rack::CaptureExceptions
```

**Benefits:**
- Cross-cutting concern separation
- Request/response processing pipeline
- Composable functionality
- Order-dependent behavior management

## 📊 Performance Architecture

### Caching Layers

1. **Application Level**
   - Redis-backed API response caching
   - Connection pooling optimization
   - TTL-based cache invalidation

2. **HTTP Level**
   - Browser caching with appropriate headers
   - CDN integration readiness
   - Gzip compression

3. **Database Level**
   - Redis connection pooling
   - Query optimization
   - Connection keep-alive

### Performance Monitoring
```ruby
# lib/middleware/performance_headers.rb
class PerformanceHeaders
  def call(env)
    start_time = Time.now
    status, headers, response = @app.call(env)
    
    duration = ((Time.now - start_time) * 1000).round(2)
    headers["X-Response-Time"] = "#{duration}ms"
    
    [status, headers, response]
  end
end
```

**Metrics Tracked:**
- Response time per request
- Cache hit/miss ratios
- Circuit breaker status
- Error rates and patterns

## 🔧 Configuration Management

### Environment-Based Configuration
```ruby
# lib/config/configuration.rb
class Configuration
  def self.validate_required_env_vars
    required_vars = %w[TMDB_API_KEY]
    required_vars.each do |var|
      raise "Missing required environment variable: #{var}" unless ENV[var]
    end
  end
end
```

**Configuration Strategy:**
- Environment variable validation
- Default value management
- Type conversion and validation
- Runtime configuration updates

### Deployment Configuration
```yaml
# render.yaml
services:
  - type: web
    name: actorsync
    env: ruby
    envVars:
      - key: RACK_ENV
        value: production
      - key: REDIS_URL
        fromService:
          type: redis
          name: actorsync-redis
          property: connectionString
```

**Infrastructure as Code:**
- Declarative service definitions
- Environment-specific configurations
- Service dependency management
- Automated deployment pipelines

## 🧪 Testing Architecture

### Test Structure
```
spec/
├── lib/                    # Unit tests
│   ├── services/          # Service layer tests
│   ├── config/            # Configuration tests
│   └── controllers/       # Controller tests
├── requests/              # Integration tests
│   └── api_spec.rb        # API endpoint tests
└── support/               # Test utilities
    ├── app.rb             # Test app configuration
    └── helpers/           # Test helper modules
```

### Testing Strategies

1. **Unit Testing**
   ```ruby
   RSpec.describe TMDBService do
     let(:service) { described_class.new(mock_client) }
     let(:mock_client) { instance_double(ResilientTMDBClient) }
     
     it "searches actors successfully" do
       allow(mock_client).to receive(:request).and_return(mock_response)
       result = service.search_actors("Leonardo")
       expect(result).to be_an(Array)
     end
   end
   ```

2. **Integration Testing**
   ```ruby
   RSpec.describe "API Endpoints", type: :request do
     it "returns actor suggestions" do
       mock_tmdb_actor_search("Leonardo", mock_results)
       get "/api/actors/search", { q: "Leonardo", field: "actor1" }
       
       expect(last_response.status).to eq(200)
       expect(last_response.body).to include("Leonardo DiCaprio")
     end
   end
   ```

**Testing Philosophy:**
- Test behavior, not implementation
- Mock external dependencies
- Integration tests for critical paths
- Performance testing for optimization

## 🚀 Deployment Architecture

### Container Strategy
```yaml
# Procfile
web: bundle exec puma -C config/puma.rb
```

**Deployment Features:**
- Process-based application management
- Environment-specific configuration
- Health check integration
- Graceful shutdown handling

### Scalability Considerations

1. **Horizontal Scaling**
   - Stateless application design
   - Redis-backed session storage
   - Load balancer compatibility

2. **Vertical Scaling**
   - Connection pooling optimization
   - Memory usage optimization
   - CPU-efficient algorithms

3. **Database Scaling**
   - Redis cluster support
   - Connection pool sizing
   - Cache distribution strategies

## 📈 Monitoring & Observability

### Health Check Architecture
```ruby
def comprehensive_check
  checks = {
    app: { status: "healthy", timestamp: Time.now.iso8601 },
    cache: cache_health_check,
    tmdb_api: tmdb_health_check
  }
  
  overall_status = checks.values.all? { |check| check[:status] == "healthy" } ? "healthy" : "degraded"
  
  {
    status: overall_status,
    checks: checks,
    timestamp: Time.now.iso8601
  }
end
```

**Monitoring Features:**
- Comprehensive dependency health checks
- Real-time status reporting
- Automated alerting integration
- Performance metric collection

### Error Tracking Integration
```ruby
# config/sentry.rb
Sentry.configure do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = ENV.fetch("RACK_ENV", "development")
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1
end
```

**Observability Strategy:**
- Real-time error tracking
- Performance monitoring
- User experience tracking
- Business metric collection

---

**Architecture Version**: 2.0  
**Last Updated**: 2025-07-13  
**Status**: Production Ready ✅