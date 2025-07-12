# CI/CD Pipeline Setup Guide

This guide explains how to set up the complete CI/CD pipeline for ActorSync using GitHub Actions and Render.com.

## 🏗️ Pipeline Overview

The CI/CD pipeline includes:

- **Continuous Integration**: Automated testing, security scanning, and code quality checks
- **Continuous Deployment**: Automated deployment to staging and production environments
- **Dependency Management**: Weekly security audits and dependency updates
- **Release Management**: Automated releases with changelog generation

## 🔧 Setup Instructions

### 1. GitHub Secrets Configuration

Add the following secrets to your GitHub repository (`Settings` → `Secrets and variables` → `Actions`):

#### Required Secrets

```bash
# Render.com Deploy Hooks
RENDER_PRODUCTION_DEPLOY_HOOK=https://api.render.com/deploy/srv-your-production-service-id?key=your-key
RENDER_STAGING_DEPLOY_HOOK=https://api.render.com/deploy/srv-your-staging-service-id?key=your-key

# Application URLs
PRODUCTION_URL=https://your-app.onrender.com
STAGING_URL=https://your-staging-app.onrender.com

# GitHub Token (usually auto-provided)
GITHUB_TOKEN=ghp_your_github_token
```

#### How to Get Render Deploy Hooks

1. Go to your Render.com dashboard
2. Select your service
3. Go to `Settings` → `Deploy Hook`
4. Copy the webhook URL
5. Add it to GitHub secrets

### 2. Environment Setup

#### GitHub Environments

Create two environments in your GitHub repository:

1. **staging** (`Settings` → `Environments` → `New environment`)
   - Add staging-specific secrets
   - Optional: Add deployment protection rules

2. **production** (`Settings` → `Environments` → `New environment`)
   - Add production-specific secrets
   - **Recommended**: Add required reviewers for production deployments

#### Branch Protection Rules

Set up branch protection for `main` branch:

1. Go to `Settings` → `Branches`
2. Add rule for `main` branch
3. Enable:
   - Require a pull request before merging
   - Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Include administrators

### 3. Render.com Configuration

#### Production Service

```yaml
# render.yaml
services:
  - type: web
    name: actorsync-production
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec puma
    envVars:
      - key: RACK_ENV
        value: production
      - key: TMDB_API_KEY
        sync: false  # Set manually in Render dashboard
      - key: SENTRY_DSN
        sync: false  # Set manually in Render dashboard
      - key: APP_VERSION
        value: main
    healthCheckPath: /health/simple
    plan: starter  # or higher for production
    region: oregon
```

#### Staging Service (Optional)

Create a separate service for staging deployments with similar configuration but different environment variables.

## 🚀 Workflows Explained

### 1. Main CI/CD Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**
- **test**: Runs RSpec test suite with Redis service
- **security**: Bundle audit and Brakeman security scanning
- **lint**: RuboCop code quality checks
- **deploy-staging**: Deploys to staging (develop branch only)
- **deploy-production**: Deploys to production (main branch only)
- **notify**: Sends pipeline status summary

### 2. Dependency Updates (`.github/workflows/dependencies.yml`)

**Triggers:**
- Weekly schedule (Sundays at 6 AM UTC)
- Manual trigger

**Features:**
- Updates all gem dependencies
- Runs security audit
- Creates automated pull request
- Creates security issues if vulnerabilities found

### 3. Release Management (`.github/workflows/release.yml`)

**Triggers:**
- Git tags matching `v*` pattern
- Manual trigger with version input

**Features:**
- Generates changelog from git commits
- Creates GitHub release
- Deploys to production
- Verifies deployment health

## 📋 Usage Guide

### Daily Development

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   # Make your changes
   git commit -m "Add new feature"
   git push origin feature/new-feature
   ```

2. **Create Pull Request**
   - GitHub Actions will automatically run tests, security scans, and lint checks
   - All checks must pass before merging

3. **Merge to Develop** (if using staging)
   - Automatically deploys to staging environment
   - Test your changes in staging

4. **Merge to Main**
   - Automatically deploys to production
   - Monitor deployment in GitHub Actions

### Creating Releases

#### Option 1: Git Tags
```bash
git tag v1.2.3
git push origin v1.2.3
```

#### Option 2: GitHub UI
1. Go to repository → `Actions`
2. Select `Release` workflow
3. Click `Run workflow`
4. Enter version number

### Emergency Deployments

If you need to deploy immediately without waiting for the full pipeline:

```bash
# Trigger manual deployment via Render webhook
curl -X POST "https://api.render.com/deploy/srv-your-service-id?key=your-key"
```

## 🔍 Monitoring & Troubleshooting

### Pipeline Status

Monitor pipeline status at:
- GitHub Actions tab in your repository
- Render.com deployment logs
- Application health endpoint: `/health/simple`

### Common Issues

#### 1. Test Failures
- Check test logs in GitHub Actions
- Ensure environment variables are set correctly
- Verify Redis service is running in CI

#### 2. Security Scan Failures
- Review bundle-audit and Brakeman reports
- Update vulnerable dependencies
- Fix security issues before deployment

#### 3. Deployment Failures
- Check Render.com build logs
- Verify environment variables in Render dashboard
- Ensure health check endpoint is responding

#### 4. Health Check Failures
- Verify application is starting correctly
- Check database/Redis connectivity
- Review application logs in Render

### Debugging Commands

```bash
# Run tests locally
bundle exec rspec

# Run security audit locally
gem install bundle-audit brakeman
bundle audit --update
brakeman --no-pager

# Run linting locally
bundle exec rubocop

# Test health endpoint locally
curl http://localhost:4567/health/simple
```

## 🛡️ Security Considerations

### Secrets Management
- Never commit secrets to git
- Use GitHub secrets for sensitive data
- Rotate secrets regularly
- Use environment-specific secrets

### Branch Protection
- Require pull request reviews
- Require status checks to pass
- Restrict who can push to main
- Enable administrator enforcement

### Dependency Security
- Weekly automated security audits
- Automatic vulnerability alerts
- Required security approval for production

## 📊 Pipeline Metrics

### Success Indicators
- ✅ All tests passing
- ✅ Security scans clean
- ✅ Code quality checks passing
- ✅ Successful deployments
- ✅ Health checks passing

### Performance Targets
- **Test Suite**: < 5 minutes
- **Security Scan**: < 2 minutes
- **Deployment**: < 3 minutes
- **Total Pipeline**: < 10 minutes

## 🔄 Maintenance

### Weekly Tasks
- Review dependency update PRs
- Monitor security scan results
- Check deployment success rates

### Monthly Tasks
- Review and update pipeline configuration
- Analyze pipeline performance metrics
- Update documentation as needed

### Quarterly Tasks
- Security audit of CI/CD pipeline
- Review branch protection rules
- Update runner versions and actions

---

## 🆘 Support

For issues with the CI/CD pipeline:

1. Check GitHub Actions logs
2. Review Render.com deployment logs
3. Verify environment variables and secrets
4. Test locally before debugging CI

**Pipeline Status**: All systems operational ✅