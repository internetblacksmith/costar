# MovieTogether Deployment Secrets Guide

This guide explains how to set up Doppler secrets for MovieTogether development and deployment.

## Overview

**MovieTogether VPS Deployment**: `as.internetblacksmith.dev`

**Deployment Method**: Kamal with Doppler (same as gcal-sinatra and the_void_chronicles)

**Key Principle**: 
- **Development machines**: Setup and use ONLY `dev` config
- **Deployment commands**: Explicitly specify `prd` config
- **Never set prd on dev machines**: Keeps environments completely separate

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Local Development (Developer Machine)                  │
│  - Setup: doppler setup --project movie_together        │
│           --config dev                                  │
│  - Use: make dev (reads dev config from .doppler)       │
│  - Never has prd config                                 │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  Deployment (Any Machine)                               │
│  - Uses: doppler run --config prd -- kamal deploy       │
│  - Explicitly specifies prd (from CI/CD or ops team)    │
│  - Never uses local .doppler file                       │
└─────────────────────────────────────────────────────────┘
```

## Step 1: Local Development Setup (Dev Machines Only)

### Create Doppler Project (One-Time)

```bash
# Login to Doppler
doppler login

# Create project (one-time, can be done on any machine)
doppler projects create movie_together
```

### Setup Dev Config on Your Machine

```bash
# Setup dev config ONLY (no prd on dev machines!)
doppler setup --project movie_together --config dev

# Add your development secrets
doppler secrets set --project movie_together --config dev
```

Enter development secrets:
- `TMDB_API_KEY` - Your TMDB API key
- `REDIS_URL` - `redis://localhost:6379` (local Redis)

### Your .doppler File (Dev Machine)

```json
{
  "project": "movie_together",
  "config": "dev"
}
```

This file should ONLY have `dev` config. Never add `prd` to your .doppler file.

### Use movie_together Locally

```bash
cd movie_together

# Copy example .doppler file
cp .doppler.example .doppler

# Start development server (uses dev config from .doppler)
make dev
```

## Step 2: Production Config Setup (Ops/CI-CD Only)

**This is NOT done on dev machines. Only authorized personnel set up prd config.**

```bash
# On a secure machine with production access:
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

**Important**: Dev machines should NEVER have the prd config set up locally.

## Deployment

When deploying from CI/CD or authorized ops machines:

```bash
cd movie_together

# Run all checks (uses dev config)
make pre-commit

# Deploy - explicitly specifies prd config
# This works even though prd is NOT set up locally
make deploy
```

The deploy command runs:
```bash
doppler run --config prd -- kamal deploy
```

This explicitly requests the `prd` config from Doppler, even if it's not in your local .doppler file.

## How Doppler Works with Configs

### On Dev Machines
- `.doppler` file contains: `"config": "dev"`
- `make dev` uses: `doppler run --config dev -- ...`
- `make deploy` uses: `doppler run --config prd -- ...` (pulls from Doppler server)
- You never have prd secrets locally

### On CI/CD or Secure Machines
- `.doppler` file contains: `"config": "prd"` (or handled by CI/CD env vars)
- `doppler run --config prd -- ...` pulls production secrets
- All secrets are from Doppler servers, never stored locally

## Required Secrets Reference

### Development Config (dev) - On Dev Machines

| Secret | Example | Purpose |
|--------|---------|---------|
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://localhost:6379` | Local Redis for caching |

**Setup on dev machines:**
```bash
doppler secrets set TMDB_API_KEY="YOUR_KEY" --config dev
doppler secrets set REDIS_URL="redis://localhost:6379" --config dev
```

### Production Config (prd) - Ops/CI-CD Only

| Secret | Example | Purpose |
|--------|---------|---------|
| `KAMAL_REGISTRY_PASSWORD` | `ghp_...` | GitHub PAT for Docker registry |
| `TMDB_API_KEY` | `abc123...` | Movie database API access |
| `REDIS_URL` | `redis://redis:6380` | VPS Redis for caching |
| `SENTRY_DSN` | `https://xxx@sentry.io/123` | Error tracking endpoint |
| `SENTRY_ENVIRONMENT` | `production` | Environment label for Sentry |

