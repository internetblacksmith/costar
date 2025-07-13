# ActorSync Development Makefile

.PHONY: dev install test lint security clean help

# Default target
dev: ## Start the development server with environment validation
	@./scripts/dev

install: ## Install dependencies
	@echo "📦 Installing dependencies..."
	@bundle install

update-gems: ## Update all gems to latest versions (use with caution)
	@echo "⚠️  Updating all gems to latest versions..."
	@echo "This will modify Gemfile with latest versions. Continue? [y/N]" && read ans && [ $${ans:-N} = y ]
	@bundle update
	@echo "📝 Remember to update version numbers in Gemfile and test thoroughly!"

check-outdated: ## Check for outdated gems
	@echo "🔍 Checking for outdated gems..."
	@bundle outdated

test: ## Run the test suite
	@echo "🧪 Running tests..."
	@bundle exec rspec

test-coverage: ## Run tests with coverage report
	@echo "🧪 Running tests with coverage..."
	@bundle exec rspec --format documentation

lint: ## Run code style checks
	@echo "🧹 Running code style checks..."
	@bundle exec rubocop -A

security: ## Run security scans
	@echo "🔒 Running security scans..."
	@bundle exec brakeman
	@bundle exec bundle-audit

clean: ## Clean temporary files
	@echo "🧹 Cleaning temporary files..."
	@rm -rf tmp/
	@rm -rf coverage/
	@find . -name "*.tmp" -delete

validate-env: ## Validate environment configuration
	@echo "🔍 Validating environment..."
	@ruby -e "require './lib/config/configuration'; Configuration.instance"

doppler-setup: ## Set up Doppler for local development
	@echo "🔐 Setting up Doppler..."
	@echo "1. Install Doppler CLI: brew install doppler"
	@echo "2. Login: doppler login"
	@echo "3. Setup project: doppler setup"
	@echo "4. Run: make dev"

help: ## Show this help message
	@echo "ActorSync Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  make dev          # Start development server"
	@echo "  make test         # Run tests"
	@echo "  make help         # Show this help"