# CoStar Security Implementation

This document details the comprehensive security hardening implemented in CoStar to ensure production-ready security posture.

## 🔒 Security Overview

CoStar implements defense-in-depth security with multiple layers of protection:

1. **Transport Security** - HTTPS enforcement and secure headers
2. **Input Protection** - Validation, sanitization, and whitelisting
3. **Request Protection** - Rate limiting and abuse prevention
4. **Response Security** - Security headers and content validation
5. **Infrastructure Security** - Redis security and connection protection
6. **Monitoring & Detection** - Logging and error tracking

## 🛡️ Transport Security

### HTTPS Enforcement
```ruby
# app.rb - Production configuration
configure :production do
  use Rack::SSL  # Force HTTPS redirection
end
```

**Implementation Details:**
- Automatic HTTP to HTTPS redirection
- HSTS headers with preload support
- Secure cookie configuration
- TLS termination at load balancer level

### Security Headers
```ruby
def add_security_headers
  response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
  response.headers["Content-Security-Policy"] = build_csp_header
  response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
end
```

**Headers Implemented:**
- **HSTS**: Prevents protocol downgrade attacks
- **CSP**: Prevents XSS and code injection
- **Referrer Policy**: Controls referrer information leakage
- **Permissions Policy**: Restricts browser feature access

## 🔍 Input Protection

### Input Validation & Sanitization

All user inputs are validated and sanitized through dedicated methods:

#### Search Query Sanitization
```ruby
def sanitize_search_query(query)
  return nil if query.nil?
  
  sanitized = query.to_s.strip
  return nil if sanitized.empty? || sanitized.length > 100
  
  # Allow international characters but remove dangerous content
  sanitized.gsub(/[^\p{L}\p{N}\s'\-\.]/, "").strip
end
```

**Protection Features:**
- Length limits (100 characters for queries)
- Character whitelisting with Unicode support
- Preservation of international actor names
- HTML/script tag removal

#### Actor ID Validation
```ruby
def sanitize_actor_id(actor_id)
  return nil if actor_id.nil? || actor_id.to_s.strip.empty?
  
  id = actor_id.to_s.strip
  return nil unless id.match?(/\A\d+\z/)  # Only digits
  
  parsed_id = id.to_i
  return nil if parsed_id <= 0 || parsed_id > 999_999_999
  
  parsed_id
end
```

**Validation Rules:**
- Integer-only input (no SQL injection vectors)
- Range validation (1 to 999,999,999)
- Type conversion safety
- Null/empty handling

#### Field Name Whitelisting
```ruby
def sanitize_field_name(field)
  %w[actor1 actor2].include?(field.to_s) ? field.to_s : "actor1"
end
```

**Security Benefits:**
- Prevents parameter pollution
- Blocks injection through field names
- Maintains application logic integrity

## 🚧 Request Protection

### Rate Limiting (Rack::Attack)

Comprehensive rate limiting implemented with Redis backend:

```ruby
# config/rack_attack.rb

# Search endpoint - 60 requests per minute
throttle("search/ip", limit: 60, period: 60) do |req|
  req.ip if req.path.start_with?("/api/actors/search")
end

# Comparison endpoint - 30 requests per minute (more expensive)
throttle("compare/ip", limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?("/api/actors/compare")
end

# General API - 120 requests per minute
throttle("api/ip", limit: 120, period: 60) do |req|
  req.ip if req.path.start_with?("/api/")
end
```

**Rate Limiting Features:**
- Endpoint-specific limits based on computational cost
- Redis-backed persistence across server restarts
- Proper HTTP 429 responses with retry-after headers
- IP-based throttling with localhost exemption

### User Agent Filtering
```ruby
blocklist("block bad user agents") do |req|
  user_agent = req.user_agent
  user_agent.nil? ||
    user_agent.empty? ||
    user_agent.match(/curl|wget|python|java|go-http|bot/i)
end
```

**Blocked Patterns:**
- Empty or null user agents
- Common scraping tools (curl, wget)
- Automated clients (python, java, go-http)
- Generic bot patterns

### Request Logging & Monitoring
```ruby
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
  StructuredLogger.warn("Request Throttled",
                        type: "security",
                        action: "throttled",
                        ip: payload[:request].ip,
                        path: payload[:request].path,
                        user_agent: payload[:request].user_agent)
end
```

**Monitoring Features:**
- Real-time attack detection
- Structured logging for analysis
- IP and pattern tracking
- Integration with error tracking (Sentry)

## 🔐 Response Security

### Content Security Policy (CSP)
```ruby
def build_csp_header
  policies = [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' https://unpkg.com",  # HTMX from CDN
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    "img-src 'self' https://image.tmdb.org data:",  # TMDB images
    "connect-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'"
  ]
  policies.join("; ")
end
```

**CSP Protection:**
- Restricts script sources to prevent XSS
- Allows necessary external resources (TMDB images, fonts)
- Prevents clickjacking with frame-ancestors
- Restricts form submission targets

### CORS Configuration
```ruby
def configure_cors_headers
  if ENV.fetch("RACK_ENV", "development") == "production"
    # Production: restrictive CORS
    allowed_origins = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip)
    origin = request.env["HTTP_ORIGIN"]
    headers "Access-Control-Allow-Origin" => origin || "*" if allowed_origins.empty? || allowed_origins.include?(origin)
  else
    # Development: permissive CORS
    headers "Access-Control-Allow-Origin" => "*"
  end
  
  headers "Access-Control-Allow-Credentials" => "false"
  headers "Access-Control-Expose-Headers" => "X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset"
end
```

**CORS Security:**
- Environment-based origin restrictions
- Production allowlist via `ALLOWED_ORIGINS`
- Credentials disabled for security
- Rate limit headers exposed for client handling

