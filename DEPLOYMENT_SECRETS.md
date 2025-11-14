# MovieTogether Deployment Secrets Guide

This guide explains how to set up Doppler secrets for MovieTogether development and deployment.

## Overview

**MovieTogether VPS Deployment**: `as.internetblacksmith.dev`

**Deployment Method**: Kamal with Doppler (same as gcal-sinatra and the_void_chronicles)

**Key Principle**: 
- Local development uses **dev config** (`--config dev`)
- Production deployment uses **prd config** (`--config prd`)
- Clear separation between development and production

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Local Development (make dev)                           │
│  - Uses: doppler run --config dev                       │
│  - Developers get dev Doppler config access             │
│  - Separate dev secrets from production                 │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  Deployment (make deploy)                               │
│  - Uses: doppler run --config prd                       │
│  - Explicitly uses production Doppler config            │
│  - All pre-commit checks run (lint, test, security)     │
│  - Kamal deploys to VPS via production secrets          │
└─────────────────────────────────────────────────────────┘
```

## Step 1: Create Doppler Project (One-Time)

```bash
# Login to Doppler
doppler login

# Create project (one-time)
doppler projects create movie_together
```

## Step 2: Set Up Local Development with Dev Config

### Setup dev Configuration

```bash
# Set up local development with dev config
doppler setup --project movie_together --config dev

# Add your development secrets
doppler secrets set --project movie_together --config dev
```

Enter development secrets:
- `TMDB_API_KEY` - Your TMDB API key
- `REDIS_URL` - `redis://localhost:6379` (local Redis)

### Use movie_together Locally

```bash
cd movie_together

# Create .doppler file for dev config (optional, already in .doppler.example)
cp .doppler.example .doppler

# Start development server (uses --config dev automatically)
make dev
```

## Step 3: Create Production Config (For Deployment)

This is done **once** by someone with production access:

```bash
# Create the production config
doppler setup --project movie_together --config prd

# Add production secrets
doppler secrets set --project movie_together --config prd
```

Enter production secrets:
- `KAMAL_REGISTRY_PASSWORD` - GitHub PAT token
- `TMDB_API_KEY` - The Movie Database API key (can be same as dev)
- `REDIS_URL` - `redis://redis:6380` (VPS Redis)
- `SENTRY_DSN` - Sentry error tracking URL
- `SENTRY_ENVIRONMENT` - `production`

## Deployment

Once production config is set up, anyone can deploy:

```bash
cd movie_together

# 1. Run all checks
make pre-commit

# 2. Deploy (uses --config prd automatically)
make deploy

# Or use interactive menu
make menu  # Option 18
```

The deploy command will:
1. ✅ Run lint, tests, security checks
2. ✅ Load production secrets from Doppler prd config
3. ✅ Build Docker image
4. ✅ Push to GitHub Container Registry
5. ✅ Deploy via Kamal to VPS

## Required Secrets Reference

### Development Config (dev)

| Secret | Example | Purpose |
|--------|---------|---------|
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://localhost:6379` | Local Redis for caching |

**Notes:**
- Dev secrets use `--config dev`
- No monitoring (Sentry/PostHog) in dev
- Keep dev Redis on localhost

### Production Config (prd)

| Secret | Example | Purpose |
|--------|---------|---------|
| `KAMAL_REGISTRY_PASSWORD` | `ghp_...` | GitHub PAT for Docker registry |
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://redis:6380` | VPS Redis for caching |
| `SENTRY_DSN` | `https://xxx@sentry.io/123` | Error tracking endpoint |
| `SENTRY_ENVIRONMENT` | `production` | Environment label for Sentry |

**Notes:**
- Production secrets use `--config prd`
- All monitoring required in production
- VPS Redis on port 6380

## Getting Required API Keys

### TMDB API Key

1. Visit: https://www.themoviedb.org/settings/api
2. Register/Login if needed
3. Accept API terms
4. Create an API key
5. Copy to both dev and prd Doppler configs (same key is fine)

### GitHub Personal Access Token (PAT)

