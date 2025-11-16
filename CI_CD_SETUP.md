# CI/CD Setup Guide - GitHub Actions + Kamal + Dependabot

Complete guide for setting up automated CI/CD with GitHub Actions, Kamal deployment, and Dependabot dependency management.

## Overview

The CI/CD pipeline automates:

1. **Continuous Integration** (on every push/PR)
   - RSpec tests (487 examples)
   - Cucumber E2E tests (7 scenarios)
   - Security scans (Brakeman, Bundle Audit)
   - Code quality checks (RuboCop)

2. **Automated Deployment** (on merge to main)
   - Build Docker image
   - Push to GitHub Container Registry (GHCR)
   - Deploy to production with Kamal
   - Requires manual approval (GitHub Environment)

3. **Dependency Updates** (weekly via Dependabot)
   - Auto-merge safe updates (dev dependencies, patches)
   - Manual review for major versions
   - Automatic test & security scans

## Prerequisites

- GitHub repository access
- DigitalOcean VPS with SSH access (port 1447)
- Doppler account & token
- Docker registry credentials (GHCR token)

## Setup Steps

### Step 1: Generate SSH Key for Deployment

Generate an ED25519 key on your local machine:

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -f ~/.ssh/vps_deploy_key -C "github-actions@movie-together"
# Press Enter twice (no passphrase)

# Get private key
cat ~/.ssh/vps_deploy_key
```

Add public key to your VPS:

```bash
# Copy public key
cat ~/.ssh/vps_deploy_key.pub

# SSH into your VPS (as deploy user)
ssh -p 1447 deploy@161.35.165.206

# Add to authorized_keys
echo "your-public-key-here" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

Test SSH connection:

```bash
ssh -i ~/.ssh/vps_deploy_key -p 1447 deploy@161.35.165.206 "echo 'SSH works!'"
```

### Step 2: Add GitHub Secrets

Go to: **GitHub Repo > Settings > Secrets and variables > Actions > New repository secret**

Add these secrets:

#### `DEPLOY_SSH_PRIVATE_KEY` (Required)
```
Value: (paste entire private key from ~/.ssh/vps_deploy_key)
```

#### `DOPPLER_TOKEN` (Required)
```bash
# Get your Doppler token
doppler login
doppler token create github-actions

# Or view at: https://dashboard.doppler.com/workplace/default/tokens
```

#### `SLACK_WEBHOOK_URL` (Optional - for CI/CD notifications)

To receive Slack notifications for CI/CD events (tests, builds, deployments), set up a Slack app:

**Step 1: Create Slack App from Manifest**

1. Go to: https://api.slack.com/apps
2. Click **"Create New App"**
3. Select **"From an app manifest"**
4. Choose your workspace
5. Copy and paste this JSON manifest:

```json
{
  "display_information": {
    "name": "CI/CD Notifications",
    "description": "Receives GitHub Actions notifications for CI/CD pipelines",
    "background_color": "#000000"
  },
  "features": {
    "bot_user": {
      "display_name": "CI/CD Bot",
      "always_online": true
    }
  },
  "oauth_config": {
    "scopes": {
      "bot": [
        "chat:write",
        "chat:write.public"
      ]
    }
  },
  "settings": {
    "org_deploy_enabled": false,
    "socket_mode_enabled": false,
    "token_rotation_enabled": false
  }
}
```

6. Click **"Create"**

**Step 2: Add Incoming Webhook**

1. In your new app, go to **"Incoming Webhooks"** (left sidebar)
2. Click **"Add New Webhook to Workspace"**
3. Select the channel where you want notifications (e.g., `#deployments` or `#ci-cd`)
4. Click **"Allow"**
5. Copy the **Webhook URL** (looks like: `https://hooks.slack.com/services/...`)

**Step 3: Add to GitHub Secrets**

1. Go to: **GitHub Repo > Settings > Secrets and variables > Actions**
2. Click **"New repository secret"**
3. Name: `SLACK_WEBHOOK_URL`
4. Value: Paste the webhook URL from Step 2
5. Click **"Add secret"**

**What you'll receive in Slack:**
- ✅ Deployment success notifications
- ❌ Deployment failure alerts
- 🔗 Direct links to GitHub Actions runs
- 📊 Commit, branch, and repository info

### Step 3: Create GitHub Environment

1. Go to: **GitHub Repo > Settings > Environments**
2. Click **New environment**
3. Name: `production`
4. Enable: **Required reviewers**
5. Add reviewers (your GitHub username or team members)
6. Optional: **Deployment branches** → restrict to `main`

