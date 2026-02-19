# Kamal Configuration Instructions for movie_together

This document provides instructions for generating a complete Kamal deployment configuration for the movie_together (ActorSync) application.

## Application Overview

**Name:** movie_together (ActorSync)  
**Type:** Ruby/Sinatra web application  
**Purpose:** Actor filmography timeline visualizer with TMDB API integration  
**Port:** 4567  
**Tech Stack:**
- Ruby 4.0.1
- Sinatra 4.1.1
- Redis (for caching)
- Puma web server
- TMDB API v3
- Doppler (secret management)
- Sentry (error monitoring)
- PostHog (analytics - optional)

## Dependencies

### Required Services (Accessories)
1. **Redis** (required)
   - Used for caching TMDB API responses
   - Port: 6379
   - **Should already be running** from gcal-sinatra deployment
   - Do NOT redeploy Redis accessory

2. **Traefik** (reverse proxy)
   - Handles SSL termination with Let's Encrypt
   - **Should already be running** from gcal-sinatra deployment
   - Do NOT redeploy Traefik

### External Services
1. **TMDB API**
   - API key required (free tier available)
   - Sign up at: https://www.themoviedb.org/settings/api
   - Rate limits: 40 requests per 10 seconds

2. **Doppler** (secrets management)
   - Service token required (starts with `dp.st.prd.`)
   - All secrets stored in Doppler cloud

3. **Sentry** (optional - error monitoring)
   - DSN required for error tracking
   - Frontend + Backend error tracking

4. **PostHog** (optional - analytics)
   - API key required (starts with `phc_`)
   - Track actor searches and comparisons

## Environment Variables (Managed via Doppler)

### Critical (Required for App to Function)
```bash
TMDB_API_KEY               # From themoviedb.org API settings
RACK_ENV                   # Should be "production"
REDIS_URL                  # Should be "redis://redis:6379"
REDIS_POOL_SIZE            # Recommended: 15
KAMAL_REGISTRY_PASSWORD    # Docker Hub token
```

### Monitoring (Optional but Recommended)
```bash
SENTRY_DSN                 # Format: https://xxx@o123.ingest.sentry.io/456
SENTRY_ENVIRONMENT         # Should be "production"
POSTHOG_API_KEY            # Format: phc_xxxxxxxxxxxxx (optional)
POSTHOG_HOST               # Default: https://app.posthog.com (optional)
```

### Optional Configuration
```bash
ALLOWED_ORIGINS            # For CORS, comma-separated domains
CDN_BASE_URL              # If using CDN for static assets
CDN_PROVIDER              # e.g., "cloudflare"
```

### Doppler Integration
```bash
DOPPLER_TOKEN              # Service token from Doppler (set via kamal secrets)
```

## Kamal Configuration Structure

### config/deploy.yml

Create a `config/deploy.yml` file with the following structure:

```yaml
# Service name (used for container naming)
service: actorsync

# Docker image (update USERNAME with actual Docker Hub username)
image: USERNAME/actorsync

# Server configuration
servers:
  web:
    hosts:
      - SERVER_IP  # Replace with actual VPS IP address
    labels:
      # Traefik routing configuration
      traefik.http.routers.actorsync.rule: Host(`actors.DOMAIN`)  # Replace DOMAIN
      traefik.http.routers.actorsync.entrypoints: websecure
      traefik.http.routers.actorsync.tls.certresolver: letsencrypt
      traefik.http.services.actorsync.loadbalancer.server.port: 4567
    # Override CMD to use Doppler for secret injection
    cmd: doppler run -- bundle exec puma -C config/puma.rb

# Docker registry authentication
registry:
  username: USERNAME  # Replace with Docker Hub username
  password:
    - KAMAL_REGISTRY_PASSWORD  # From .env or kamal secrets

# Environment variables
env:
  # Only the Doppler token is passed to container
  # All other secrets are fetched by Doppler at runtime
  secret:
    - DOPPLER_TOKEN

# DO NOT INCLUDE accessories or traefik sections
# They are already running from gcal-sinatra deployment
# Redis and Traefik are shared across all apps

# Health check configuration
healthcheck:
  path: /health/simple
  port: 4567
  interval: 10s
  timeout: 5s
  max_attempts: 3

# Persistent volumes
volumes:
  - actorsync-cache:/app/tmp

# Deployment hooks
hooks:
  post-deploy: .kamal/hooks/post-deploy
```

