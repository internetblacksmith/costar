# movie_together Deployment Status & Next Steps

## Current Status

### ✅ Completed

#### Infrastructure & Configuration
- [x] GitHub Actions Deploy Workflow (`.github/workflows/deploy.yml`)
  - Valid YAML with proper syntax
  - Three jobs: test, build, deploy
  - Correct secrets/variables distinction
  - SSH setup for VPS connectivity
  - Docker build and push to GHCR
  - Kamal deploy execution
  - Slack notifications on success/failure

- [x] Kamal Configuration (`config/deploy.yml`)
  - Proper registry authentication with GHCR
  - Traefik routing to `as.frenimies-lab.dev`
  - Redis accessory configuration
  - Volume and persistence setup
  - Environment variable declarations

- [x] Git Submodule Setup
  - movie_together registered in `.gitmodules`
  - SSH URL configured: `git@github.com:Frenimies-Solutions/movie_together.git`
  - Accessible from vps-config parent repo

- [x] Documentation
  - `DEPLOYMENT_SECRETS.md` - Comprehensive secrets configuration guide
  - Includes verification steps and troubleshooting
  - Deployment flow diagram
  - All required secrets listed

### 📋 Required Actions Before First Deployment

The following must be verified/configured in Doppler and GitHub before deployment can succeed:

#### 1. Doppler Configuration (movie_together/prd)
**Secrets** (marked as type "secret"):
- [ ] `KAMAL_REGISTRY_PASSWORD` - GitHub PAT with packages scopes
- [ ] `TMDB_API_KEY` - Movie Database API key
- [ ] `SESSION_SECRET` - 64+ character random string
- [ ] `SENTRY_DSN` - Sentry error tracking (optional)
- [ ] `POSTHOG_API_KEY` - Analytics API key (optional)

**Variables** (marked as type "variable"):
- [ ] `REDIS_URL` - Redis connection string
- [ ] `SENTRY_ENVIRONMENT` - Environment name

#### 2. GitHub Repository Secrets
Repo: `Frenimies-Solutions/movie_together`

**Secrets that must be manually set:**
- [ ] `DEPLOY_SSH_PRIVATE_KEY` - Ed25519 private key for deploy@digitalocean
- [ ] `SLACK_WEBHOOK_URL` - Slack webhook for notifications (optional)

**Secrets synced from Doppler:**
- These will appear automatically once Doppler GitHub integration is configured
- Expected: KAMAL_REGISTRY_PASSWORD, TMDB_API_KEY, SESSION_SECRET, SENTRY_DSN, POSTHOG_API_KEY

**Variables synced from Doppler:**
- These will appear automatically once Doppler GitHub integration is configured
- Expected: REDIS_URL, SENTRY_ENVIRONMENT

#### 3. VPS Infrastructure (Already Configured)
- [x] Deploy user created on VPS
- [x] SSH key pair generated
- [x] SSH port 1447 open
- [x] Docker and Docker Compose installed
- [x] Traefik configured and running
- [x] Redis 7.4 running on port 6380
- [x] Let's Encrypt certificates configured

## Deployment Flow

```
User pushes to main branch
    ↓
GitHub Actions workflow triggers
    ↓
Test Job
├─ Sets up Ruby 4.0.1
├─ Runs bundle install (cached)
├─ Sets up Chrome for Cuprite
├─ Runs RSpec test suite
├─ Runs Cucumber feature tests
└─ Runs security checks (Brakeman, bundle-audit)
    ↓
[Only if tests pass]
Build Job
├─ Sets up Docker Buildx
├─ Logs in to GHCR with GITHUB_TOKEN
├─ Extracts image metadata
├─ Builds Docker image
└─ Pushes to ghcr.io/jabawack81/movie_together:main-<sha>
    ↓
[Only if build succeeds]
Deploy Job (requires production environment secrets)
├─ Sets up Ruby and Kamal
├─ Configures SSH for VPS connectivity
├─ Executes: kamal deploy
│  ├─ Authenticates with GHCR using KAMAL_REGISTRY_PASSWORD
│  ├─ Pulls built image
│  ├─ Stops previous container
│  ├─ Starts new container with environment variables
│  ├─ Configures Traefik routing
│  └─ Verifies deployment
├─ Checks deployment status
└─ Sends Slack notification
    ↓
Application running at https://as.frenimies-lab.dev
```

