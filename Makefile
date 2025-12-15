.PHONY: menu help setup setup-dev setup-deploy test test-coverage test-rspec test-cucumber lint fix clean docker-build docker-run
.PHONY: deploy deploy-build deploy-logs deploy-restart deploy-rollback deploy-stop deploy-shell deploy-status deploy-env deploy-setup
.PHONY: redis-start redis-stop kamal-secrets-setup pre-commit security

.DEFAULT_GOAL := menu

menu:
	@bash scripts/menu.sh

help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  MovieTogether - Makefile Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📦 Development Commands:"
	@echo "  make setup-dev           - Setup dev environment (Ruby dependencies)"
	@echo "  make setup-deploy        - Setup deployment environment (Kamal/Doppler)"
	@echo "  make test                - Run all tests (RSpec + Cucumber, no warnings)"
	@echo "  make test-rspec          - Run RSpec tests only (no warnings)"
	@echo "  make test-cucumber       - Run Cucumber tests only (no warnings)"
	@echo "  make test-coverage       - Run tests with coverage report (no warnings)"
	@echo "  make test-accessibility  - Run accessibility tests (optional, with expected warnings)"
	@echo "  make dev                 - Run development server (auto-reload)"
	@echo "  make lint                - Check code style (RuboCop)"
	@echo "  make fix                 - Auto-fix code style issues"
	@echo "  make security            - Run security scans (Brakeman + bundler-audit)"
	@echo "  make pre-commit          - Run all checks before committing"
	@echo "  make clean               - Clean build artifacts"
	@echo "  make kamal-secrets-setup - Generate .kamal/secrets file for development"
	@echo ""
	@echo "🐳 Docker Commands:"
	@echo "  make docker-build    - Build Docker image locally"
	@echo "  make docker-run      - Run Docker container locally"
	@echo ""
	@echo "⚙️  Background Services:"
	@echo "  make redis-start - Start Redis server"
	@echo "  make redis-stop  - Stop Redis server"
	@echo ""
	@echo "🚀 Deployment Commands (Kamal + Doppler):"
	@echo "  make deploy          - Deploy to production"
	@echo "  make deploy-build    - Build and push image only"
	@echo "  make deploy-logs     - Stream production logs"
	@echo "  make deploy-restart  - Restart production containers"
	@echo "  make deploy-rollback - Rollback to previous version"
	@echo "  make deploy-stop     - Stop production containers"
	@echo "  make deploy-shell    - Open shell in production container"
	@echo "  make deploy-status   - Show deployment status"
	@echo "  make deploy-env      - Show production environment variables"
	@echo "  make deploy-setup    - Setup Kamal on new server"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Setup development environment (Ruby dependencies only)
setup-dev:
	@echo "🚀 Setting up development environment..."
	@echo ""
	@echo "📋 Checking Ruby installation..."
	@if ! command -v ruby > /dev/null; then \
		echo "❌ Ruby not found. Please install Ruby first."; \
		echo "   On macOS: brew install ruby"; \
		echo "   On Ubuntu: sudo apt install ruby-full"; \
		exit 1; \
	fi
	@echo "✅ Ruby $$(ruby --version | awk '{print $$2}') found"
	@echo ""
	@echo "💎 Installing Bundler and dependencies..."
	@if ! command -v bundle > /dev/null; then \
		echo "Installing bundler..."; \
		gem install bundler; \
	fi
	bundle install
	@echo ""
	@echo "🪝 Installing git pre-commit hook..."
	@if [ -f .git-hooks/pre-commit ]; then \
		mkdir -p .git/hooks 2>/dev/null || mkdir -p ../.git/modules/movie_together/hooks; \
		if [ -d .git/hooks ]; then \
			cp .git-hooks/pre-commit .git/hooks/pre-commit; \
			chmod +x .git/hooks/pre-commit; \
		else \
			cp .git-hooks/pre-commit ../.git/modules/movie_together/hooks/pre-commit; \
			chmod +x ../.git/modules/movie_together/hooks/pre-commit; \
		fi; \
		echo "✅ Git pre-commit hook installed (runs lint + tests + security before commits)"; \
	else \
		echo "⚠️  Pre-commit hook script not found at .git-hooks/pre-commit"; \
	fi
	@echo ""
	@echo "🧪 Running tests to verify setup..."
	@$(MAKE) test
	@echo ""
	@echo "✅ Development environment setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Setup Doppler with dev config:"
	@echo "     doppler setup --project movie_together --config dev"
	@echo "  2. Copy .doppler.example to .doppler:"
	@echo "     cp .doppler.example .doppler"
	@echo "  3. Configure dev secrets in Doppler:"
	@echo "     doppler secrets set --project movie_together --config dev"
	@echo "  4. Run 'make redis-start' to start Redis (in separate terminal)"
	@echo "  5. Run 'make dev' to start the local development server"
	@echo "  6. Run 'make setup-deploy' to configure production deployment (separate step)"
	@echo ""
	@echo "ℹ️  Git pre-commit hook is now active - it will run 'make pre-commit' before each commit"
	@echo "ℹ️  Never set up prd config on dev machines - deployment uses explicit --config prd"

