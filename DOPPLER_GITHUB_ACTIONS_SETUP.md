# Doppler + GitHub Actions Setup Guide

## ✅ Overview

This project uses **Doppler** for centralized secrets management with automatic injection into GitHub Actions workflows. This eliminates the need to manually sync secrets between Doppler and GitHub.

## 🔑 GitHub Secret Required

You only need **ONE** secret in GitHub Actions:

### DOPPLER_TOKEN

**Purpose**: Service token that allows GitHub Actions to fetch all secrets from Doppler

**Value**: `dp.st.prd.TyLOTQGn6V9MPDbUACVsndcPa32XutHnAC2mZSav0xO`

**How to Add**:
1. Go to: https://github.com/jabawack81/movie_together/settings/secrets/actions
2. Click "New repository secret"
3. Name: `DOPPLER_TOKEN`
4. Value: Paste the token above
5. Click "Add secret"

**Important**: Also add `DEPLOY_SSH_PRIVATE_KEY` from Doppler:
```bash
doppler secrets get DEPLOY_SSH_PRIVATE_KEY --project movie_together --config prd --plain
```

## 📋 How It Works

### Workflow Steps:

1. **Install Doppler CLI** (via `dopplerhq/cli-action@v3`)
2. **Fetch all secrets from Doppler** using `DOPPLER_TOKEN`
3. **Create `.kamal/secrets` file** with all application secrets
4. **Deploy with Kamal** using `doppler run -- kamal deploy`

### Secrets Automatically Loaded:

All these secrets are fetched from Doppler's `movie_together/prd` config:

- `KAMAL_REGISTRY_PASSWORD` - GitHub Container Registry auth
- `TMDB_API_KEY` - The Movie Database API key
- `REDIS_URL` - Redis connection string
- `SENTRY_DSN` - Sentry error tracking
- `SENTRY_ENVIRONMENT` - Environment name
- `SESSION_SECRET` - Session encryption key
- `POSTHOG_API_KEY` - PostHog analytics key
- `DEPLOY_SSH_PRIVATE_KEY` - SSH key for VPS
- `SLACK_WEBHOOK_URL` - Slack notifications

## ✅ Doppler Configuration Status

All secrets validated in `movie_together/prd`:

| Secret | Status | Length | Purpose |
|--------|--------|--------|---------|
| KAMAL_REGISTRY_PASSWORD | ✅ | 40 chars | GitHub PAT for ghcr.io |
| TMDB_API_KEY | ✅ | 32 chars | Movie database API |
| REDIS_URL | ✅ | 35 chars | `redis://movie-together-redis:6380/0` |
| SENTRY_DSN | ✅ | 85 chars | Error tracking |
| SENTRY_ENVIRONMENT | ✅ | 10 chars | `production` |
| SESSION_SECRET | ✅ | 64 chars | Session encryption |
| POSTHOG_API_KEY | ✅ | 47 chars | Analytics tracking |
| DEPLOY_SSH_PRIVATE_KEY | ✅ | 386 chars | VPS SSH access |
| SLACK_WEBHOOK_URL | ✅ | 81 chars | Deployment notifications |

## 🔄 Updating Secrets

To update any secret:

1. Update in Doppler:
   ```bash
   doppler secrets set SECRET_NAME="new_value" --project movie_together --config prd
   ```

2. Next deployment automatically uses the new value (no GitHub changes needed!)

## 🚀 Manual Deployment Trigger

To manually trigger a deployment:

1. Go to: https://github.com/jabawack81/movie_together/actions
2. Click "Deploy to Production"
3. Click "Run workflow"
4. Select branch: `main`
5. Click "Run workflow"

## 📊 Deployment Flow

```
Push to main
  ↓
GitHub Actions Triggered
  ↓
Install Ruby + Kamal + Doppler CLI
  ↓
Setup SSH (using DEPLOY_SSH_PRIVATE_KEY from GitHub)
  ↓
Fetch ALL secrets from Doppler (using DOPPLER_TOKEN)
  ↓
Create .kamal/secrets file
  ↓
Run: doppler run -- kamal deploy
  ↓
Deploy to VPS (161.35.165.206:1447)
  ↓
App running at: https://as.internetblacksmith.dev
```

## 🔐 Security Benefits

1. **Single Source of Truth**: All secrets managed in Doppler
2. **Automatic Sync**: No manual secret copying to GitHub
3. **Audit Trail**: Doppler logs all secret changes
4. **Easy Rotation**: Update once in Doppler, applies everywhere
5. **Reduced Attack Surface**: Only 1 token in GitHub vs 7+ secrets

## 🛠️ Local Development

For local deployment:

```bash
# Setup Doppler for this project
doppler setup --project movie_together --config prd

# Create .kamal/secrets file
doppler secrets download --no-file --format env-no-quotes > .kamal/secrets
sed -i 's/^/export /' .kamal/secrets

# Deploy
doppler run -- kamal deploy
```

## 📝 Service Token Management

The `DOPPLER_TOKEN` is a service token for the `prd` config.

**To create a new token** (if needed):
```bash
doppler configs tokens create github-actions-production \
  --config prd \
  --project movie_together \
  --plain
```

**To revoke the current token** (if compromised):
```bash
doppler configs tokens revoke github-actions-production \
  --config prd \
  --project movie_together
```

## 🎯 Next Steps

1. ✅ Add `DOPPLER_TOKEN` to GitHub Secrets
2. ✅ Add `DEPLOY_SSH_PRIVATE_KEY` to GitHub Secrets  
3. ✅ Push to main or manually trigger workflow
4. ✅ Monitor deployment at: https://github.com/jabawack81/movie_together/actions
5. ✅ Verify app at: https://as.internetblacksmith.dev

## 📚 References

- [Doppler GitHub Actions Integration](https://docs.doppler.com/docs/github-actions)
- [Doppler CLI Action](https://github.com/DopplerHQ/cli-action)
- [Kamal Deployment](https://kamal-deploy.org/)
