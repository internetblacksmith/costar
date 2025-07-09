#!/bin/bash

# Deployment script for ActorSync
# This script helps prepare and deploy to Render.com

set -e

echo "🚀 ActorSync Deployment Script"
echo "==============================="

# Check if we're in the right directory
if [ ! -f "app.rb" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check for required files
echo "📋 Checking required files..."
required_files=("Gemfile" "app.rb" "render.yaml" "Procfile")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Required file '$file' not found"
        exit 1
    fi
    echo "✅ Found: $file"
done

# Check Ruby version
echo "🔍 Checking Ruby version..."
ruby_version=$(ruby --version)
echo "Current Ruby version: $ruby_version"

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Check for environment variables
echo "🔧 Checking environment configuration..."
if command -v doppler &> /dev/null; then
    echo "✅ Doppler CLI found"
    if doppler secrets list &> /dev/null; then
        echo "✅ Doppler secrets configured"
    else
        echo "⚠️  Warning: Doppler not configured. Run 'doppler setup' or check .env file"
    fi
else
    echo "⚠️  Doppler CLI not found. Checking for .env file..."
    if [ ! -f ".env" ]; then
        echo "⚠️  Warning: No .env file found. Make sure to set TMDB_API_KEY in Render dashboard"
    else
        echo "✅ Found .env file"
    fi
fi

# Run basic tests
echo "🧪 Running basic health checks..."
echo "Testing app startup..."
timeout 10s bundle exec ruby -e "require_relative 'app.rb'; puts 'App loads successfully'" || {
    echo "❌ Error: App failed to load"
    exit 1
}

echo "✅ App loads successfully"

# Git status check
echo "📊 Checking git status..."
if git status --porcelain | grep -q .; then
    echo "⚠️  Warning: You have uncommitted changes"
    echo "Uncommitted files:"
    git status --porcelain
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled"
        exit 1
    fi
else
    echo "✅ Working directory clean"
fi

# Check current branch
current_branch=$(git branch --show-current)
echo "Current branch: $current_branch"

if [ "$current_branch" != "main" ]; then
    echo "⚠️  Warning: You're not on the main branch"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled"
        exit 1
    fi
fi

# Final deployment instructions
echo ""
echo "🎉 Pre-deployment checks complete!"
echo ""
echo "Next steps for Render.com deployment:"
echo "1. Push your code to GitHub:"
echo "   git add ."
echo "   git commit -m 'Deploy to Render.com'"
echo "   git push origin main"
echo ""
echo "2. In Render dashboard:"
echo "   - Create new Web Service"
echo "   - Connect your GitHub repository"
echo "   - Use settings from render.yaml"
echo "   - Add environment variables:"
echo "     * TMDB_API_KEY (required)"
echo "     * RACK_ENV=production (required)"
echo "     * POSTHOG_API_KEY (optional)"
echo "     * DOPPLER_TOKEN (optional, if using Doppler)"
echo ""
echo "3. Deploy and monitor the build logs"
echo ""
echo "For detailed instructions, see DEPLOYMENT.md"
echo ""
echo "🚀 Ready for deployment!"