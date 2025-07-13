# Development Server Script

The `dev` script provides a comprehensive development startup experience with environment validation and automatic configuration detection.

## Quick Start

```bash
# Start development server with full validation
./scripts/dev

# Or use the Makefile
make dev
```

## Features

### 🔍 Environment Detection & Validation
- **Doppler First**: Automatically detects and prefers Doppler configuration
- **Fallback to .env**: Uses .env file if Doppler isn't configured
- **Comprehensive Validation**: Checks all required environment variables
- **Fail Fast**: Stops immediately if critical configuration is missing

### 📦 Dependency Management
- **Automatic Installation**: Runs `bundle install` if needed
- **Dependency Verification**: Checks for required commands (ruby, bundle)
- **Optional Tools**: Detects and reports optional tools (doppler)

### 🚀 Smart Server Startup
- **Environment-Aware**: Uses `doppler run` if Doppler is configured
- **Modern File Watching**: Uses `filewatcher` for automatic restarts (no deprecation warnings)
- **Clear Feedback**: Shows which files are being watched and restart notifications

## Environment Configuration Priority

1. **Doppler** (Recommended for all environments)
   ```bash
   brew install doppler
   doppler login
   doppler setup
   ```

2. **.env File** (Development fallback)
   ```bash
   cp .env.example .env
   # Edit with your values
   ```

## Error Handling & Guidance

The script provides helpful guidance for common issues:

### Missing Dependencies
```
❌ Missing required commands: bundle
   Please install Ruby and Bundler before continuing
```

### No Environment Configuration
```
❌ No environment configuration found

Options:
1. Set up Doppler (recommended):
   brew install doppler
   doppler login
   doppler setup

2. Create .env file with required variables:
   cp .env.example .env
```

### Invalid Environment Variables
```
🚨 CRITICAL CONFIGURATION ERRORS:
   ❌ TMDB_API_KEY is missing or not properly configured

   The application may not work correctly!
   Please check your environment configuration.
```

## Integration with Existing Tools

The script works seamlessly with existing project tools:

- **Make**: `make dev` calls the script
- **Existing Validation**: Uses the project's Configuration class
- **Environment Scripts**: Compatible with existing validation scripts
- **CI/CD**: Can be used in automated environments

## Usage Examples

```bash
# Most common usage
./scripts/dev

# Alternative via Makefile
make dev

# Validate environment without starting server
make validate-env

# Other development tasks
make test        # Run tests
make lint        # Code style
make security    # Security scans
```

## Benefits Over Manual Startup

| Manual | Script |
|--------|--------|
| Remember to check environment | ✅ Automatic validation |
| Manual dependency installation | ✅ Automatic `bundle install` |
| Remember correct startup command | ✅ Environment-aware startup |
| Debug environment issues | ✅ Clear error messages & guidance |
| Switch between .env and Doppler | ✅ Automatic detection |

## Customization

The script is designed to be project-agnostic and can be easily modified for:
- Additional dependency checks
- Custom validation rules
- Different server startup commands
- Additional environment tools