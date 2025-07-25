#!/bin/bash

# Script to help set up GitHub repository secrets
# Run this after creating the repository on GitHub

echo "GitHub Repository Secrets Setup"
echo "=============================="
echo ""
echo "This project uses VCR cassettes for API testing,"
echo "so no API keys are needed for CI/CD tests to run."
echo ""
echo "Optional Secrets (for deployment to production):"
echo "  - SENTRY_DSN: Your Sentry DSN for error tracking"
echo "  - RENDER_API_KEY: For automated deployment to Render"
echo ""
echo "Note: TMDB_API_KEY is only needed in production and"
echo "should be configured in your deployment platform"
echo "(e.g., Render.com with Doppler integration)."