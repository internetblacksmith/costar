# CoStar Deployment Secrets Configuration

## Overview

This document outlines all secrets and environment variables required for deploying `costar` to production using GitHub Actions and Kamal.

## Secrets & Variables Checklist

### 1. Doppler Configuration
Project: `costar`, Config: `prd`

**Secrets (marked as secret type in Doppler):**
- [ ] `KAMAL_REGISTRY_PASSWORD` - GitHub Container Registry PAT with `read:packages` and `write:packages` scopes
- [ ] `TMDB_API_KEY` - The Movie Database API key
- [ ] `SESSION_SECRET` - 64+ character secret for Sinatra session encryption
- [ ] `SENTRY_DSN` - Sentry error tracking DSN (optional but recommended)
- [ ] `POSTHOG_API_KEY` - PostHog analytics API key (optional)

**Variables (marked as variable type in Doppler):**
- [ ] `REDIS_URL` - Redis connection URL (e.g., `redis://redis.service.consul:6379`)
- [ ] `SENTRY_ENVIRONMENT` - Environment name for Sentry (e.g., `production`)

### 2. GitHub Repository Secrets
Repo: `internetblacksmith/costar`, Environment: `production`

**Deployment Secrets:**
- [ ] `DEPLOY_SSH_PRIVATE_KEY` - Ed25519 private key for deploy@digitalocean (1447)
- [ ] `SLACK_WEBHOOK_URL` - Slack webhook for deployment notifications (optional)

**Synced from Doppler (via Doppler GitHub integration):**
- [ ] `KAMAL_REGISTRY_PASSWORD`
- [ ] `TMDB_API_KEY`
- [ ] `SESSION_SECRET`
- [ ] `SENTRY_DSN`
- [ ] `POSTHOG_API_KEY`
- [ ] `REDIS_URL` (variable)
- [ ] `SENTRY_ENVIRONMENT` (variable)

## Configuration Sources

### Workflow File: `.github/workflows/deploy.yml`
```yaml
# Secrets used in deploy job
KAMAL_REGISTRY_PASSWORD: ${{ secrets.KAMAL_REGISTRY_PASSWORD }}
TMDB_API_KEY: ${{ secrets.TMDB_API_KEY }}
SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
SESSION_SECRET: ${{ secrets.SESSION_SECRET }}
DEPLOY_SSH_PRIVATE_KEY: ${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}
POSTHOG_API_KEY: ${{ secrets.POSTHOG_API_KEY }}
SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

# Variables used in deploy job
REDIS_URL: ${{ vars.REDIS_URL }}
SENTRY_ENVIRONMENT: ${{ vars.SENTRY_ENVIRONMENT }}
```

### Kamal Config: `config/deploy.yml`
```yaml
registry:
  server: ghcr.io
  username: internetblacksmith
  password: $KAMAL_REGISTRY_PASSWORD  # Gets KAMAL_REGISTRY_PASSWORD from environment

env:
  clear:
    RACK_ENV: production
  secret:
    - TMDB_API_KEY
    - REDIS_URL
    - SENTRY_DSN
    - SENTRY_ENVIRONMENT
    - SESSION_SECRET
```

## Deployment Flow

```
GitHub Push to main
    |
GitHub Actions Workflow Triggers
    |
[Test Job]
- Runs RSpec and Cucumber tests
- Uses test placeholder for TMDB_API_KEY
    |
[Build Job]
- Sets up Docker Buildx
- Logs in to GHCR using GITHUB_TOKEN
- Extracts Docker metadata
- Builds and pushes image to ghcr.io/internetblacksmith/costar
    |
[Deploy Job]
- Reads secrets from GitHub (synced from Doppler)
- Sets up SSH key for deploy@digitalocean
- Runs: kamal deploy
  - Kamal reads env vars from process environment
  - Uses KAMAL_REGISTRY_PASSWORD to authenticate with GHCR
  - Pulls built image
  - Deploys to VPS with all secret env vars
  - Configures Traefik for HTTP/HTTPS at costar.internetblacksmith.dev
    |
Container Running with:
- RACK_ENV=production
- TMDB_API_KEY (from container env)
- REDIS_URL (from container env)
- SENTRY_DSN (from container env)
- SENTRY_ENVIRONMENT (from container env)
- SESSION_SECRET (from container env)
```

## Verification Steps

### 1. Check Doppler Configuration
```bash
# Login to Doppler (if not already logged in)
doppler login

# Switch to costar/prd config
doppler switch

# List all secrets and variables
doppler secrets list

# Verify specific secrets are present
doppler secrets get KAMAL_REGISTRY_PASSWORD
doppler secrets get TMDB_API_KEY
doppler secrets get SESSION_SECRET
doppler secrets get SENTRY_DSN
doppler secrets get POSTHOG_API_KEY

# Verify specific variables
doppler secrets get REDIS_URL
doppler secrets get SENTRY_ENVIRONMENT
```

### 2. Check GitHub Secrets
```bash
# Requires gh CLI and GitHub token

# List repository secrets (shows only names, not values)
gh secret list -R internetblacksmith/costar

# List repository variables
gh variable list -R internetblacksmith/costar

# Check if specific secret exists
gh secret list -R internetblacksmith/costar | grep KAMAL_REGISTRY_PASSWORD
```

### 3. Test Deployment
```bash
# Push a test commit to main
git push origin main

# Watch GitHub Actions workflow
# - Test job should pass
# - Build job should push image to GHCR
# - Deploy job should execute kamal deploy
# - Check Slack notification for success/failure

# Monitor VPS
# - SSH to VPS and check containers
ssh -p 1447 deploy@161.35.165.206
docker ps | grep costar
docker logs costar-web
```

## Troubleshooting

### Docker Registry Authentication Failure
**Error:** `Error response from daemon: Get "https://ghcr.io/v2/": denied: denied`

**Solutions:**
1. Verify KAMAL_REGISTRY_PASSWORD is a valid GitHub PAT
2. PAT must have `read:packages` and `write:packages` scopes
3. PAT must be active (not expired)
4. Check that KAMAL_REGISTRY_PASSWORD is synced to GitHub from Doppler

### Deploy SSH Key Issues
**Error:** `Permission denied (publickey)` when connecting to VPS

**Solutions:**
1. Verify DEPLOY_SSH_PRIVATE_KEY is set in GitHub
2. Verify the public key is in `/home/deploy/.ssh/authorized_keys` on VPS
3. Verify SSH port 1447 is accessible
4. Check Ansible inventory for correct host configuration

### Missing Environment Variables
**Error:** Configuration validation failure in container logs

**Solutions:**
1. Check that all required secrets are in Doppler `prd` config
2. Verify Doppler GitHub integration is synced
3. Check that variables are correctly passed in workflow (secrets vs vars)
4. Review `config/deploy.yml` for correct env variable references

## Additional Resources

- [GitHub Actions Secrets & Variables](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [Doppler GitHub Integration](https://docs.doppler.com/docs/github-actions)
- [Kamal Documentation](https://kamal-deploy.org/)
- [CoStar README](./README.md)
