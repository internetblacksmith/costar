#!/bin/bash
# frozen_string_literal: true

# Kamal Deployment Script for CoStar
# Secrets are fetched by .kamal/secrets via Kamal's Doppler adapter
# Usage: ./scripts/deploy.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Kamal deployment${NC}"

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
echo
echo -e "${BLUE}🔐 Secrets Management: https://dashboard.doppler.com${NC}"
