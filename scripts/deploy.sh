#!/bin/bash
# frozen_string_literal: true

# Kamal Deployment Script for movie_together
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

# Check if kamal is installed
if ! command -v kamal &> /dev/null; then
    echo -e "${RED}❌ Kamal is not installed. Please install it first.${NC}"
    echo "gem install kamal"
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
    echo "  doppler projects create movie_together"
    echo "  doppler setup"
    exit 1
fi

# Run tests before deployment
echo -e "${BLUE}🧪 Running tests...${NC}"
if ! bundle exec rspec; then
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

# Generate .kamal/secrets file from Doppler (never commit this file!)
echo -e "${BLUE}🔐 Generating secrets from Doppler...${NC}"
mkdir -p .kamal
doppler secrets download --no-file --format env --config "$DOPPLER_CONFIG" > .kamal/secrets

# Deploy the application with Kamal
echo -e "${BLUE}🚀 Deploying with Kamal...${NC}"
kamal deploy

# Note: cleanup happens automatically via trap on EXIT

# Check deployment status
echo -e "${BLUE}📊 Checking deployment status...${NC}"
kamal app details

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
