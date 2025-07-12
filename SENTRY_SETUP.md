# Sentry Setup Guide for ActorSync

This guide walks you through setting up Sentry error tracking for your ActorSync application.

## 🎯 Why Sentry?

- **Free tier**: 5,000 errors/month (perfect for new apps)
- **Cost-effective scaling**: $26/month for 50k errors vs Bugsnag's $59/month for 25k
- **Better Ruby/Sinatra support** with excellent documentation
- **Performance monitoring included**
- **Open source** with self-hosting option

## 📋 Step-by-Step Setup

### 1. Create Sentry Account

1. Go to [sentry.io](https://sentry.io) and sign up for a free account
2. Create a new project:
   - Platform: **Ruby**
   - Framework: **Sinatra**
   - Project name: `actorsync` (or your preferred name)

### 2. Get Your DSN

After creating the project, Sentry will show you a **DSN** (Data Source Name) that looks like:
```
https://abc123def456@o123456.ingest.sentry.io/789012
```

**Copy this DSN** - you'll need it for the next step.

### 3. Add DSN to Doppler

Add the Sentry DSN to your Doppler secrets:

```bash
# Add to Doppler
doppler secrets set SENTRY_DSN="https://your-dsn-here@sentry.io/project-id"

# Optional: Set app version for release tracking
doppler secrets set APP_VERSION="1.0.0"

# Optional: Configure trace sampling (0.0 to 1.0)
doppler secrets set SENTRY_TRACES_SAMPLE_RATE="0.1"
```

### 4. Verify Integration

The Sentry integration is already implemented in your application with:

✅ **Error Tracking**: All exceptions automatically captured
✅ **Performance Monitoring**: Request tracing enabled  
✅ **Data Filtering**: Sensitive data (passwords, API keys) automatically filtered
✅ **Environment-Aware**: Only enabled in production/staging
✅ **Release Tracking**: Tracks app versions for better debugging

### 5. Deploy and Test

After adding the `SENTRY_DSN` to Doppler:

1. **Deploy to Render** - Doppler will sync the environment variable automatically
2. **Test error tracking**:
   - Visit: `https://movie-together.onrender.com/api/actors/search?q=nonexistent`
   - Check your Sentry dashboard for captured errors
3. **Monitor your dashboard** at [sentry.io](https://sentry.io)

## 🔧 Configuration Features

Your Sentry setup includes:

### Automatic Error Capture
- All unhandled exceptions
- API errors and validation errors
- Performance issues and slow queries

### Data Privacy
- API keys and passwords automatically filtered
- Request headers sanitized
- Sensitive data marked as `[FILTERED]`

### Environment Tagging
- Distinguishes between development/staging/production
- Tags all events with app name and component
- Tracks releases for better debugging

### Performance Monitoring
- 10% sample rate (configurable via `SENTRY_TRACES_SAMPLE_RATE`)
- Request duration tracking
- Database query monitoring (if added later)

## 📊 Monitoring Setup

### Dashboard Alerts
Set up alerts in Sentry for:
- **High error rate**: >10 errors in 10 minutes
- **New error types**: First occurrence of new exceptions
- **Performance issues**: Requests taking >5 seconds

### Release Tracking
When you deploy new versions:
```bash
# Update version in Doppler
doppler secrets set APP_VERSION="1.1.0"
```

Sentry will track which errors occur in which releases.

## 💰 Cost Management

### Free Tier Limits
- **5,000 errors/month** - plenty for most applications
- **1 user** - upgrade when you need team access
- **1 project** - sufficient for ActorSync

### When to Upgrade
Consider upgrading to **Team plan ($26/month)** when:
- You exceed 5,000 errors/month
- You need multiple team members
- You want advanced features like custom dashboards

## 🚨 Troubleshooting

### Sentry Not Receiving Errors
1. Check `SENTRY_DSN` is set in Render environment variables
2. Verify environment is set to `production` or `staging`
3. Test with a manual error: `Sentry.capture_message("Test error")`

### Too Many Errors
If you're hitting the 5,000/month limit:
1. Review which errors are most frequent
2. Fix common bugs to reduce error volume
3. Adjust sample rate if needed
4. Consider upgrading to paid plan

### Performance Impact
Sentry has minimal performance impact:
- ~1-2ms overhead per request
- Async error submission
- Configurable sampling rates

## 🎉 Next Steps

With Sentry configured, you now have:
- **Real-time error tracking** with detailed stack traces
- **Performance monitoring** to identify slow requests
- **Release tracking** to correlate errors with deployments
- **Team collaboration** tools for debugging

Your application is now production-ready with enterprise-grade error monitoring!

---

## 📞 Support

- **Sentry Documentation**: [docs.sentry.io](https://docs.sentry.io)
- **Ruby SDK Guide**: [docs.sentry.io/platforms/ruby](https://docs.sentry.io/platforms/ruby)
- **Performance Monitoring**: [docs.sentry.io/product/performance](https://docs.sentry.io/product/performance)