**Setup by ops team:**
```bash
doppler secrets set KAMAL_REGISTRY_PASSWORD="ghp_..." --config prd
doppler secrets set TMDB_API_KEY="YOUR_KEY" --config prd
doppler secrets set REDIS_URL="redis://redis:6380" --config prd
doppler secrets set SENTRY_DSN="https://..." --config prd
doppler secrets set SENTRY_ENVIRONMENT="production" --config prd
```

## Getting Required API Keys

### TMDB API Key

1. Visit: https://www.themoviedb.org/settings/api
2. Register/Login if needed
3. Accept API terms
4. Create an API key
5. Add to your dev Doppler config (same key can be used in prod)

### GitHub Personal Access Token (PAT)

For production deployment only:

1. Visit: https://github.com/settings/tokens/new
2. Create new token with scopes:
   - ✅ `read:packages` - read container images
   - ✅ `write:packages` - push container images
3. Add to prd Doppler config (ops team only)

### Sentry DSN (Optional for Production)

For error tracking in production:

1. Create Sentry account: https://sentry.io
2. Create new project (select Ruby/Sinatra)
3. Add DSN URL to prd Doppler config (ops team only)

## Development Workflow

### First Time Setting Up Locally

```bash
cd movie_together

# Install dependencies
make install

# Set up dev environment
make setup-dev

# Setup Doppler dev config ONLY
doppler setup --project movie_together --config dev
doppler secrets set --project movie_together --config dev

# Start development server
make dev
```

### Running Tests Locally

```bash
cd movie_together

# Run all tests (uses dev config)
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

# This explicitly uses --config prd
make deploy

# Watch logs
make deploy-logs

# Rollback if needed
make deploy-rollback
```

## Important: Never Do This on Dev Machines

```bash
# ❌ DON'T DO THIS on your dev machine:
doppler setup --project movie_together --config prd

# ❌ DON'T DO THIS:
cp .doppler .doppler.bak
# edit .doppler to add prd config

# ✅ DO THIS INSTEAD:
# Keep .doppler with only dev config
# Let deployment commands specify --config prd
```

## Troubleshooting

### "Config prd not found" when deploying

This might happen if:
1. Prd config hasn't been set up yet (ops team needs to do it)
2. You don't have access to the prd config (check Doppler permissions)

**Solution**: Ask your ops team to set up the prd config

### "Can't pull Docker image during deployment"

Make sure the prd config has `KAMAL_REGISTRY_PASSWORD`:

```bash
# On a secure machine with prd access:
doppler secrets get KAMAL_REGISTRY_PASSWORD --project movie_together --config prd
```

### "Redis connection refused" during development

Make sure Redis is running locally:

```bash
# Start Redis
make redis-start

# In another terminal
make dev
```

## Environment Separation

| Aspect | Dev Machine | Deployment (CI/CD or Ops) |
|--------|-------------|--------------------------|
| Doppler config | `dev` only | `prd` (explicit param) |
| .doppler file | `"config": "dev"` | N/A or `"config": "prd"` |
| Dev command | `make dev` (uses dev config) | N/A |
| Deploy command | `make deploy` (specifies --config prd) | `make deploy` (specifies --config prd) |
| REDIS_URL | `redis://localhost:6379` | `redis://redis:6380` |
| Monitoring | ❌ Disabled | ✅ Enabled |
| KAMAL_REGISTRY_PASSWORD | ❌ Not available | ✅ From prd config |
| SENTRY_DSN | ❌ Not available | ✅ From prd config |

## Reference Links

- **Doppler Docs**: https://docs.doppler.com
- **Kamal Docs**: https://kamal-deploy.org
- **TMDB API**: https://developer.themoviedb.org/docs
- **GitHub PAT**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- **Sentry Docs**: https://docs.sentry.io

## Summary

**What Dev Machines Do:**
```bash
# One-time setup
doppler setup --project movie_together --config dev
doppler secrets set --project movie_together --config dev

# Daily use
make dev  # uses dev config from .doppler
```

**What Deployment Does:**
```bash
# Deployment explicitly specifies prd
make deploy  # runs: doppler run --config prd -- kamal deploy

# No need for prd to be in local .doppler or setup locally
```

**Key Rule: Dev machines NEVER have prd config**