This ensures every deployment requires approval.

### Step 4: Verify Workflow Files

The repository should have these workflow files:

```
.github/workflows/
├── ci.yml                    # Existing (runs tests)
├── deploy.yml                # NEW (builds & deploys)
└── dependencies.yml          # Existing (Dependabot)
```

Check deployment workflow:

```bash
cd /home/jabawack81/projects/vps-config/movie_together
cat .github/workflows/deploy.yml | head -20
```

## How It Works

### On Every Pull Request:

```
PR Created
  ↓
CI Tests Run (2 min)
  ├─ RSpec: 487 examples
  ├─ Cucumber: 7 scenarios  
  ├─ Security checks
  └─ Code quality
  ↓
Status shown on PR
```

### On Merge to Main:

```
PR Merged to main
  ↓
CI Tests Run Again (2 min)
  ↓
Tests Pass ✅
  ↓
Build Docker Image (4-5 min)
  ├─ Run tests in container
  ├─ Push to GHCR
  └─ Tag with commit SHA
  ↓
Waiting for Approval ⏳
  (GitHub Environment requires reviewer approval)
  ↓
Reviewer Approves
  ↓
Deploy to Production (3-4 min)
  ├─ SSH to VPS
  ├─ Kamal deploys
  ├─ Runs health checks
  └─ Notifies Slack (if configured)
  ↓
Deployment Complete ✅
  (or Rollback ↩️ if failed)
```

### Dependabot Updates (Weekly):

```
Dependabot checks for updates
  ↓
Development dependency (e.g., rspec)?
  ├─ YES → Auto-merge ✅
  │        PR merged
  │        CI runs
  │        Auto-deploys (requires approval)
  │
  └─ NO (production dependency)
     └─ Patch update (1.0.x → 1.0.y)?
        ├─ YES → Auto-merge with caution ✅
        └─ NO (minor/major) → Manual review 👤
           PR created with "Needs Review"
           Requires explicit approval
```

## Testing the Workflow

### Test 1: Verify SSH Works

```bash
# From your local machine
ssh -i ~/.ssh/vps_deploy_key -p 1447 deploy@161.35.165.206 "whoami"
# Should output: deploy
```

### Test 2: Trigger Manual Deployment

```bash
# Go to GitHub Repo > Actions > Deploy to Production
# Click "Run workflow"
# Select "production" environment
# Click "Run workflow"
# Monitor logs
```

### Test 3: Local Docker Build

```bash
cd /home/jabawack81/projects/vps-config/movie_together

# Build image
docker build -t movie-together:test .

# Run tests in container
docker run -e RACK_ENV=test movie-together:test bundle exec rspec
```

## Troubleshooting

### Issue: "SSH permission denied"

**Diagnosis:**
```bash
# Test SSH locally
ssh -i ~/.ssh/vps_deploy_key -p 1447 deploy@161.35.165.206 "echo works"
```

**Solutions:**
1. Verify VPS IP is correct: `161.35.165.206`
2. Verify SSH port is correct: `1447`
3. Check public key is in VPS `~/.ssh/authorized_keys`
4. Regenerate key and update GitHub Secret

### Issue: "Doppler token invalid"

**Solution:**
```bash
# Generate new token
doppler login
doppler token create github-actions

# Copy to GitHub Secrets > DOPPLER_TOKEN
```

### Issue: "Docker build fails"

**Diagnosis:**
```bash
# Check Dockerfile
cat Dockerfile | head -20

# Build locally to test
docker build -t movie-together:test .
```

**Common causes:**
- Missing Gemfile.lock
- Base image not available
- Port conflicts

### Issue: "Deployment waiting forever"

**Cause:** Waiting for approval

**Solution:**
1. Go to Actions tab
2. Find the deployment run
3. Click "Review deployments"
4. Select "production" environment
5. Click "Approve and deploy"

### Issue: "Health check failing"

**Diagnosis:**
```bash
# SSH to VPS
ssh -p 1447 deploy@161.35.165.206

# Check container status
docker ps | grep movie

# View logs
docker logs <container-id>

# Test health endpoint
curl http://localhost:4567/health || curl http://localhost:4567/
```

## Dependabot Configuration

### Current Rules

Edit `.github/dependabot.yml` to customize:

**Development Dependencies** (auto-merge):
```yaml
groups:
  development-dependencies:
    patterns:
      - "rspec*"
      - "cucumber*"
      - "capybara*"
      - # ... other dev gems
    dependency-type: "development"
```

