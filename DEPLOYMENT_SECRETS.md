# MovieTogether Deployment Secrets Guide

This guide explains how to set up Doppler secrets for MovieTogether deployment to the VPS.

## Overview

MovieTogether is deployed to: **as.internetblacksmith.dev**

Deployment method: **Kamal with Doppler** (same as gcal-sinatra and the_void_chronicles)

## Required Doppler Setup

### 1. Create Doppler Project (if not already created)

```bash
# Login to Doppler
doppler login

# Create project (one-time)
doppler projects create movie_together
```

### 2. Create Doppler Configs

Two configurations needed:

#### Dev Config (Local Development)
```bash
doppler setup --project movie_together --config dev
```

#### Production Config (VPS Deployment)
```bash
doppler setup --project movie_together --config prd
```

## Required Secrets

### All Environments (dev + prd)

| Secret | Description | Example |
|--------|-------------|---------|
| `TMDB_API_KEY` | The Movie Database API Key | `abc123...` |
| `REDIS_URL` | Redis connection string | `redis://redis:6379` (dev) or `redis://localhost:6380` (prod) |

### Production Only (prd)

| Secret | Description | Example |
|--------|-------------|---------|
| `KAMAL_REGISTRY_PASSWORD` | GitHub PAT for ghcr.io (GitHub Container Registry) | `ghp_...` |
| `SENTRY_DSN` | Sentry error tracking URL | `https://xxx@sentry.io/123` |
| `SENTRY_ENVIRONMENT` | Sentry environment label | `production` |

## Setting Up Secrets in Doppler

### 1. Configure Dev Secrets

```bash
doppler secrets set --project movie_together --config dev
```

Then interactively enter:
- `TMDB_API_KEY`: Your TMDB API key
- `REDIS_URL`: `redis://localhost:6379` (local Redis)

### 2. Configure Production Secrets

```bash
doppler secrets set --project movie_together --config prd
```

Then interactively enter:
- `KAMAL_REGISTRY_PASSWORD`: GitHub PAT token
- `TMDB_API_KEY`: Your TMDB API key (same as dev)
- `REDIS_URL`: `redis://redis:6380` (VPS Redis port)
- `SENTRY_DSN`: Your Sentry project URL
- `SENTRY_ENVIRONMENT`: `production`

## Getting Required API Keys

### TMDB API Key

1. Visit: https://www.themoviedb.org/settings/api
2. Register/Login to TMDB
3. Accept terms and create an API key
4. Copy the key and add to Doppler

### GitHub PAT (Personal Access Token)

For `KAMAL_REGISTRY_PASSWORD`:

1. Visit: https://github.com/settings/tokens/new
2. Create new token with scopes:
   - `read:packages` - read container images
   - `write:packages` - push container images
3. Copy the token to Doppler

### Sentry DSN (Optional)

1. Create Sentry account: https://sentry.io
2. Create new project (select Ruby/Sinatra)
3. Copy the DSN URL to Doppler

## Deployment Workflow

### First-Time Deployment

```bash
# 1. Setup dev environment
cd movie_together
make setup-dev

# 2. Setup deployment environment
make setup-deploy

# 3. Verify Doppler is configured
doppler configure get project --plain

# 4. Generate .kamal/secrets file
make kamal-secrets-setup

# 5. Deploy!
make deploy
```

### Subsequent Deployments

```bash
cd movie_together

# Just deploy (all checks included)
make deploy

# Or use the interactive menu
make menu
```

## Environment-Specific Notes

### Development (`dev` config)

- `REDIS_URL`: Points to localhost Redis
- No error tracking (Sentry DSN optional)
- Can skip KAMAL_REGISTRY_PASSWORD

### Production (`prd` config)

- `REDIS_URL`: Points to VPS Redis (port 6380)
- All secrets required
- Sentry DSN recommended for error tracking

## Troubleshooting

### "KAMAL_REGISTRY_PASSWORD not found"

Make sure it's set in Doppler prd config:
```bash
doppler secrets get KAMAL_REGISTRY_PASSWORD --project movie_together --config prd
```

### "Can't pull Docker image"

1. Verify PAT token has `read:packages` scope
2. Check token is set correctly in Doppler
3. Test manually: `echo $KAMAL_REGISTRY_PASSWORD | docker login ghcr.io -u jabawack81 --password-stdin`

### "Redis connection refused"

1. Check `REDIS_URL` matches VPS Redis setup
2. Verify Redis is running: `make redis-start`
3. Verify port 6380 is not blocked

## Next Steps

1. **Setup Doppler**: Run `doppler setup` for dev and prd
2. **Add Secrets**: Use `doppler secrets set` for each config
3. **Deploy**: Run `make deploy`
4. **Monitor**: Check logs with `make deploy-logs`

## Reference Links

- **Doppler Docs**: https://docs.doppler.com
- **Kamal Docs**: https://kamal-deploy.org
- **TMDB API**: https://developer.themoviedb.org/docs
- **GitHub PAT**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- **Sentry**: https://docs.sentry.io
