# Gem Version Management

## Current Strategy

All gems in this project are **pinned to exact versions** for:
- 🛡️ **Production Stability**: No surprise updates that could break functionality
- 🔄 **Reproducible Builds**: Same versions across all environments
- 🐛 **Easier Debugging**: Known versions when investigating issues
- 📦 **Dependency Clarity**: Explicit about what versions we're using

## Gem Version Status

Last updated: **2025-07-13**

All gems are pinned to their current latest stable versions:

### Core Dependencies
- `activesupport`: 7.1.5.1 (web framework support)
- `sinatra`: 4.1.1 (web framework)
- `puma`: 6.6.0 (web server)
- `redis`: 5.4.0 (caching)
- `sentry-ruby`: 5.26.0 (error tracking)

### Development Tools
- `rubocop`: 1.78.0 (code style)
- `brakeman`: 6.2.2 (security scanning)
- `filewatcher`: 2.1.0 (file watching, replaces rerun)

### Testing Framework
- `rspec`: 3.13.1 (testing framework)
- `vcr`: 6.3.1 (HTTP recording)
- `webmock`: 3.25.1 (HTTP stubbing)

## Management Commands

### Check for Updates
```bash
# Check which gems have newer versions available
make check-outdated
```

### Update Strategy

#### Option 1: Individual Gem Updates (Recommended)
```bash
# Update a specific gem
bundle update <gem-name>

# Then update the version in Gemfile manually
# Example: gem "activesupport", "8.0.2"
```

#### Option 2: Full Update (Use with Caution)
```bash
# Updates all gems and requires manual Gemfile updates
make update-gems
```

### Testing After Updates
```bash
# Always test after gem updates
make test
make lint
make security

# Test the development environment
make dev
```

## Update Process

1. **Check for Outdated Gems**:
   ```bash
   make check-outdated
   ```

2. **Update Individually** (safest approach):
   ```bash
   # Example: updating brakeman
   bundle update brakeman
   # Edit Gemfile: gem "brakeman", "7.0.2"
   bundle install
   ```

3. **Test Thoroughly**:
   ```bash
   make test        # Run test suite
   make lint        # Check code style
   make security    # Security scan
   make dev         # Test development server
   ```

4. **Commit Changes**:
   ```bash
   git add Gemfile Gemfile.lock
   git commit -m "Update brakeman to 7.0.2"
   ```

## Benefits of Pinned Versions

### ✅ Advantages
- **Predictable Deployments**: Same versions in all environments
- **No Surprise Breakages**: Updates are intentional and tested
- **Easier Rollbacks**: Clear version history in git
- **Security Auditing**: Know exactly which versions are in use
- **Faster CI/CD**: No time spent resolving dependencies

### ⚠️ Considerations
- **Manual Update Process**: Requires intentional updates
- **Security Updates**: Must actively monitor for security patches
- **Dependency Drift**: Can fall behind if not regularly updated

## Security Monitoring

The project includes automated security scanning:
```bash
make security  # Runs brakeman + bundle-audit
```

For security updates:
1. Monitor `bundle-audit` warnings
2. Check gem changelogs for security fixes
3. Prioritize security updates over feature updates
4. Test security updates in staging first

## Version Update Schedule

**Recommended Schedule:**
- **Security Updates**: Immediately when available
- **Minor Updates**: Monthly review and selective updates
- **Major Updates**: Quarterly, with thorough testing
- **Development Tools**: As needed for new features

**Process:**
1. Weekly: `make check-outdated` to monitor available updates
2. Monthly: Review and update non-critical gems
3. Quarterly: Plan major version updates

## Emergency Updates

For critical security vulnerabilities:
1. Check advisory: `bundle audit`
2. Update immediately: `bundle update <vulnerable-gem>`
3. Update Gemfile version
4. Fast-track testing and deployment
5. Monitor application health post-deployment

---

This strategy balances **stability** with **security** while maintaining **clear dependency management**.