**Production Dependencies** (manual review):
```yaml
groups:
  production-patch-updates:
    patterns:
      - "*"
    exclude-patterns:
      - "rspec*"  # Already in dev group
    update-types:
      - "minor"
      - "patch"
```

### Examples of Auto-Merge:

✅ **Auto-merged**:
- rspec 3.12.0 → 3.13.0 (dev dependency)
- redis 4.8.0 → 4.8.1 (patch)
- sinatra 3.0.5 → 3.0.6 (patch)

❌ **Manual review**:
- sinatra 3.x → 4.x (major)
- ruby 3.2 → 3.3 (major)
- redis 4.x → 5.x (major)

## Security Best Practices

### 1. SSH Key Rotation (Every 3 months)

```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/vps_deploy_key_new

# Update VPS
ssh -p 1447 deploy@161.35.165.206
# Add new public key
# Remove old public key

# Update GitHub Secret with new private key
```

### 2. Doppler Token Rotation (Every 6 months)

```bash
# Generate new token
doppler token create github-actions-new

# Update GitHub Secret
# Delete old token from Doppler dashboard
```

### 3. Review Approvers

Regularly audit who can approve production deployments:

```
Settings > Environments > production > Required reviewers
```

### 4. Monitor Deployments

```bash
# Check recent deployments
kamal app details

# View production logs
kamal app logs

# Check Sentry for errors
# https://sentry.io/organizations/your-org/
```

## Monitoring & Debugging

### View CI Status

```bash
# GitHub Actions page
https://github.com/your-repo/actions

# Recent runs
- Click workflow name to see details
- Click job to see step logs
```

### View Deployment Status

```bash
# From local machine
kamal app details

# Or SSH to VPS
ssh -p 1447 deploy@161.35.165.206
docker ps
docker logs movie-together
```

### View Production Logs

```bash
# Stream live logs
kamal app logs

# Or with SSH
ssh -p 1447 deploy@161.35.165.206
docker logs -f $(docker ps | grep movie | awk '{print $1}')
```

### Sentry Error Monitoring

All production errors automatically sent to:
- https://sentry.io/organizations/your-org/issues/

### Slack Notifications

If Slack webhook configured:
- ✅ Deployment success
- ❌ Deployment failure
- 📊 Coverage reports (optional)

## Common Workflows

### Deploy a Hotfix:

```bash
# 1. Create branch
git checkout -b hotfix/critical-issue

# 2. Make changes
# ... edit files ...

# 3. Test locally
make test

# 4. Push and create PR
git add .
git commit -m "fix: critical issue"
git push origin hotfix/critical-issue

# 5. Go to GitHub, create PR
# 6. CI runs automatically
# 7. Merge PR when tests pass

# 8. Wait for approval prompt in Actions
# 9. Reviewer approves
# 10. Auto-deploys to production
```

### Roll Back Failed Deployment:

```bash
# Quick rollback
kamal rollback

# Verify
kamal app details
kamal app logs
```

### Manually Test Deployment Locally:

```bash
# Build Docker image
docker build -t movie-together:test .

# Run container
docker run -p 4567:4567 \
  -e RACK_ENV=production \
  -e TMDB_API_KEY=test_key \
  movie-together:test

# Test in another terminal
curl http://localhost:4567
```

## Performance Tips

### Speed Up Deployments:

1. **Docker caching**: Workflows use GitHub Actions cache
   - First build: 5 min
   - Subsequent builds: 2-3 min

2. **Parallel jobs**: CI jobs run in parallel
   - Tests: 2 min
   - Build: 4 min
   - Total: 6-7 min (parallel)

3. **Deploy only on main**: Reduce unnecessary deployments
   - Feature branches: only CI
   - Main branch: CI + Deploy

### Reduce Test Duration:

```bash
# Current: 2 minutes
# RSpec: 1 min
# Cucumber: 1 min

# Optimize if needed:
# - Parallelize RSpec: bundle exec parallel_test
# - Skip slow tests in CI: add @skip_slow tag
```

## References

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Kamal Deployment](https://kamal-deploy.org/)
- [Dependabot Docs](https://docs.github.com/en/code-security/dependabot)
- [Doppler Docs](https://docs.doppler.com/)
- [Docker GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## Support

For issues:

1. Check workflow logs: **Actions > [workflow name] > View logs**
2. Test locally: `make test`, `docker build`, etc.
3. Check Kamal status: `kamal app details`
4. Monitor production: `kamal app logs`
5. Review Sentry: https://sentry.io

---

**Last Updated**: November 2025
**Status**: ✅ Ready to deploy