# Setup deployment environment (Kamal, Doppler)
setup-deploy:
	@echo "🚀 Setting up deployment environment..."
	@echo ""
	@echo "📋 Checking prerequisites..."
	@if ! command -v ruby > /dev/null; then \
		echo "❌ Ruby not found. Please install Ruby first."; \
		echo "   On macOS: brew install ruby"; \
		echo "   On Ubuntu: sudo apt install ruby-full"; \
		exit 1; \
	fi
	@echo "✅ Ruby $$(ruby --version | awk '{print $$2}') found"
	@if ! command -v docker > /dev/null; then \
		echo "❌ Docker not found. Please install Docker first."; \
		echo "   Visit: https://docs.docker.com/get-docker/"; \
		exit 1; \
	fi
	@echo "✅ Docker $$(docker --version | awk '{print $$3}' | tr -d ',') found"
	@if ! command -v doppler > /dev/null; then \
		echo "❌ Doppler CLI not found. Please install Doppler first."; \
		echo "   On macOS: brew install dopplerhq/cli/doppler"; \
		echo "   On Linux: curl -sLf https://cli.doppler.com/install.sh | sh"; \
		exit 1; \
	fi
	@echo "✅ Doppler CLI found"
	@echo ""
	@echo "💎 Installing deployment gems (Kamal)..."
	@if ! command -v bundle > /dev/null; then \
		echo "Installing bundler..."; \
		gem install bundler; \
	fi
	bundle install
	@echo "✅ Kamal $$(bundle exec kamal version 2>/dev/null || echo 'installed')"
	@echo ""
	@echo "🔐 Checking Doppler configuration..."
	@if ! doppler configure get project --plain 2>/dev/null | grep -q "movie_together"; then \
		echo "⚠️  Doppler not configured for deployment. You'll need to set up:"; \
		echo "   doppler setup --project movie_together --config prd"; \
	else \
		echo "✅ Doppler project: movie_together"; \
	fi
	@echo ""
	@echo "🔧 Generating .kamal/secrets file..."
	@$(MAKE) kamal-secrets-setup
	@echo ""
	@echo "✅ Deployment environment setup complete!"
	@echo ""
	@echo "Next steps (for authorized ops/CI-CD personnel ONLY):"
	@echo "  1. Setup production Doppler config:"
	@echo "     doppler setup --project movie_together --config prd"
	@echo "  2. Set production secrets in Doppler prd config:"
	@echo "     doppler secrets set --project movie_together --config prd"
	@echo "  3. Test VPS connection:"
	@echo "     ssh digitalocean-deploy"
	@echo "  4. Test deployment:"
	@echo "     make deploy-setup  # Setup Kamal (first time only)"
	@echo "  5. Deploy:"
	@echo "     make deploy"
	@echo ""
	@echo "ℹ️  IMPORTANT: Never set up prd config on developer machines"
	@echo "ℹ️  Dev machines: Use dev config from .doppler file"
	@echo "ℹ️  Deployment: Explicitly specifies prd config (--config prd)"

# Full setup (both dev and deploy)
setup: setup-dev setup-deploy

# Run all tests
test: test-rspec test-cucumber
	@echo "✅ All tests completed successfully!"

# Run RSpec tests only
test-rspec:
	@echo "🧪 Running RSpec test suite..."
	@echo "✅ Tests use mock environment - no secrets needed"
	@echo "📦 Excluding optional accessibility tests to prevent gem warnings..."
	bundle exec rspec --format progress spec/lib spec/requests spec/contracts spec/integration spec/performance spec/security spec/javascript spec/views spec/visual spec/compatibility spec/stress

# Run Cucumber tests only
test-cucumber:
	@echo "🥒 Running Cucumber BDD tests..."
	@echo "✅ Testing with mocked API responses"
	BUNDLE_WITHOUT="accessibility" bundle exec cucumber

# Run tests with coverage
test-coverage:
	@echo "🧪 Running tests with coverage..."
	bundle exec rspec --format progress spec/lib spec/requests spec/contracts spec/integration spec/performance spec/security spec/javascript spec/views spec/visual spec/compatibility spec/stress
	@echo "Coverage report generated"

# Run accessibility tests (includes optional accessibility gems)
test-accessibility:
	@echo "🔍 Running accessibility tests..."
	@echo "⚠️  Note: axe-core-rspec has benign circular require warnings (expected)"
	ACCESSIBILITY_TESTS=true bundle exec rspec spec/accessibility --format documentation
	@echo "✅ Accessibility tests completed"