### config/puma.rb

Create a Puma configuration file:

```ruby
# config/puma.rb
port ENV.fetch("PORT", 4567)
environment ENV.fetch("RACK_ENV", "production")

# Worker configuration
workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
threads_count = ENV.fetch("MAX_THREADS", 5).to_i
threads threads_count, threads_count

# Preload app for better performance
preload_app!

# Allow puma to be restarted by `bin/rails restart` command
plugin :tmp_restart

on_worker_boot do
  # Reconnect to Redis after fork
  if defined?(Redis)
    Redis.current.disconnect!
  end
end
```

### Dockerfile

Create a production-ready Dockerfile with Doppler:

```dockerfile
FROM ruby:4.0.1-slim as base

WORKDIR /app

ENV RACK_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

FROM base as build

# Install build dependencies including curl for Doppler
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    pkg-config \
    curl \
    gnupg

# Install Doppler CLI
RUN curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
    https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    tee /etc/apt/sources.list.d/doppler-cli.list && \
    apt-get update && \
    apt-get -y install doppler

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

FROM base

# Install runtime packages + Doppler
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    gnupg && \
    curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
    https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    tee /etc/apt/sources.list.d/doppler-cli.list && \
    apt-get update && \
    apt-get -y install doppler && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Create non-root user
RUN groupadd --system --gid 1000 ruby && \
    useradd ruby --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R ruby:ruby /app

USER ruby:ruby

EXPOSE 4567

# Use Doppler to inject secrets at runtime
CMD ["doppler", "run", "--", "bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### config.ru

Ensure config.ru exists:

```ruby
# frozen_string_literal: true

require_relative "app"

run MovieTogetherApp
```

### .kamal/hooks/post-deploy

Create executable post-deployment hook:

```bash
#!/bin/bash
set -e

echo "✅ actorsync deployment completed"

# Optional: Notify Sentry of new release
if [ -n "$SENTRY_AUTH_TOKEN" ] && [ -n "$SENTRY_ORG" ] && [ -n "$SENTRY_PROJECT" ]; then
  VERSION=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  
  curl https://sentry.io/api/0/organizations/$SENTRY_ORG/releases/ \
    -X POST \
    -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{
      \"version\": \"$VERSION\",
      \"projects\": [\"$SENTRY_PROJECT\"]
    }" 2>/dev/null || echo "⚠️  Sentry notification failed (non-critical)"
fi

# Warm up cache (optional)
if [ -n "$APP_URL" ]; then
  curl -s "$APP_URL/health/complete" > /dev/null || echo "⚠️  Cache warming failed (non-critical)"
fi

echo "🎉 Post-deployment tasks completed"
```

Make it executable:
```bash
chmod +x .kamal/hooks/post-deploy
```

## Configuration Checklist

### Pre-Deployment Setup

- [ ] **Doppler Configuration**
  - [ ] Create Doppler project: `doppler projects create actorsync`
  - [ ] Setup environment: `doppler setup` (select actorsync, config: prd)
  - [ ] Add all required secrets (see Environment Variables section)
  - [ ] Create service token: `doppler configs tokens create kamal-deploy --project actorsync --config prd`
  - [ ] Save token securely

- [ ] **TMDB API Setup**
  - [ ] Create account at https://www.themoviedb.org
  - [ ] Go to Settings → API
  - [ ] Request API key (free)
  - [ ] Copy API key (v3) to Doppler

- [ ] **Sentry Setup** (optional)
  - [ ] Create Sentry project (Ruby/Rack platform)
  - [ ] Copy DSN to Doppler
  - [ ] Create auth token for release tracking (optional)

- [ ] **PostHog Setup** (optional)
  - [ ] Create PostHog account
  - [ ] Copy Project API Key to Doppler

- [ ] **Docker Hub**
  - [ ] Create repository: `actorsync`
  - [ ] Use same token as gcal-sinatra
  - [ ] Add token to Doppler as `KAMAL_REGISTRY_PASSWORD`

### Application Files

- [ ] **Create required files**
  - [ ] `config/deploy.yml` (see above)
  - [ ] `config/puma.rb` (see above)
  - [ ] `Dockerfile` (see above)
  - [ ] `.kamal/hooks/post-deploy`
  - [ ] Verify `config.ru` exists

- [ ] **Update config/deploy.yml**
  - [ ] Replace `USERNAME` with Docker Hub username
  - [ ] Replace `SERVER_IP` with VPS IP address
  - [ ] Replace `DOMAIN` with your domain (e.g., example.com)
  - [ ] **IMPORTANT:** Do NOT include `accessories` section (Redis already running)
  - [ ] **IMPORTANT:** Do NOT include `traefik` section (Traefik already running)

- [ ] **Set Kamal secrets**
  - [ ] `kamal secrets set DOPPLER_TOKEN="dp.st.prd.YOUR_TOKEN"`

### DNS Configuration

- [ ] **Add DNS A record**
  - [ ] Create A record: `actors.DOMAIN` → `SERVER_IP`
  - [ ] Wait for propagation (check with `dig actors.DOMAIN`)

## Deployment Order (Important!)

This is the **SECOND** app deployment. Redis and Traefik should already be running.

### Verify Prerequisites

```bash
# SSH to server
ssh deploy@SERVER_IP

