#!/bin/bash

# Run all test suites and generate a summary report

echo "🧪 MovieTogether Comprehensive Test Suite"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0

# Function to run a test suite
run_test_suite() {
    local suite_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running ${suite_name}...${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ ${suite_name} passed${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ ${suite_name} failed${NC}"
        ((FAILED++))
    fi
    echo ""
}

# 1. Unit Tests
run_test_suite "Unit Tests" "bundle exec rspec spec/lib --format progress"

# 2. Integration Tests
run_test_suite "Integration Tests" "bundle exec rspec spec/requests --format progress"

# 3. End-to-End Tests
run_test_suite "E2E Tests (Cucumber)" "bundle exec cucumber --format progress"

# 4. Accessibility Tests
run_test_suite "Accessibility Tests" "ACCESSIBILITY_TESTS=true bundle exec rspec spec/accessibility --format progress"

# 5. Performance Tests
run_test_suite "Performance Tests" "bundle exec rspec spec/performance --format progress"

# 6. Security Tests
run_test_suite "Security Tests" "bundle exec rspec spec/security --format progress"

# 7. Code Style
run_test_suite "Code Style (RuboCop)" "bundle exec rubocop"

# 8. Security Scan
run_test_suite "Security Scan (Brakeman)" "bundle exec brakeman -q"

# 9. Dependency Audit
run_test_suite "Dependency Audit" "bundle exec bundle-audit check --update"

# Summary
echo "========================================"
echo "Test Summary:"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
echo -e "  ${RED}Failed: ${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the output above.${NC}"
    exit 1
fi