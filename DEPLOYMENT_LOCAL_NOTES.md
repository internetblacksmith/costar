# Local Deployment Notes

## Known Issue: Docker Login with Kamal

The local `make deploy` command will fail at the `docker login` step with:
```
Error response from daemon: Get "https://ghcr.io/v2/": denied: denied
```

This happens because:
1. The GitHub token IS valid (✅ our validation confirms this)
2. `docker login --password-stdin` works correctly
3. Kamal uses `docker login -p` which fails on some Docker daemon configurations

## Why GitHub Actions Works

GitHub Actions deploys successfully because it uses a different environment with potentially different Docker daemon behavior or version.

## Workaround Options

### Option 1: Use GitHub Actions (Recommended)
Push to `main` branch and GitHub Actions will deploy automatically. This is the intended deployment method.

### Option 2: Deploy from Different Machine
If you need to deploy locally, try from a different machine/environment where `docker login -p` works properly.

### Option 3: Manual Docker Login
```bash
# Pre-authenticate before running deploy
PASSWORD=$(doppler secrets get KAMAL_REGISTRY_PASSWORD --config prd --plain)
echo "$PASSWORD" | docker login ghcr.io -u internetblacksmith --password-stdin

# Then run kamal commands directly (secrets fetched by .kamal/secrets Doppler adapter)
bundle exec kamal build push
bundle exec kamal deploy
```

## Token Validation

The deploy script includes a GitHub token validation step that confirms:
- Token is present in Doppler ✅
- Token is valid and not expired ✅
- Token can authenticate with GHCR ✅

If validation fails, it provides clear instructions for fixing the token.

## Recommended Approach

**Use GitHub Actions for all deployments:**
1. Make your code changes
2. Commit and push to `main` branch
3. GitHub Actions automatically runs tests, builds image, and deploys
4. Monitor at: https://github.com/internetblacksmith/costar/actions

This ensures consistent, tested deployments across different environments.