# Check Redis is running
docker ps | grep redis
# Should show: redis container running

# Check Traefik is running
docker ps | grep traefik
# Should show: traefik container running
```

If Redis or Traefik are not running, deploy gcal-sinatra first.

## Deployment Commands

### Initial Deployment

```bash
# 1. Build Docker image
docker build -t USERNAME/actorsync .

# 2. Push to Docker Hub
docker push USERNAME/actorsync

# 3. Initialize Kamal (creates config)
kamal init

# 4. Validate configuration
kamal config

# 5. Deploy application (Redis & Traefik already exist)
kamal deploy

# 6. Check logs
kamal app logs -f

# 7. Verify deployment
curl -I https://actors.DOMAIN
```

### Update Deployment

```bash
# 1. Make code changes
git commit -am "Update feature"

# 2. Build and push new image
docker build -t USERNAME/actorsync .
docker push USERNAME/actorsync

# 3. Deploy update (zero-downtime)
kamal deploy

# 4. Check logs
kamal app logs
```

### Rollback

```bash
# Rollback to previous version
kamal app rollback

# Check current version
kamal app version
```

## Verification Steps

After deployment, verify:

### 1. Container Health
```bash
kamal app containers
# Should show: actorsync running

kamal app logs | grep -i error
# Should have no critical errors
```

### 2. Doppler Integration
```bash
kamal app exec --interactive bash
doppler secrets
# Should list all secrets (values hidden)
exit
```

### 3. Application Access
```bash
curl -I https://actors.DOMAIN
# Should return: HTTP/2 200

curl https://actors.DOMAIN/health/simple
# Should return: {"status":"healthy"}
```

### 4. SSL Certificate
```bash
echo | openssl s_client -connect actors.DOMAIN:443 -servername actors.DOMAIN 2>/dev/null | openssl x509 -noout -dates
# Should show valid dates
```

### 5. Redis Connection
```bash
kamal app exec 'echo "PING" | nc redis 6379'
# Should return: +PONG

kamal app logs | grep -i redis
# Should show successful Redis connection
```

### 6. TMDB API Integration
```bash
# Visit app and search for an actor
# e.g., https://actors.DOMAIN

# Search for "Tom Hanks"
# Should return results with autocomplete

# Check logs
kamal app logs | grep -i tmdb
# Should show successful API calls
```

### 7. Sentry Integration
```bash
kamal app logs | grep -i sentry
# Should see: "Sentry initialized"

# Trigger a test error
# Check Sentry dashboard for error
```

### 8. Performance
```bash
# Check response time
curl -w "@-" -o /dev/null -s https://actors.DOMAIN <<'EOF'
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
      time_redirect:  %{time_redirect}\n
   time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
         time_total:  %{time_total}\n
EOF
# Should be under 500ms for first request
```

## Troubleshooting

### Doppler Secrets Not Loading

```bash
# Check token is set
kamal app exec 'env | grep DOPPLER'