For production deployment only:

1. Visit: https://github.com/settings/tokens/new
2. Create new token with scopes:
   - ✅ `read:packages` - read container images
   - ✅ `write:packages` - push container images
3. Copy token to Doppler prd config as `KAMAL_REGISTRY_PASSWORD`

### Sentry DSN (Optional for Production)

For error tracking in production:

1. Create Sentry account: https://sentry.io
2. Create new project (select Ruby/Sinatra)
3. Copy DSN URL to Doppler prd config as `SENTRY_DSN`

## Development Workflow

### First Time Setting Up Locally

```bash
cd movie_together

# Install dependencies
make install

# Set up dev environment (installs gems and pre-commit hooks)
make setup-dev

# Setup Doppler dev config
doppler setup --project movie_together --config dev
doppler secrets set --project movie_together --config dev

# Start development server (uses dev config)
make dev
```

### Running Tests Locally

```bash
cd movie_together

# Run all tests (uses dev config via setup-dev)
make test

# Run specific test suite
make test-rspec
make test-cucumber

# Run with coverage
make test-coverage
```

### Deploying to Production

```bash
cd movie_together

# This automatically uses prd config
make deploy

# Watch logs
make deploy-logs

# Rollback if needed
make deploy-rollback
```

## Doppler Configuration Files

### .doppler (local machine)

Created by running `doppler setup --project movie_together --config dev`:

```json
{
  "project": "movie_together",
  "config": "dev"
}
```

This file tells Doppler CLI to use the dev config for local commands.

### Makefile Deployment

The Makefile explicitly specifies configs:

```bash
# Development: uses .doppler file (dev config)
doppler run --config dev -- bundle exec rerun...

# Production: explicitly specifies prd
doppler run --config prd -- kamal deploy
```

## Troubleshooting

### "KAMAL_REGISTRY_PASSWORD not found" during deployment

Only an issue during deployment. Make sure it's set in Doppler prd config:

```bash
doppler secrets get KAMAL_REGISTRY_PASSWORD --project movie_together --config prd
```

### "Can't pull Docker image during deployment"

1. Verify GitHub PAT token has `read:packages` and `write:packages` scopes
2. Test token manually:
   ```bash
   echo $KAMAL_REGISTRY_PASSWORD | docker login ghcr.io -u jabawack81 --password-stdin
   ```
3. Check token is current in Doppler prd config

### "Redis connection refused" during development

Make sure Redis is running:

```bash
# Start Redis
make redis-start

# In another terminal
make dev
```

### "Doppler config not found" during dev

Make sure you have the dev config set up:

```bash
doppler setup --project movie_together --config dev
doppler secrets set --project movie_together --config dev
```

## Environment Separation

| Aspect | Dev | Production |
|--------|-----|-----------|
| Doppler config | `dev` | `prd` |
| Setup command | `doppler setup --project movie_together --config dev` | `doppler setup --project movie_together --config prd` |
| Dev command | `doppler run --config dev -- make dev` | N/A |
| Deploy command | N/A | `doppler run --config prd -- kamal deploy` |
| REDIS_URL | `redis://localhost:6379` | `redis://redis:6380` |
| Monitoring | ❌ Disabled | ✅ Enabled |
| .doppler file | Points to `dev` | N/A (deploy uses explicit --config prd) |

## Reference Links

- **Doppler Docs**: https://docs.doppler.com
- **Kamal Docs**: https://kamal-deploy.org
- **TMDB API**: https://developer.themoviedb.org/docs
- **GitHub PAT**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- **Sentry Docs**: https://docs.sentry.io

## Summary

**Local Development:**
- Copy `.doppler.example` → `.doppler`
- Run: `doppler setup --project movie_together --config dev`
- Run: `doppler secrets set --project movie_together --config dev`
- Run: `make dev` (automatically uses dev config)

**Production Deployment:**
- Run: `doppler setup --project movie_together --config prd`
- Run: `doppler secrets set --project movie_together --config prd`
- Run: `make deploy` (automatically uses prd config)
