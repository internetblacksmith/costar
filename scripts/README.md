# CoStar Environment Validation Scripts

This directory contains comprehensive environment validation tools for the CoStar application.

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
## cleanup_workflow_runs.sh

Automated cleanup script for GitHub Actions workflow runs. Deletes failed and cancelled runs to keep your Actions history clean.

### Features

- ✅ Automatic 1Password authentication
- ✅ Unsets conflicting GITHUB_TOKEN environment variable
- ✅ Shows summary of runs before deletion
- ✅ Confirmation prompt before deleting
- ✅ Progress indicator during deletion
- ✅ Colored output for better readability
- ✅ Error handling and validation

### Usage

```bash
# Run the script
./scripts/cleanup_workflow_runs.sh

# Or from anywhere in the repo
bash scripts/cleanup_workflow_runs.sh
```

### Requirements

- `gh` CLI installed: https://cli.github.com/
- `op` CLI installed: https://developer.1password.com/docs/cli
- GitHub token stored in 1Password at: `op://Personal/github/token`
- Token must have permissions:
  - Actions: Read and write
  - Metadata: Read

### What It Does

1. Checks for required tools (gh, op)
2. Unsets any conflicting GITHUB_TOKEN environment variable
3. Signs in to 1Password (if needed)
4. Authenticates gh CLI using token from 1Password
5. Shows summary of workflow runs (total, failed, cancelled, successful)
6. Asks for confirmation
7. Deletes all failed runs
8. Deletes all cancelled runs
9. Shows final summary

### Example Output

```
========================================
GitHub Workflow Runs Cleanup
========================================

Checking 1Password authentication...
✅ 1Password authenticated

Authenticating GitHub CLI...
✅ GitHub CLI authenticated

Current Workflow Runs Summary:

  Total runs:     45
  Successful:     12
  Failed:         28
  Cancelled:      5

This will delete:
  - 28 failed runs
  - 5 cancelled runs

Continue? (y/N): y

Deleting workflow runs...

Deleting 28 failed runs...
  Deleted: 28/28
✅ Deleted 28 failed runs

Deleting 5 cancelled runs...
  Deleted: 5/5
✅ Deleted 5 cancelled runs

========================================
✅ Cleanup Complete!
========================================

Remaining workflow runs: 12
```

### Customization

Edit the script to change:

- **1Password token path**: Update `ONE_PASSWORD_TOKEN_PATH` variable
- **Delete strategy**: Modify the run deletion logic to keep certain runs
- **Confirmation**: Remove the confirmation prompt for fully automated cleanup

### Troubleshooting

**Error: gh CLI is not installed**
```bash
# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

**Error: 1Password CLI is not installed**
```bash
# macOS
brew install 1password-cli

# Linux
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update
sudo apt install 1password-cli
```

**Error: Failed to authenticate gh CLI**

Your GitHub token may be invalid or expired:
1. Generate a new token: https://github.com/settings/tokens?type=beta
2. Required permissions: Actions (read/write), Metadata (read)
3. Save to 1Password at `op://Personal/github/token`
4. Run the script again

### Integration with Make

Add to `Makefile`:
```makefile
.PHONY: cleanup-runs
cleanup-runs:
	@bash scripts/cleanup_workflow_runs.sh
```

Then run:
```bash
make cleanup-runs
```
