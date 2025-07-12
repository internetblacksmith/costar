#!/bin/bash
# Local CI/CD Simulation Script
# Runs the same checks that GitHub Actions will run

set -e  # Exit on any error

echo "🚀 Running Local CI/CD Simulation..."
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 passed${NC}"
    else
        echo -e "${RED}❌ $1 failed${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}📦 Installing dependencies...${NC}"
bundle install
print_status "Bundle install"

echo -e "${YELLOW}🧪 Running tests...${NC}"
bundle exec rspec
print_status "RSpec tests"

echo -e "${YELLOW}🔍 Running code quality checks...${NC}"
bundle exec rubocop
print_status "RuboCop"

echo -e "${YELLOW}🛡️  Running security audit...${NC}"
# Install security tools if not present
if ! gem list bundle-audit -i > /dev/null 2>&1; then
    gem install bundle-audit
fi

if ! gem list brakeman -i > /dev/null 2>&1; then
    gem install brakeman
fi

bundle audit --update
print_status "Bundle audit"

brakeman --no-pager --quiet
print_status "Brakeman security scan"

echo -e "${YELLOW}🏥 Testing health endpoint...${NC}"
# Start the app in background for health check
bundle exec ruby app.rb &
APP_PID=$!

# Wait for app to start
sleep 3

# Test health endpoint
curl -f http://localhost:4567/health/simple > /dev/null 2>&1
HEALTH_STATUS=$?

# Kill the app
kill $APP_PID 2>/dev/null || true

if [ $HEALTH_STATUS -eq 0 ]; then
    print_status "Health check"
else
    echo -e "${RED}❌ Health check failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All checks passed! Ready for CI/CD pipeline.${NC}"
echo ""
echo "Next steps:"
echo "1. Commit your changes: git add . && git commit -m 'Your message'"
echo "2. Push to GitHub: git push origin your-branch"
echo "3. Create pull request to trigger CI/CD pipeline"
echo ""
echo "Pipeline will run:"
echo "- ✅ Tests (RSpec)"
echo "- ✅ Security scan (bundle-audit, brakeman)"
echo "- ✅ Code quality (RuboCop)"
echo "- ✅ Deployment (if merging to main/develop)"