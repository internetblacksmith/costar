#!/bin/bash
# GitHub Actions Workflow Runs Cleanup Script
# Deletes failed and cancelled workflow runs from the repository

set -e  # Exit on error (disabled during deletion loop)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONE_PASSWORD_TOKEN_PATH="op://Personal/github/token"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Workflow Runs Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required commands
if ! command_exists gh; then
    echo -e "${RED}Error: gh CLI is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! command_exists op; then
    echo -e "${RED}Error: 1Password CLI is not installed${NC}"
    echo "Install it from: https://developer.1password.com/docs/cli"
    exit 1
fi

# Unset GITHUB_TOKEN if it exists (to allow gh auth login)
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Unsetting existing GITHUB_TOKEN environment variable${NC}"
    unset GITHUB_TOKEN
fi

# Check 1Password authentication
echo -e "${BLUE}Checking 1Password authentication...${NC}"
if ! op whoami >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Not signed in to 1Password. Signing in...${NC}"
    if ! op signin; then
        echo -e "${RED}Error: Failed to sign in to 1Password${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ 1Password authenticated${NC}"
echo ""

# Authenticate gh CLI
echo -e "${BLUE}Authenticating GitHub CLI...${NC}"
if ! op read "$ONE_PASSWORD_TOKEN_PATH" | gh auth login --with-token 2>/dev/null; then
    echo -e "${RED}Error: Failed to authenticate gh CLI${NC}"
    echo "The token at $ONE_PASSWORD_TOKEN_PATH may be invalid or expired."
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "1. Generate a new token: https://github.com/settings/tokens?type=beta"
    echo "2. Required permissions: Actions (read/write), Metadata (read)"
    echo "3. Save to 1Password or run: echo 'TOKEN' | gh auth login --with-token"
    exit 1
fi
echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"
echo ""

# Verify authentication
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI authentication failed${NC}"
    exit 1
fi

# Change to repository directory
cd "$REPO_PATH"

# Show current workflow runs summary
echo -e "${BLUE}Current Workflow Runs Summary:${NC}"
echo ""

total_runs=$(gh run list --limit 1000 --json databaseId --jq '. | length')
failed_runs=$(gh run list --status failure --limit 1000 --json databaseId --jq '. | length')
cancelled_runs=$(gh run list --status cancelled --limit 1000 --json databaseId --jq '. | length')
success_runs=$(gh run list --status success --limit 1000 --json databaseId --jq '. | length')

echo -e "  Total runs:     ${BLUE}$total_runs${NC}"
echo -e "  Successful:     ${GREEN}$success_runs${NC}"
echo -e "  Failed:         ${RED}$failed_runs${NC}"
echo -e "  Cancelled:      ${YELLOW}$cancelled_runs${NC}"
echo ""

# Check if there are runs to delete
if [ "$failed_runs" -eq 0 ] && [ "$cancelled_runs" -eq 0 ]; then
    echo -e "${GREEN}✅ No failed or cancelled runs to delete!${NC}"
    exit 0
fi

# Ask for confirmation
echo -e "${YELLOW}This will delete:${NC}"
echo -e "  - ${RED}$failed_runs failed runs${NC}"
echo -e "  - ${YELLOW}$cancelled_runs cancelled runs${NC}"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled by user${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Deleting workflow runs...${NC}"
echo ""

# Temporarily disable exit-on-error for deletion loop
set +e

# Delete failed runs
if [ "$failed_runs" -gt 0 ]; then
    echo -e "${BLUE}Deleting $failed_runs failed runs...${NC}"
    deleted_count=0
    failed_count=0
    for run_id in $(gh run list --status failure --limit 1000 --json databaseId --jq '.[].databaseId'); do
        # gh run delete requires confirmation, so we use printf to send 'y\n'
        if printf 'y\n' | gh run delete "$run_id" >/dev/null 2>&1; then
            deleted_count=$((deleted_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        echo -ne "\r  Progress: $((deleted_count + failed_count))/$failed_runs (deleted: $deleted_count, failed: $failed_count)"
    done
    echo ""
    if [ "$failed_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Successfully deleted $deleted_count failed runs, $failed_count failed to delete${NC}"
    else
        echo -e "${GREEN}✅ Deleted $deleted_count failed runs${NC}"
    fi
    echo ""
fi

# Delete cancelled runs
if [ "$cancelled_runs" -gt 0 ]; then
    echo -e "${BLUE}Deleting $cancelled_runs cancelled runs...${NC}"
    deleted_count=0
    failed_count=0
    for run_id in $(gh run list --status cancelled --limit 1000 --json databaseId --jq '.[].databaseId'); do
        # gh run delete requires confirmation, so we use printf to send 'y\n'
        if printf 'y\n' | gh run delete "$run_id" >/dev/null 2>&1; then
            deleted_count=$((deleted_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        echo -ne "\r  Progress: $((deleted_count + failed_count))/$cancelled_runs (deleted: $deleted_count, failed: $failed_count)"
    done
    echo ""
    if [ "$failed_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Successfully deleted $deleted_count cancelled runs, $failed_count failed to delete${NC}"
    else
        echo -e "${GREEN}✅ Deleted $deleted_count cancelled runs${NC}"
    fi
    echo ""
fi

# Re-enable exit-on-error
set -e

# Show final summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show remaining runs
remaining_runs=$(gh run list --limit 1000 --json databaseId --jq '. | length')
echo -e "Remaining workflow runs: ${BLUE}$remaining_runs${NC}"
echo ""

# Optional: Show last 5 runs
echo -e "${BLUE}Last 5 workflow runs:${NC}"
gh run list --limit 5
echo ""

echo -e "${GREEN}Done!${NC}"
