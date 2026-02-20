#!/bin/bash

show_header() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎬 CoStar - Development & Deployment Menu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

show_menu() {
    echo "📦 Development Commands:"
    echo "  1)  Setup dev environment (Ruby dependencies)         [make setup-dev]"
    echo "  2)  Setup deployment environment (Kamal/Doppler)      [make setup-deploy]"
    echo "  3)  Run all tests (RSpec + Cucumber)                  [make test]"
    echo "  4)  Run RSpec tests only                               [make test-rspec]"
    echo "  5)  Run Cucumber tests only                            [make test-cucumber]"
    echo "  6)  Run tests with coverage report                     [make test-coverage]"
    echo "  7)  Run development server (auto-reload)              [make dev]"
    echo "  8)  Lint and format code (RuboCop)                    [make lint]"
    echo "  9)  Auto-fix code style issues                        [make fix]"
    echo "  10) Run security scans (Brakeman + bundler-audit)     [make security]"
    echo "  11) Run all pre-commit checks                         [make pre-commit]"
    echo "  12) Clean build artifacts                             [make clean]"
    echo "  13) Generate .kamal/secrets file                      [make kamal-secrets-setup]"
    echo ""
    echo "🐳 Docker Commands:"
    echo "  14) Build Docker image locally                        [make docker-build]"
    echo "  15) Run Docker container locally                      [make docker-run]"
    echo ""
    echo "⚙️  Background Services:"
    echo "  16) Start Redis server                                [make redis-start]"
    echo "  17) Stop Redis server                                 [make redis-stop]"
    echo ""
    echo "🚀 Deployment Commands (Kamal + Doppler):"
    echo "  18) 🔥 Deploy to production                           [make deploy]"
    echo "  19) Build and push image only                         [make deploy-build]"
    echo "  20) Stream production logs                            [make deploy-logs]"
    echo "  21) Restart production containers                     [make deploy-restart]"
    echo "  22) Rollback to previous version                      [make deploy-rollback]"
    echo "  23) Stop production containers                        [make deploy-stop]"
    echo "  24) Open shell in production container                [make deploy-shell]"
    echo "  25) Show deployment status                            [make deploy-status]"
    echo "  26) Show production environment variables             [make deploy-env]"
    echo "  27) Setup Kamal on new server                         [make deploy-setup]"
    echo ""
    echo "  0)  Exit"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

execute_command() {
    case $1 in
        1)
            echo "▶️  Setting up development environment..."
            make setup-dev
            ;;
        2)
            echo "▶️  Setting up deployment environment..."
            make setup-deploy
            ;;
        3)
            echo "▶️  Running all tests..."
            make test
            ;;
        4)
            echo "▶️  Running RSpec tests..."
            make test-rspec
            ;;
        5)
            echo "▶️  Running Cucumber tests..."
            make test-cucumber
            ;;
        6)
            echo "▶️  Running tests with coverage..."
            make test-coverage
            ;;
        7)
            echo "▶️  Starting development server..."
            make dev
            ;;
        8)
            echo "▶️  Linting code..."
            make lint
            ;;
        9)
            echo "▶️  Auto-fixing code style issues..."
            make fix
            ;;
        10)
            echo "▶️  Running security scans..."
            make security
            ;;
        11)
            echo "▶️  Running all pre-commit checks..."
            make pre-commit
            ;;
        12)
            echo "▶️  Cleaning build artifacts..."
            make clean
            ;;
        13)
            echo "▶️  Generating .kamal/secrets file..."
            make kamal-secrets-setup
            ;;
        14)
            echo "▶️  Building Docker image..."
            make docker-build
            ;;
        15)
            echo "▶️  Running Docker container..."
            make docker-run
            ;;
        16)
            echo "▶️  Starting Redis server..."
            make redis-start
            ;;
        17)
            echo "▶️  Stopping Redis server..."
            make redis-stop
            ;;
        18)
            echo "🔥 Deploying to production..."
            echo ""
            read -p "⚠️  Are you sure you want to deploy to production? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                make deploy
            else
                echo "❌ Deployment cancelled."
            fi
            ;;
        19)
            echo "▶️  Building and pushing image..."
            make deploy-build
            ;;
        20)
            echo "▶️  Streaming production logs (Ctrl+C to exit)..."
            make deploy-logs
            ;;
        21)
            echo "▶️  Restarting production containers..."
            make deploy-restart
            ;;
        22)
            echo "▶️  Rolling back to previous version..."
            read -p "⚠️  Are you sure you want to rollback? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                make deploy-rollback
            else
                echo "❌ Rollback cancelled."
            fi
            ;;
        23)
            echo "▶️  Stopping production containers..."
            read -p "⚠️  Are you sure you want to stop production? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                make deploy-stop
            else
                echo "❌ Stop cancelled."
            fi
            ;;
        24)
            echo "▶️  Opening shell in production container..."
            make deploy-shell
            ;;
        25)
            echo "▶️  Showing deployment status..."
            make deploy-status
            ;;
        26)
            echo "▶️  Showing production environment variables..."
            make deploy-env
            ;;
        27)
            echo "▶️  Setting up Kamal on new server..."
            read -p "⚠️  Are you sure you want to setup a new server? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                make deploy-setup
            else
                echo "❌ Setup cancelled."
            fi
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please try again."
            ;;
    esac
}

main() {
    while true; do
        show_header
        show_menu
        read -p "Select an option (0-27): " choice
        echo ""
        execute_command "$choice"
        echo ""
        # Don't prompt for Enter if running interactive commands
        if [ "$choice" != "7" ] && [ "$choice" != "15" ] && [ "$choice" != "16" ] && [ "$choice" != "20" ] && [ "$choice" != "24" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

main
