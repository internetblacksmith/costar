# Doppler Setup Guide

This guide covers setting up Doppler for secure environment variable management with ActorSync.

## Why Doppler?

- **Secure**: Encrypted secrets management
- **Team-friendly**: Easy sharing across team members
- **Environment-specific**: Different configs for dev/staging/prod
- **Audit logs**: Track who changed what secrets
- **CI/CD integration**: Works with Render.com and other platforms

**Note**: This implementation uses the Doppler CLI, not a Ruby gem. The app automatically detects if Doppler is available and falls back to `.env` files if not.

## Prerequisites

1. **Doppler Account**: Sign up at [doppler.com](https://doppler.com)
2. **Doppler CLI**: Install the CLI tool

### Install Doppler CLI

```bash
# macOS
brew install dopplerhq/cli/doppler

# Linux
curl -Ls https://cli.doppler.com/install.sh | sh

# Windows
scoop install doppler
```

## Setup Steps

### 1. Create Doppler Project

```bash
# Login to Doppler
doppler login

# Create project
doppler projects create actorsync

# Setup local configuration
doppler setup --project actorsync --config development
```

### 2. Add Secrets to Doppler

```bash
# Add your TMDB API key
doppler secrets set TMDB_API_KEY="your_actual_tmdb_api_key"

# Add optional secrets
doppler secrets set POSTHOG_API_KEY="your_posthog_key"
doppler secrets set RACK_ENV="development"

# Verify secrets
doppler secrets list
```

### 3. Configure Environments

```bash
# Create staging environment
doppler configs create staging --project actorsync

# Create production environment  
doppler configs create production --project actorsync

# Set production secrets
doppler secrets set TMDB_API_KEY="your_api_key" --config production
doppler secrets set RACK_ENV="production" --config production
```

### 4. Local Development

```bash
# Run app with Doppler
doppler run -- bundle exec ruby app.rb

# Or with rerun for development
doppler run -- bundle exec rerun ruby app.rb
```

## Render.com Integration

### Method 1: Doppler Integration (Recommended)

1. **Install Doppler on Render**:
   - Add to your `render.yaml`:
   ```yaml
   buildCommand: |
     curl -Ls https://cli.doppler.com/install.sh | sh
     doppler secrets download --no-file --format env > .env
     bundle install
   ```

2. **Set Doppler Token**:
   - Get service token: `doppler configs tokens create production --project actorsync`
   - Add to Render environment variables: `DOPPLER_TOKEN=dp.st.xxxx`

### Method 2: Manual Environment Variables

If you prefer not to use Doppler on Render:

```bash
# Export secrets for manual setup
doppler secrets download --no-file --format env --config production
```

Copy the output to Render's environment variables section.

## Team Collaboration

### Share Project Access

```bash
# Invite team members
doppler workplace users invite user@example.com --project actorsync

# Set permissions
doppler workplace users update user@example.com --role admin --project actorsync
```

### Environment-Specific Access

```bash
# Give staging access only
doppler configs users invite user@example.com --config staging --project actorsync

# Production access (restricted)
doppler configs users invite user@example.com --config production --project actorsync
```

## Development Workflow

### 1. Clone Repository

```bash
git clone your-repo
cd actorsync
```

### 2. Setup Doppler

```bash
# Setup local config (one time)
doppler setup --project actorsync --config development

# Or copy from team member
cp .doppler.example .doppler
# Edit .doppler with your project details
```

### 3. Install Dependencies

```bash
bundle install
```

### 4. Run Application

```bash
# With Doppler
doppler run -- bundle exec rerun ruby app.rb

# Or run deployment script
doppler run -- ./scripts/deploy.sh
```

## Security Best Practices

### 1. Token Management

```bash
# Use service tokens for CI/CD
doppler configs tokens create production --project actorsync

# Use personal tokens for development
doppler auth login
```

### 2. Environment Separation

- **Development**: Local secrets, can be shared
- **Staging**: Production-like, limited access
- **Production**: Restricted access, audit logs

### 3. Secret Rotation

```bash
# Rotate API keys regularly
doppler secrets set TMDB_API_KEY="new_api_key" --config production

# Verify deployment
doppler secrets get TMDB_API_KEY --config production
```

## Troubleshooting

### Common Issues

**Authentication Errors**:
```bash
doppler auth login
doppler setup --project actorsync --config development
```

**Missing Secrets**:
```bash
doppler secrets list
doppler secrets set MISSING_SECRET="value"
```

**Wrong Environment**:
```bash
doppler configure set config production
```

### Local Development Fallback

The app includes fallback to `.env` files if Doppler fails:

```bash
# Create .env file as backup
cp .env.example .env
# Edit with your local secrets
```

## Migration from dotenv

If you're migrating from dotenv:

1. **Export existing secrets**:
   ```bash
   cat .env | doppler secrets upload --format env
   ```

2. **Verify migration**:
   ```bash
   doppler secrets list
   ```

3. **Update .gitignore**:
   ```
   .env
   .doppler
   ```

4. **Test locally**:
   ```bash
   doppler run -- bundle exec ruby app.rb
   ```

## Next Steps

1. **Set up environments** for your team
2. **Configure CI/CD** with Doppler tokens
3. **Enable audit logging** for production
4. **Set up secret rotation** schedule
5. **Train team** on Doppler workflows

For more details, see the [Doppler documentation](https://docs.doppler.com/).