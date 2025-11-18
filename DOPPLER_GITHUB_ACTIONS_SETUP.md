# Doppler + GitHub Actions Setup Guide

## ✅ Overview

This project uses **Doppler** with automatic GitHub sync to inject secrets into the GitHub Actions `production` environment. Secrets are automatically synced from Doppler to GitHub, eliminating manual setup.

## 🔑 GitHub Secrets Configuration

### Automatic Sync via Doppler

Since Doppler is configured to sync with GitHub Actions, all secrets from the `movie_together/prd` config are automatically available in the `production` environment.

### Required Secrets (Sensitive - Auto-synced from Doppler):

1. **KAMAL_REGISTRY_PASSWORD** - GitHub PAT for ghcr.io
2. **TMDB_API_KEY** - The Movie Database API key
3. **SENTRY_DSN** - Sentry error tracking DSN
4. **SESSION_SECRET** - Session encryption key
5. **POSTHOG_API_KEY** - PostHog analytics key
6. **SLACK_WEBHOOK_URL** - Slack webhook for notifications
7. **DEPLOY_SSH_PRIVATE_KEY** - SSH key for VPS access

### Required Variables (Non-sensitive - Auto-synced from Doppler):

1. **REDIS_URL** - Redis connection string (`redis://movie-together-redis:6380/0`)
2. **SENTRY_ENVIRONMENT** - Environment name (`production`)

**Note**: Variables are used for non-sensitive configuration that doesn't need encryption.

### Manual Setup (Only if Doppler sync is not working):

If you need to manually add secrets to GitHub Actions:

1. Go to: https://github.com/jabawack81/movie_together/settings/secrets/actions
2. For each secret, click "New repository secret"
3. Get the value from Doppler:
   ```bash
   doppler secrets get SECRET_NAME --project movie_together --config prd --plain
   ```
4. Add to GitHub with the same name

## 📋 How It Works

### Workflow Steps:

1. **Setup SSH** for VPS connection
2. **Create `.kamal/secrets` file** from environment variables (auto-synced from Doppler)
3. **Deploy with Kamal** directly (no Doppler CLI needed)

### Secrets Automatically Available:

All these secrets are synced from Doppler to GitHub Actions `production` environment:

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
