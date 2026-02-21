#!/bin/bash
# Helper script to display secrets for GitHub Actions configuration
# Run this and copy each value to GitHub repository settings

set -e

PROJECT="costar"
CONFIG="prd"

echo "========================================"
echo "GitHub Secrets Configuration Helper"
echo "========================================"
echo ""
echo "Navigate to: https://github.com/internetblacksmith/costar/settings/secrets/actions"
echo "Click 'New repository secret' for each of these:"
echo ""
echo "----------------------------------------"

secrets=(
  "KAMAL_REGISTRY_PASSWORD"
  "DEPLOY_SSH_PRIVATE_KEY"
  "TMDB_API_KEY"
  "SENTRY_DSN"
  "SESSION_SECRET"
  "POSTHOG_API_KEY"
  "SLACK_WEBHOOK_URL"
)

for secret in "${secrets[@]}"; do
  echo ""
  echo "📝 Secret: $secret"
  echo "   Value:"
  value=$(doppler secrets get "$secret" --project "$PROJECT" --config "$CONFIG" --plain 2>/dev/null || echo "NOT FOUND")
  if [ "$value" = "NOT FOUND" ]; then
    echo "   ❌ NOT FOUND IN DOPPLER"
  else
    echo "$value" | head -c 100
    length=${#value}
    if [ $length -gt 100 ]; then
      echo "... (truncated, full length: $length chars)"
    else
      echo " (length: $length chars)"
    fi
  fi
  echo ""
  echo "   Copy command (macOS):"
  echo "   doppler secrets get $secret --project $PROJECT --config $CONFIG --plain | pbcopy"
  echo ""
  echo "   Copy command (Linux):"
  echo "   doppler secrets get $secret --project $PROJECT --config $CONFIG --plain | xclip -selection clipboard"
  echo ""
  read -p "   Press Enter to continue to next secret..."
done

echo ""
echo "========================================"
echo "GitHub Variables Configuration"
echo "========================================"
echo ""
echo "Navigate to: https://github.com/internetblacksmith/costar/settings/variables/actions"
echo "Click 'New repository variable' for each:"
echo ""

echo "📝 Variable: REDIS_URL"
echo "   Value: redis://costar-redis:6380/0"
echo ""

echo "📝 Variable: SENTRY_ENVIRONMENT"
echo "   Value: production"
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next: Trigger deployment by pushing to main or manually at:"
echo "https://github.com/internetblacksmith/costar/actions"
