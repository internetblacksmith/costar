# MovieTogether Deployment Secrets Guide

This guide explains how to set up Doppler secrets for MovieTogether development and deployment.

## Overview

**MovieTogether VPS Deployment**: `as.internetblacksmith.dev`

**Deployment Method**: Kamal with Doppler (same as gcal-sinatra and the_void_chronicles)

**Key Principle**: 
- Local development uses **default Doppler config** (no explicit config specified)
- Only deployment explicitly uses `prd` config
- This allows flexibility: developers can use their own Doppler environment

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Local Development (make dev)                           │
│  - Uses: doppler run (default config, no --config flag) │
│  - Developers can set their own Doppler project config  │
│  - Or run without Doppler if not installed              │
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

## Step 2: Set Up Your Local Development Environment

### Option A: Use Doppler for Local Development

```bash
# Set up local development with Doppler
doppler setup --project movie_together

# Add your local development secrets
doppler secrets set
# Enter: TMDB_API_KEY, REDIS_URL
```

Then use normally:
```bash
cd movie_together
make dev  # Uses doppler run with default config
```

### Option B: Run Without Doppler Locally

If you don't want to use Doppler for development:

```bash
cd movie_together
# Create .env file manually with your dev secrets
cp .env.example .env
# Edit .env with TMDB_API_KEY=your_key, REDIS_URL=redis://localhost:6379

make dev  # Will detect no Doppler and run directly
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
- `TMDB_API_KEY` - The Movie Database API key
- `REDIS_URL` - `redis://redis:6380` (VPS Redis)
- `SENTRY_DSN` - Sentry error tracking URL
- `SENTRY_ENVIRONMENT` - `production`

## Deployment

Once production config is set up, anyone can deploy:

```bash
cd movie_together

# 1. Run all checks
make pre-commit

# 2. Deploy (uses prd config automatically)
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

### Development (your local config)

| Secret | Example | Purpose |
|--------|---------|---------|
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://localhost:6379` | Local Redis for caching |

### Production (prd config)

| Secret | Example | Purpose |
|--------|---------|---------|
| `KAMAL_REGISTRY_PASSWORD` | `ghp_...` | GitHub PAT for Docker registry |
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://redis:6380` | VPS Redis for caching |
| `SENTRY_DSN` | `https://xxx@sentry.io/123` | Error tracking endpoint |
| `SENTRY_ENVIRONMENT` | `production` | Environment label for Sentry |

## Getting Required API Keys

### TMDB API Key

1. Visit: https://www.themoviedb.org/settings/api
2. Register/Login if needed
3. Accept API terms
4. Create an API key
5. Copy to your Doppler config (dev and/or prd)

### GitHub Personal Access Token (PAT)

For production deployment only:

1. Visit: https://github.com/settings/tokens/new
2. Create new token with scopes:
   - ✅ `read:packages` - read container images
   - ✅ `write:packages` - push container images
3. Copy token to Doppler prd config as `KAMAL_REGISTRY_PASSWORD`

### Sentry DSN (Optional)

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

# Set up dev environment (Doppler optional)
make setup-dev

# Start development server
make dev
```

### Running Tests Locally

```bash
cd movie_together

# Run all tests
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

## Troubleshooting

### "KAMAL_REGISTRY_PASSWORD not found"

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

### "Doppler not found" during development

This is okay! The app will run without Doppler if you have `.env` file:

```bash
cp .env.example .env
# Edit with your dev secrets
make dev
```

### "Redis connection refused" during development

Make sure Redis is running:

```bash
# Start Redis
make redis-start

# In another terminal
make dev
```

## Reference Links

- **Doppler Docs**: https://docs.doppler.com
- **Kamal Docs**: https://kamal-deploy.org
- **TMDB API**: https://developer.themoviedb.org/docs
- **GitHub PAT**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- **Sentry Docs**: https://docs.sentry.io

## Summary

| Task | Local Dev | Production |
|------|-----------|-----------|
| Doppler config | Optional (default or custom) | Required (prd) |
| `make dev` | Uses default Doppler config | N/A |
| `make deploy` | N/A | Uses prd config automatically |
| Pre-commit hooks | Run before commit | Run before deploy |
| Deploy user | N/A | `deploy` user on VPS |
| Domain | localhost:4567 | as.internetblacksmith.dev |
