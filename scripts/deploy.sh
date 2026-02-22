#!/bin/bash
# frozen_string_literal: true

# Kamal Deployment Script for CoStar
# Secrets are fetched by .kamal/secrets via Kamal's Doppler adapter
# Usage: ./scripts/deploy.sh [--staging]

set -e

# Ensure secrets file is cleaned up even if script fails
cleanup() {
  if [ -f .kamal/secrets ]; then
    rm -f .kamal/secrets
    echo -e "${BLUE}🔒 Cleaned up temporary secrets file${NC}"
  fi
}
trap cleanup EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
DOPPLER_CONFIG="prd"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --staging)
      ENVIRONMENT="staging"
      DOPPLER_CONFIG="stg"
      shift
      ;;
    --help)
      echo "Usage: $0 [--staging]"
      echo "  --staging     Deploy to staging environment"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🚀 Starting Kamal deployment for ${ENVIRONMENT} environment${NC}"

# Check if kamal is installed (should be in Gemfile dev group)
if ! bundle exec kamal version &> /dev/null; then
    echo -e "${RED}❌ Kamal is not installed. Run: bundle install${NC}"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "config/deploy.yml" ]]; then
    echo -e "${RED}❌ config/deploy.yml not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Check if Doppler is installed and configured
echo -e "${BLUE}🔐 Checking Doppler configuration...${NC}"
if ! command -v doppler &> /dev/null; then
    echo -e "${RED}❌ Doppler CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://docs.doppler.com/docs/install-cli"
    echo "brew install dopplerhq/cli/doppler"
    exit 1
fi

if ! doppler configure get project &> /dev/null; then
    echo -e "${RED}❌ Doppler project not configured. Please run:${NC}"
    echo "  doppler login"
    echo "  doppler projects create costar"
    echo "  doppler setup"
    exit 1
fi

# Run tests before deployment
echo -e "${BLUE}🧪 Running tests...${NC}"
# Exclude visual regression, browser compatibility, and accessibility tests as they are flaky due to external CDN resources
if ! bundle exec rspec spec/ --exclude-pattern "spec/visual/**/*,spec/compatibility/**/*,spec/accessibility/**/*"; then
    echo -e "${RED}❌ Tests failed. Aborting deployment.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Tests passed!${NC}"

# Run linting
echo -e "${BLUE}🔍 Running linting...${NC}"
if ! bundle exec rubocop; then
    echo -e "${YELLOW}⚠️  Linting issues found. Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Deployment aborted due to linting issues.${NC}"
        exit 1
    fi
fi

# Run security checks
echo -e "${BLUE}🔒 Running security checks...${NC}"
if ! bundle exec brakeman --force; then
    echo -e "${YELLOW}⚠️  Security issues found. Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Deployment aborted due to security issues.${NC}"
        exit 1
    fi
fi

# Verify required secrets in Doppler
echo -e "${BLUE}🔐 Verifying Doppler secrets for ${DOPPLER_CONFIG} config...${NC}"
REQUIRED_SECRETS=("TMDB_API_KEY" "REDIS_URL" "KAMAL_REGISTRY_PASSWORD")

for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! doppler secrets get "$secret" --config "$DOPPLER_CONFIG" --plain &> /dev/null; then
        echo -e "${RED}❌ Missing required secret: $secret${NC}"
        echo "Please set it with: doppler secrets set $secret --config $DOPPLER_CONFIG"
        exit 1
    fi
done

# Check optional production secrets
if [ "$DOPPLER_CONFIG" = "prd" ]; then
    echo -e "${BLUE}🔐 Verifying optional production secrets...${NC}"
    OPTIONAL_SECRETS=("SENTRY_DSN" "SENTRY_ENVIRONMENT")
    for secret in "${OPTIONAL_SECRETS[@]}"; do
        if ! doppler secrets get "$secret" --config "$DOPPLER_CONFIG" --plain &> /dev/null; then
            echo -e "${YELLOW}⚠️  Optional secret not set: $secret${NC}"
        fi
    done
fi

echo -e "${GREEN}✅ All required secrets present!${NC}"

# Validate GitHub token (KAMAL_REGISTRY_PASSWORD)
echo -e "${BLUE}🔐 Validating GitHub Container Registry token...${NC}"
REGISTRY_PASSWORD=$(doppler secrets get KAMAL_REGISTRY_PASSWORD --config "$DOPPLER_CONFIG" --plain)

# Test docker login with the token
if ! echo "$REGISTRY_PASSWORD" | docker login ghcr.io -u jabawack81 --password-stdin &> /dev/null; then
    echo -e "${RED}❌ GitHub Container Registry token validation failed!${NC}"
    echo "   The token in Doppler (KAMAL_REGISTRY_PASSWORD) is invalid or expired."
    echo "   Please verify the token at: https://github.com/settings/tokens"
    echo ""
    echo "   Token requirements:"
    echo "   - Scope: write:packages (for pushing to container registry)"
    echo "   - Scope: read:packages (for pulling from container registry)"
    echo "   - Not expired"
    echo ""
    echo "   To update the token:"
    echo "   1. Create/regenerate at: https://github.com/settings/tokens"
    echo "   2. Update Doppler: doppler secrets set KAMAL_REGISTRY_PASSWORD --config $DOPPLER_CONFIG"
    exit 1
fi

echo -e "${GREEN}✅ GitHub Container Registry token is valid!${NC}"

# Deploy the application with Kamal (secrets fetched via Doppler adapter in .kamal/secrets)
echo -e "${BLUE}🚀 Deploying with Kamal...${NC}"
bundle exec kamal deploy

# Check deployment status
echo -e "${BLUE}📊 Checking deployment status...${NC}"
bundle exec kamal app details

echo
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo
echo -e "${YELLOW}💡 Useful Kamal commands:${NC}"
echo "  kamal app logs       - View live logs"
echo "  kamal app details    - Check app status"
echo "  kamal app exec       - Run commands in container"
echo "  kamal rollback       - Rollback to previous version"

# Show monitoring links if configured
if doppler secrets get SENTRY_DSN --config "$DOPPLER_CONFIG" --plain &> /dev/null; then
    echo
    echo -e "${GREEN}🐛 Error Monitoring: https://sentry.io${NC}"
fi

echo
echo -e "${BLUE}🔐 Secrets Management: https://dashboard.doppler.com${NC}"
