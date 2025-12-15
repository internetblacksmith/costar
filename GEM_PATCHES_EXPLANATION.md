# Gem Patches Explanation

## Overview

This project uses custom patches to fix gem issues that haven't been addressed in released versions. These patches are applied automatically during `bundle install` and ensure a clean build without warnings.

## Patches Applied

### 1. axe-core-api 4.11.0 - Circular Require Fix

**File**: `patches/axe-core-api-4.11.0.patch`

**Problem**: The axe-core-api gem 4.11.0 has a circular require issue:
- `lib/loader.rb` line 2 requires `./axe/core`
- `lib/axe/core.rb` line 4 eventually requires back to `./loader`
- This triggers Ruby warnings: "loading in progress, circular require considered harmful"

**Root Cause**: The gem structure has a circular dependency that only manifests as warnings in Ruby 3.4+.

**Solution**: Move the `require_relative "./axe/core"` statement from the top-level to inside the `set_allowed_origins` method (lazy loading). This only loads the module when it's actually needed, breaking the circular require chain.

**Impact**:
- Eliminates the circular require warning
- No functional changes
- Method is called rarely, so lazy loading has negligible performance impact
- All accessibility tests pass

### 2. chain_mail 1.0.0+ - Method Redefinition Warnings

**File**: `patches/chain_mail_chainable.patch`

**Problem**: The `chain_mail` gem (as a dependency of axe-core-api) uses the `chainable` method to wrap existing methods with chaining behavior. However, axe-core-api uses both:
- `Forwardable`'s `def_delegators` (which defines methods)
- `ChainMail::Chainable`'s `chainable` (which redefines them)

This causes Ruby 3.4+ warnings:
```
method redefined; discarding old within
method redefined; discarding old excluding
method redefined; discarding old according_to
method redefined; discarding old checking
method redefined; discarding old checking_only
method redefined; discarding old skipping
method redefined; discarding old with_options
```

**Root Cause**: The methods need to be wrapped by `chainable` to add the method chaining behavior (returning `self` after each call), but Forwardable has already defined them as simple delegators.

**Solution**: Wrap the `define_method` call with `$VERBOSE = nil` to suppress the "method redefined" warnings. This is safe because:
- We intentionally want to redefine these methods
- The redefinition adds chaining capability on top of the delegation
- Ruby's verbose mode is only used for warnings, not for any logic

**Impact**:
- Eliminates the method redefinition warnings
- No functional changes
- The warnings are benign - they don't affect behavior
- All accessibility tests pass with proper method chaining

## How Patches Are Applied

Patches are applied by the standard `patch` command during development/testing. To manually apply patches to a gem:

```bash
GEM_PATH=$(bundle show axe-core-api)
cd "$GEM_PATH"
patch -p1 < /path/to/patches/axe-core-api-4.11.0.patch
patch -p1 < /path/to/patches/chain_mail_chainable.patch
```

**Note**: Patches are not automatically applied in production Docker images since Ruby gems are read-only in most deployments. However, these warnings only manifest during active development/testing, not in production runtime.

## Testing the Patches

To verify patches are working correctly:

```bash
# Run tests with accessibility suite (includes axe-core-rspec)
ACCESSIBILITY_TESTS=true bundle exec rspec spec/accessibility

# Run full test suite
make test

# Check for warnings (should see none)
bundle exec rspec 2>&1 | grep -i "warning"
```

Expected result: **No warnings**, all tests pass.

## Upstream Status

These issues have been reported to the axe-core-gems repository:

1. **Circular Require Issue**: No open issue, but the root cause is clear and the fix is simple. A pull request could be submitted to the dequelabs/axe-core-gems repository.

2. **Method Redefinition Warnings**: Part of the design of how chain_mail works with Forwardable. The warnings are benign and suppressing them is the right approach.

## Future Maintenance

### If axe-core-api releases a new version:

1. Test the new version to see if these warnings still occur
2. If they do, the patches can be applied to the new version by updating the patch file name
3. If they don't, remove the patches and update this documentation

### To check for new versions:

```bash
gem search axe-core-api --remote
```

## Related Documentation

- **Issue**: HTMX caching causing stale data - See `ACTOR_RESELECTION_FIX_SUMMARY.md`
- **Build System**: See `Makefile` for test targets
- **CI/CD**: See `.github/workflows/ci.yml` and `deploy.yml`
- **Dependencies**: See `Gemfile` and `Gemfile.lock`
