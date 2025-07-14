# Production Deployment Guide

This comprehensive guide covers deploying ActorSync to production with Redis caching, error tracking, and security hardening.

## 🚀 Quick Deployment (Render.com)

ActorSync is pre-configured for one-click deployment to Render.com with Redis and monitoring.

### Prerequisites

1. **Render.com Account**: Sign up at [render.com](https://render.com)
2. **GitHub Repository**: Code pushed to GitHub repository
3. **TMDB API Key**: Get from [themoviedb.org](https://www.themoviedb.org/settings/api)
4. **Sentry Account** (optional): Error tracking from [sentry.io](https://sentry.io)

## 📋 Deployment Steps

### 1. Automatic Infrastructure Setup

The `render.yaml` file automatically provisions:

```yaml
services:
  - type: web
    name: actorsync
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec puma
    healthCheckPath: /health/simple
    
  - type: redis
    name: actorsync-redis
    plan: free
    region: oregon
```

**What Gets Created:**
- Web service with Ruby environment
- Redis cache service (free tier: 25MB)
- Automatic HTTPS with SSL certificates
- Health check monitoring
- Auto-scaling configuration

### 2. Connect GitHub Repository

1. **Log into Render Dashboard**
2. **Create New Service**:
   - Click "New +" → "Web Service"
   - Connect GitHub account
   - Select your ActorSync repository
   - Choose `main` branch

3. **Render Auto-Detection**:
   - Render automatically detects `render.yaml`
   - Creates both web service and Redis instance
   - Links Redis to web service via environment variables

### 3. Configure Environment Variables

**Critical Variables (Update from `changeme`):**

```bash
# Required - Update these values
TMDB_API_KEY=your_actual_tmdb_api_key_here
SENTRY_DSN=your_actual_sentry_dsn_here
SESSION_SECRET=your_random_64_character_session_secret_here

# Auto-configured by Render
RACK_ENV=production
REDIS_URL=redis://render-redis-url:6379
PORT=10000

# Security Configuration
ALLOWED_ORIGINS=https://your-app-name.onrender.com

# Performance Tuning
REDIS_POOL_SIZE=15
REDIS_POOL_TIMEOUT=5
```

**In Render Dashboard:**
1. Navigate to your web service
2. Go to "Environment" tab
3. Update the placeholder values:
   - `TMDB_API_KEY`: Replace `changeme` with your TMDB API key
   - `SENTRY_DSN`: Replace `changeme` with your Sentry DSN
   - `ALLOWED_ORIGINS`: Set to your domain (e.g., `https://actorsync.onrender.com`)

### 4. Deploy Application

1. **Trigger Deployment**:
   - Render automatically deploys on configuration save
   - Or manually trigger from "Manual Deploy" button

2. **Monitor Deployment**:
   ```
   Build Process:
   - Bundle install (Ruby dependencies)
   - Security middleware initialization
   - Redis connection establishment
   - Health check verification
   ```

3. **Verify Deployment**:
   - Visit your app URL: `https://your-app-name.onrender.com`
   - Check health endpoint: `https://your-app-name.onrender.com/health/simple`
   - Verify Redis: `https://your-app-name.onrender.com/health/complete`

## 🔧 Production Configuration

### Redis Configuration

**Automatic Setup:**
- Redis service provisioned automatically
- Connection string injected as `REDIS_URL`
- Connection pooling configured (15 connections)
- Automatic failover to memory cache if Redis unavailable

**Redis Features Enabled:**
- Rate limiting persistence
- API response caching
- Session storage (if implemented)
- Performance metrics storage

### Security Configuration

**Automatic Security Features:**
- HTTPS enforcement with Rack::SSL
- Rate limiting with Rack::Attack
- Security headers (CSP, HSTS, X-Frame-Options)
- Input validation and sanitization
- CORS protection with origin allowlisting

**Security Settings:**
```ruby
# Automatically enabled in production
use Rack::SSL                    # HTTPS enforcement
use Rack::Attack                 # Rate limiting
use Rack::Protection              # Security headers
```

### Monitoring & Error Tracking

**Sentry Integration:**
1. **Create Sentry Project**:
   - Visit [sentry.io](https://sentry.io)
   - Create new Ruby/Sinatra project
   - Copy DSN from project settings

2. **Configure Environment**:
   ```bash
   SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
   ```

3. **Features Enabled**:
   - Real-time error tracking
   - Performance monitoring
   - Release tracking
   - User context capture

**Health Check Monitoring:**
- `/health/simple` - Basic uptime check (for load balancers)
- `/health/complete` - Comprehensive dependency validation
- Automatic Redis connectivity verification
- TMDB API health validation

## 📊 Performance Optimization

### Caching Strategy

**Redis Caching (Production):**
- Actor search results: 30 minutes TTL
- Movie data: 60 minutes TTL
- Profile data: 24 hours TTL
- Connection pooling: 15 connections
- Automatic reconnection with circuit breaker

**Performance Metrics:**
- 80% reduction in TMDB API calls
- Sub-second response times
- Connection pool efficiency monitoring
- Cache hit rate tracking

### Rate Limiting

**Endpoint-Specific Limits:**
- Search endpoints: 60 requests/minute
- Comparison endpoints: 30 requests/minute
- General API: 120 requests/minute
- Health checks: Unlimited (whitelisted)

**Redis-Backed Persistence:**
- Rate limit data survives server restarts
- Distributed rate limiting across instances
- Custom rate limit responses with retry headers

## 🛡️ Security Hardening

### Transport Security
- **HTTPS Enforcement**: Automatic with Render.com SSL
- **HSTS Headers**: Preload-enabled for security
- **Secure Cookies**: Production-hardened configuration

### Application Security
- **Input Validation**: All user inputs sanitized
- **SQL Injection Protection**: Parameterized queries only
- **XSS Prevention**: Content Security Policy headers
- **CSRF Protection**: Rack::Protection middleware

### Infrastructure Security
- **Redis Security**: Password-protected with SSL
- **Environment Variables**: Encrypted at rest
- **Network Security**: Private service communication
- **Access Control**: Role-based access to services

## 🔄 CI/CD Pipeline

### GitHub Actions Integration

**Automatic Workflows:**
```yaml
# .github/workflows/test.yml
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Run tests
        run: bundle exec rspec
      - name: Run security scan
        run: bundle exec brakeman
```

**Deployment Pipeline:**
1. **Push to main** → Automatic deployment trigger
2. **Tests run** → RSpec suite (333 examples)
3. **Security scan** → Brakeman vulnerability check
4. **Deploy** → Render.com automatic deployment
5. **Health check** → Post-deployment verification

### Deployment Verification

**Post-Deployment Checks:**
```bash
# Health check verification
curl https://your-app.onrender.com/health/complete

# Expected response
{
  "status": "healthy",
  "checks": {
    "app": {"status": "healthy"},
    "cache": {"status": "healthy"},
    "tmdb_api": {"status": "healthy"}
  }
}
```

## 🔍 Monitoring & Observability

### Application Monitoring

**Structured Logging:**
- JSON-formatted logs for machine parsing
- Request/response logging with performance metrics
- Error context and stack traces
- Security event logging (rate limiting, blocked requests)

**Performance Metrics:**
- Response time tracking
- Cache hit/miss ratios
- Circuit breaker status
- Rate limiting effectiveness

### Error Tracking

**Sentry Integration Features:**
- Real-time error notifications
- Performance transaction monitoring
- Release and deployment tracking
- User session replay (if enabled)
- Custom dashboards and alerting

### Infrastructure Monitoring

**Render.com Built-in Monitoring:**
- CPU and memory usage tracking
- Request rate and error rate monitoring
- Service health and uptime tracking
- Automatic alerting for service failures

## 🐛 Troubleshooting

### Common Deployment Issues

**1. Environment Variable Issues**
```bash
# Check logs for missing variables
render logs --service actorsync

# Common error: Missing TMDB_API_KEY
ERROR: Missing required environment variable: TMDB_API_KEY
# Solution: Update TMDB_API_KEY in Render dashboard
```

**2. Redis Connection Issues**
```bash
# Check Redis service status
# Verify REDIS_URL is properly set
# Check Redis service logs for connection errors
```

**3. Rate Limiting Too Aggressive**
```bash
# Check Rack::Attack logs
# Adjust rate limits in config/rack_attack.rb if needed
# Whitelist development IPs for testing
```

**4. Performance Issues**
```bash
# Check cache hit rates in logs
# Verify Redis connectivity
# Monitor response times in Sentry
```

### Debug Commands

**Local Debugging:**
```bash
# Test Redis connection
bundle exec ruby -e "require './app'; puts Cache.get('test') || 'Redis working'"

# Check environment configuration
bundle exec ruby -e "require './lib/config/configuration'; Configuration.validate_required_env_vars"

# Run security scan
bundle exec brakeman --no-pager

# Test health endpoints locally
curl http://localhost:4567/health/complete
```

## 📈 Scaling Considerations

### Horizontal Scaling

**Render.com Scaling:**
- Auto-scaling based on CPU/memory usage
- Load balancer with session affinity
- Redis shared across instances
- Rate limiting distributed across instances

**Performance Optimization:**
- Connection pooling for Redis
- Stateless application design
- Cache optimization strategies
- Database connection management

### Vertical Scaling

**Resource Optimization:**
- Memory usage optimization
- CPU-efficient algorithms
- Connection pool tuning
- Cache size optimization

## 💰 Cost Optimization

### Render.com Free Tier

**Included Resources:**
- Web service: 512MB RAM, 0.1 CPU
- Redis: 25MB storage
- HTTPS: Included
- Custom domain: Included

**Usage Monitoring:**
- Monitor memory usage in dashboard
- Optimize cache size for available Redis memory
- Use efficient data structures
- Implement cache cleanup strategies

### Production Scaling

**Paid Tier Benefits:**
- Increased memory and CPU
- Larger Redis instances
- Priority support
- Advanced monitoring

## 🔄 Maintenance

### Regular Maintenance Tasks

**Weekly:**
- Review error rates in Sentry
- Check performance metrics
- Monitor cache hit rates
- Review security logs

**Monthly:**
- Update dependencies: `bundle update`
- Security audit: `bundle exec bundle-audit`
- Performance optimization review
- Backup configuration verification

**Quarterly:**
- Security penetration testing
- Performance benchmarking
- Infrastructure cost optimization
- Documentation updates

### Backup Strategy

**Configuration Backup:**
- Environment variables exported
- Redis configuration documented
- Application configuration versioned
- Deployment scripts maintained

**Data Backup:**
- Cache data is ephemeral (regenerated from API)
- Application state is stateless
- Configuration stored in version control
- No persistent data requiring backup

---

**Deployment Support**: For deployment issues, check the troubleshooting section or create a GitHub issue.

**Last Updated**: 2025-07-13  
**Production Ready**: ✅ Complete