# Run development server
dev:
	@echo "💻 Starting development server with auto-reload..."
	@echo "🌐 Server will be available at: http://localhost:4567"
	@echo "🔄 Auto-reloads on file changes (*.rb, *.erb)"
	@echo "Press Ctrl+C to stop the server"
	@echo ""
	@if command -v doppler > /dev/null; then \
		echo "🔐 Using Doppler dev config for secrets..."; \
		doppler run --config dev -- bundle exec rerun --pattern="**/*.{rb,erb}" -- ruby app.rb; \
	else \
		echo "⚠️  Doppler not found. Running without Doppler..."; \
		bundle exec rerun --pattern="**/*.{rb,erb}" -- ruby app.rb; \
	fi

# Lint code
lint:
	@echo "🔍 Checking code style..."
	bundle exec rubocop

# Auto-fix code style issues
fix:
	@echo "🔧 Auto-fixing code style issues..."
	bundle exec rubocop -a

# Run security scans
security:
	@echo "🔒 Running security scans..."
	bundle exec brakeman --force
	bundle exec bundle-audit check --update

# Run all pre-commit checks
pre-commit: lint test security
	@echo "✅ All checks passed!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning up temporary files..."
	rm -rf tmp/
	rm -rf coverage/
	rm -rf .bundle/vendor/
	rm -f .env
	@echo "✅ Cleanup complete!"

# Build Docker image
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t movie_together .

# Run Docker container
docker-run:
	@echo "🐳 Running Docker container..."
	docker run -it -p 4567:4567 --env-file .env movie_together

# Start Redis server
redis-start:
	@echo "🚀 Starting Redis server..."
	@if ! command -v docker > /dev/null 2>&1; then \
		echo "❌ Docker not found. Please install Docker first."; \
		exit 1; \
	fi
	@echo "📊 Redis logs will be shown below. Press Ctrl+C to stop."
	@echo ""
	docker compose up redis

# Stop Redis server
redis-stop:
	@echo "🛑 Stopping Redis server..."
	docker compose down
	@echo "✅ Redis stopped successfully!"

# Deploy to production using Doppler for secrets
deploy: pre-commit
	@echo ""
	@echo "✅ All pre-deployment checks passed!"
	@echo ""
	@echo "🚀 Deploying to production with Doppler secrets..."
	@echo "🔐 Using Doppler prd environment..."
	@if [ -f "./scripts/deploy.sh" ]; then \
		chmod +x ./scripts/deploy.sh && ./scripts/deploy.sh; \
	else \
		doppler run --project movie_together --config prd --command='bash -c "export KAMAL_REGISTRY_PASSWORD && kamal deploy"'; \
	fi

# Build and push Docker image only
deploy-build:
	@echo "🔨 Building and pushing Docker image..."
	doppler run --project movie_together --config prd -- kamal build push

# Stream production logs
deploy-logs:
	doppler run --project movie_together --config prd -- kamal app logs -f

# Restart production containers
deploy-restart:
	doppler run --project movie_together --config prd -- kamal app boot

# Rollback to previous version
deploy-rollback:
	doppler run --project movie_together --config prd -- kamal rollback

# Stop production containers
deploy-stop:
	doppler run --project movie_together --config prd -- kamal app stop

# Open shell in production container
deploy-shell:
	doppler run --project movie_together --config prd -- kamal app exec -i bash

# Show deployment status
deploy-status:
	doppler run --project movie_together --config prd -- kamal details

# Show production environment variables
deploy-env:
	doppler run --project movie_together --config prd -- kamal app exec env | grep -v PASSWORD | grep -v TOKEN | sort

# Setup Kamal on new server
deploy-setup:
	doppler run --project movie_together --config prd -- kamal setup

# Generate .kamal/secrets file for development
kamal-secrets-setup:
	@echo "📝 Generating .kamal/secrets file..."
	@mkdir -p .kamal
	@echo "# Kamal secrets file - uses variable substitution with Doppler" > .kamal/secrets
	@echo "# This file is required by Kamal even when using environment variables" >> .kamal/secrets
	@echo "# Doppler injects the actual values during deployment (not at runtime)" >> .kamal/secrets
	@echo "" >> .kamal/secrets
	@echo "# Deployment secrets (used only during deployment)" >> .kamal/secrets
	@echo "KAMAL_REGISTRY_PASSWORD=\$$KAMAL_REGISTRY_PASSWORD" >> .kamal/secrets
	@echo "" >> .kamal/secrets
	@echo "# Runtime environment variables (passed to container)" >> .kamal/secrets
	@echo "TMDB_API_KEY=\$$TMDB_API_KEY" >> .kamal/secrets
	@echo "REDIS_URL=\$$REDIS_URL" >> .kamal/secrets
	@echo "SENTRY_DSN=\$$SENTRY_DSN" >> .kamal/secrets
	@echo "SENTRY_ENVIRONMENT=\$$SENTRY_ENVIRONMENT" >> .kamal/secrets
	@echo "RACK_ENV=production" >> .kamal/secrets
	@echo "" >> .kamal/secrets
	@echo "✅ .kamal/secrets file created successfully"
	@echo ""
	@echo "⚠️  This file uses variable substitution (\$$VAR_NAME) so Doppler can inject the actual secrets."
	@echo "   Make sure you have all required secrets configured in Doppler prd config."