# Test Doppler manually
kamal app exec --interactive bash
doppler secrets --token=$DOPPLER_TOKEN
```

### TMDB API Not Working

```bash
# Check API key
kamal app exec 'env | grep TMDB'

# Test API manually
kamal app exec --interactive bash
curl -H "Authorization: Bearer $TMDB_API_KEY" \
  'https://api.themoviedb.org/3/search/person?query=Tom%20Hanks'
```

### Redis Connection Issues

```bash
# Check Redis is accessible
kamal app exec 'nc -zv redis 6379'

# Test Redis commands
kamal app exec 'echo "PING" | nc redis 6379'

# Check connection pool
kamal app logs | grep -i "redis pool"
```

### High Response Times

```bash
# Check cache hit rate
kamal app logs | grep -i cache

# Verify Redis caching is working
kamal app exec --interactive bash
redis-cli -h redis
KEYS actorsync:*
# Should show cached keys
```

### CORS Issues

```bash
# Check CORS headers
curl -I -H "Origin: https://example.com" https://actors.DOMAIN/api/actors/search?q=Tom

# Should see:
# Access-Control-Allow-Origin: *
# (or your specific domain if ALLOWED_ORIGINS is set)
```

## Performance Optimization

### Redis Caching Strategy

The app caches:
- Actor search results: 1 hour
- Actor filmography: 6 hours
- TMDB API responses: 1 hour

Adjust cache TTL in application code if needed.

### Rate Limiting

App includes built-in rate limiting:
- Search endpoint: 30 requests/minute per IP
- Compare endpoint: 60 requests/minute per IP
- Health checks: 120 requests/minute per IP

### Monitoring Cache Performance

```bash
# Check cache stats
kamal app exec --interactive bash
redis-cli -h redis INFO stats

# Check cache keys
redis-cli -h redis KEYS actorsync:*

# Monitor cache in real-time
redis-cli -h redis MONITOR
```

## Environment-Specific Configurations

### Staging Environment

Create a separate Doppler config for staging:

```bash
doppler setup --config stg
doppler secrets set TMDB_API_KEY="same_as_production"
doppler secrets set SENTRY_DSN="staging_sentry_dsn"

# Deploy to staging
kamal deploy --destination staging
```

### Development Environment

For local development with Doppler:

```bash
doppler setup --config dev
doppler secrets set TMDB_API_KEY="dev_api_key"
doppler secrets set REDIS_URL="redis://localhost:6379"

# Run locally with Doppler
doppler run -- bundle exec ruby app.rb
```

## Security Notes

1. **TMDB API Key** - Read-only, but keep secure
2. **Rate Limiting** - Implemented via Rack::Attack
3. **Input Validation** - All user inputs sanitized
4. **CORS** - Configure ALLOWED_ORIGINS for production
5. **HTTPS Only** - Enforced by Traefik
6. **Error Messages** - Don't expose internal details

## Maintenance

### Update Secrets

```bash
doppler secrets set TMDB_API_KEY="new_api_key"
kamal app restart
```

### Clear Cache

```bash
kamal app exec --interactive bash
redis-cli -h redis
FLUSHDB  # Clears current database
# Or selectively:
DEL actorsync:search:*
```

### View Logs

```bash
# Application logs
kamal app logs -f

# Filter for errors
kamal app logs | grep -i error

# Filter for TMDB API calls
kamal app logs | grep -i tmdb
```

### Monitor Performance

```bash
# Check response times
kamal app logs | grep "Completed" | tail -20

# Check cache hit rate
kamal app logs | grep -i "cache hit"
```

## Additional Resources

- **TMDB API Docs**: https://developers.themoviedb.org/3
- **Kamal Docs**: https://kamal-deploy.org
- **Doppler Docs**: https://docs.doppler.com
- **Sentry Docs**: https://docs.sentry.io
- **PostHog Docs**: https://posthog.com/docs
- **Project Guide**: `/home/paolo/projects/kamal_config/DOPPLER_SENTRY_POSTHOG_INTEGRATION.md`

---

**Generated for:** movie_together (ActorSync)  
**Last Updated:** 2025-01-10  
**Kamal Version:** 2.x  
**Ruby Version:** 4.0.1  
**IMPORTANT:** This is the SECOND app deployment. Redis and Traefik must already be running.