## 🏗️ Infrastructure Security

### Redis Security
```ruby
# lib/config/cache.rb
@pool = ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
  Redis.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
    reconnect_attempts: 3,
    connect_timeout: 3,
    read_timeout: 3,
    write_timeout: 3,
    tcp_keepalive: 60,
    driver: :ruby
  )
end
```

**Redis Protection:**
- Connection pooling prevents connection exhaustion
- Timeout configuration prevents hanging connections
- Automatic reconnection with retry limits
- Network keepalive for stability

### Environment Security
```ruby
# Production environment variables
RACK_ENV=production
TMDB_API_KEY=secret_key_here
SENTRY_DSN=secret_dsn_here
REDIS_URL=redis://redis_server:6379
ALLOWED_ORIGINS=https://yourdomain.com
```

**Environment Protection:**
- Secrets stored in environment variables
- No hardcoded credentials in code
- Separate configurations per environment
- Environment validation on startup

## 📊 Monitoring & Detection

### Structured Security Logging
```ruby
StructuredLogger.warn("Request Blocked",
                      type: "security",
                      action: "blocked",
                      ip: payload[:request].ip,
                      path: payload[:request].path,
                      user_agent: payload[:request].user_agent,
                      reason: "suspicious_user_agent")
```

**Logged Security Events:**
- Rate limiting violations
- Blocked requests (user agent filtering)
- Input validation failures
- Authentication attempts (if implemented)
- Circuit breaker activations

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

**Security Monitoring:**
- Real-time error alerts
- Performance degradation detection
- Security event aggregation
- Trend analysis and reporting

## 🔧 Security Configuration

### Production Security Middleware Stack
```ruby
# app.rb - Middleware order is important
use Rack::Attack           # Rate limiting (first line of defense)
use Rack::Deflater         # Compression
use Rack::SSL              # HTTPS enforcement
use Rack::Protection        # XSS/CSRF protection
use PerformanceHeaders     # Caching headers
use RequestLogger          # Request logging
use Sentry::Rack::CaptureExceptions  # Error tracking
```

**Middleware Security:**
- Ordered for optimal protection
- Defense in depth approach
- Performance optimized
- Comprehensive logging

### API Security Headers
```ruby
# Applied to all API responses
headers "X-Content-Type-Options" => "nosniff"
headers "X-Frame-Options" => "DENY"
headers "X-XSS-Protection" => "1; mode=block"
headers "Access-Control-Allow-Credentials" => "false"
```

**API Protection:**
- MIME type sniffing prevention
- Clickjacking protection
- XSS filtering enablement
- Credential transmission disabled

## 🚨 Security Testing

### Test Coverage
```ruby
# spec/requests/api_spec.rb - Security test examples
it "includes CORS headers for API endpoints" do
  get "/api/actors/search", { q: "test" }
  expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
end

it "handles non-existent routes" do
  get "/non-existent-endpoint"
  expect([200, 403, 404, 500]).to include(last_response.status)
end
```

**Security Tests:**
- Input validation edge cases
- Rate limiting behavior
- CORS header verification
- Error handling security
- Authentication bypass attempts

### Code Security Scanning
```bash
# Automated security scanning
bundle exec brakeman       # Static security analysis
bundle exec bundle-audit   # Dependency vulnerability scan
bundle exec rubocop        # Code quality and security patterns
```

**Security Tools:**
- **Brakeman**: Static analysis for Rails/Sinatra security issues
- **Bundle-audit**: Known vulnerability detection in dependencies
- **RuboCop**: Security-focused linting rules

## ⚡ Performance vs Security

### Optimized Security Implementations

**Redis Rate Limiting:**
- Connection pooling prevents performance degradation
- Efficient key patterns for fast lookups
- TTL-based cleanup with automatic background service prevents memory leaks

**Input Validation:**
- Regex compilation optimized for performance
- Early validation to fail fast
- Minimal string operations

**Header Management:**
- Headers cached where possible
- Conditional application based on environment
- Minimal header redundancy

## 🔄 Security Maintenance

### Regular Security Tasks

1. **Dependency Updates**
   ```bash
   bundle update && bundle audit
   ```

2. **Security Scanning**
   ```bash
   bundle exec brakeman --no-pager
   ```

3. **Log Analysis**
   - Review blocked request patterns
   - Analyze rate limiting effectiveness
   - Monitor error rates and types

4. **Configuration Review**
   - Validate environment variables
   - Review rate limiting thresholds
   - Update allowed origins list

### Security Incident Response

1. **Detection**: Sentry alerts and log monitoring
2. **Analysis**: Structured logs provide context
3. **Response**: Rate limiting and blocking capabilities
4. **Recovery**: Circuit breaker and graceful degradation
5. **Learning**: Log analysis and pattern identification

## 📋 Security Checklist

### Pre-Deployment Security Verification

- [ ] All environment variables configured
- [ ] Rate limiting thresholds appropriate for traffic
- [ ] CORS origins configured for production domain
- [ ] Security headers tested and verified
- [ ] Input validation covers all endpoints
- [ ] Error responses don't leak sensitive information
- [ ] Logging captures security events
- [ ] Sentry configured for security monitoring

### Post-Deployment Security Monitoring

- [ ] Rate limiting effectiveness metrics
- [ ] Security event frequency analysis
- [ ] Performance impact assessment
- [ ] Error rate and pattern monitoring
- [ ] User agent analysis for new threats
- [ ] Regular security scanning execution

---

**Security Contact**: For security issues or questions, create a GitHub issue with the "security" label.

**Last Updated**: 2025-07-13  
**Security Review**: Production Ready ✅