## What Gets Deployed

### Container Environment Variables
These variables are injected into the Docker container at runtime:

```
RACK_ENV=production
TMDB_API_KEY=<from secrets>
REDIS_URL=<from variables>
SENTRY_DSN=<from secrets>
SENTRY_ENVIRONMENT=<from variables>
SESSION_SECRET=<from secrets>
```

### Container Configuration
- **Port**: 4567 (exposed via Traefik)
- **RAM**: No limit set (may need tuning)
- **Restart**: always (restarts on failure)
- **DNS**: Uses VPS network configuration
- **Network**: docker network "private"
- **Logging**: Driver: json-file, Max size: 10m

### Traefik Routing
- **Domain**: as.frenimies-lab.dev
- **Protocol**: HTTPS (Let's Encrypt)
- **HTTP Redirect**: Automatic redirect to HTTPS
- **Upstream Port**: 4567
- **Load Balancer**: Round-robin (single container)

## Next Steps (In Order)

### 1. Verify/Configure Doppler
See `DEPLOYMENT_SECRETS.md` Section "Verification Steps" -> "Check Doppler Configuration"

### 2. Verify GitHub Secrets
See `DEPLOYMENT_SECRETS.md` Section "Verification Steps" -> "Check GitHub Secrets"

### 3. Configure Missing GitHub Secrets
Must manually set:
- `DEPLOY_SSH_PRIVATE_KEY` - from VPS
- `SLACK_WEBHOOK_URL` - from your Slack workspace (optional)

### 4. Test Deployment
Push a test commit to main and monitor:
- Test job completes successfully
- Docker image builds and pushes to GHCR
- Kamal deploy executes without errors
- Slack notification sent (if configured)

### 5. Verify Application
- Check container is running: `docker ps | grep movie`
- Check logs: `docker logs movie-together-web`
- Test health endpoint: `curl -I https://as.frenimies-lab.dev/health`
- Test application: Browse to `https://as.frenimies-lab.dev`

## Troubleshooting Common Issues

### Docker Registry Authentication Failure
**Error**: `Error response from daemon: Get "https://ghcr.io/v2/": denied: denied`

**Fix**:
1. Verify KAMAL_REGISTRY_PASSWORD in Doppler
2. Ensure GitHub PAT has `read:packages` and `write:packages` scopes
3. Verify token is not expired
4. Force sync: Push new commit to trigger workflow

### SSH Connection Failure
**Error**: `Permission denied (publickey)` when connecting to VPS

**Fix**:
1. Verify DEPLOY_SSH_PRIVATE_KEY is set in GitHub
2. Verify public key is in `/home/deploy/.ssh/authorized_keys` on VPS
3. Test manually: `ssh -p 1447 deploy@161.35.165.206 "whoami"`

### Configuration Validation Failure
**Error**: Container exits with configuration validation errors

**Fix**:
1. Check all required secrets are in Doppler
2. Verify Doppler GitHub integration is synced
3. Check container logs for specific missing variables
4. Ensure SECRET vs VARIABLE distinction is correct in workflow

### Application Crashes
**Fix**:
1. Check container logs: `docker logs movie-together-web -f`
2. Verify REDIS_URL is accessible
3. Verify TMDB_API_KEY is valid
4. Check if dependencies need updating

## Important Notes

- **Doppler Sync**: GitHub automatically syncs Doppler secrets/variables every 15 minutes
- **First Sync**: May take up to 15 minutes after Doppler GitHub integration setup
- **Manual Force Sync**: Push a commit to trigger workflow (uses current cached values)
- **Log Retention**: GitHub Actions logs retained for 90 days
- **Docker Registry**: Images kept for 90 days (configurable)
- **Notifications**: Slack integration is optional but highly recommended

## File References

- Workflow: `.github/workflows/deploy.yml`
- Kamal Config: `config/deploy.yml`
- Secrets Guide: `DEPLOYMENT_SECRETS.md`
- Configuration Validator: `lib/services/configuration_validator.rb`
- App Entry: `app.rb`
