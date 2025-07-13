# ActorSync Environment Validation Scripts

This directory contains comprehensive environment validation tools for the ActorSync application.

## Scripts Overview

### 🔍 `check_doppler_environments.rb`
**Primary validation tool** - Validates all Doppler configurations directly.

```bash
# Check all environments (dev, stg, prd)
ruby scripts/check_doppler_environments.rb
```

**Features:**
- ✅ Validates all 3 environments (dev/stg/prd) from Doppler
- ✅ Environment-specific validation rules
- ✅ Required vs optional variable classification
- ✅ Production performance optimization checks
- ✅ Detailed error reporting with fix commands
- ✅ Direct Doppler CLI integration

### 📋 `check_env_variables.rb`
**Context-specific checker** - Validates current environment variables.

```bash
# Check current environment
ruby scripts/check_env_variables.rb

# Check with Doppler environment
doppler run --config prd -- ruby scripts/check_env_variables.rb
```

### 🌍 `check_all_environments.rb`
**Complete validation wrapper** - Runs both checkers for comprehensive analysis.

```bash
# Complete validation
ruby scripts/check_all_environments.rb

# With specific Doppler environment
doppler run --config dev -- ruby scripts/check_all_environments.rb
```

## Validated Environment Variables

### Required for All Environments
- `TMDB_API_KEY` - Movie database API access
- `SESSION_SECRET` - Session encryption (64+ chars)
- `REDIS_URL` - Caching database connection
- `RACK_ENV` - Application environment
- `ALLOWED_ORIGINS` - CORS security configuration
- `PORT` - Web server port

### Optional but Recommended
- `SENTRY_DSN` - Error tracking
- `POSTHOG_API_KEY` + `POSTHOG_HOST` - Analytics
- `APP_VERSION` - Release tracking
- `CACHE_PREFIX` - Redis key prefix

### Production Optimizations
- `REDIS_POOL_SIZE` - Connection pooling
- `REDIS_POOL_TIMEOUT` - Pool timeout
- `PUMA_THREADS` - Web server threads
- `WEB_CONCURRENCY` - Worker processes
- `SENTRY_TRACES_SAMPLE_RATE` - Performance monitoring

### CDN (Production Only)
- `CDN_DOMAIN` - Static asset CDN
- `CDN_PROVIDER` - CDN configuration

## Environment-Specific Rules

| Variable | Dev | Staging | Production |
|----------|-----|---------|------------|
| `RACK_ENV` | `development` | `staging` | `production` |
| `PORT` | `4567` | `10000` | `10000` |
| `REDIS_URL` | `localhost:6379` | Redis URL | Redis cluster |
| `ALLOWED_ORIGINS` | `localhost:4567` | Domain | Domain |

## Quick Doppler Commands

```bash
# Set required variables for dev
doppler secrets set RACK_ENV=development --config dev
doppler secrets set SESSION_SECRET=$(openssl rand -hex 32) --config dev
doppler secrets set REDIS_URL=redis://localhost:6379 --config dev

# Set required variables for production  
doppler secrets set RACK_ENV=production --config prd
doppler secrets set SESSION_SECRET=$(openssl rand -hex 32) --config prd
doppler secrets set REDIS_URL=your_redis_url --config prd

# Add performance optimizations for production
doppler secrets set REDIS_POOL_SIZE=15 --config prd
doppler secrets set PUMA_THREADS=5 --config prd
doppler secrets set WEB_CONCURRENCY=2 --config prd
```

## Integration with Deployment

These scripts are designed to be run:
- ✅ Before deployments to validate configuration
- ✅ In CI/CD pipelines for automated validation
- ✅ During development for environment debugging
- ✅ After Doppler configuration changes

## Status Indicators

- ✅ **Green**: All configured correctly
- ⚠️ **Yellow**: Configured with warnings (optional variables missing)
- ❌ **Red**: Critical issues need immediate attention

The scripts provide actionable commands to fix any detected issues.