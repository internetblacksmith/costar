# Deployment Guide - Render.com

This guide covers deploying ActorSync to Render.com's free tier.

## Prerequisites

1. **Render.com Account**: Sign up at [render.com](https://render.com)
2. **GitHub Repository**: Push your code to a GitHub repository
3. **TMDB API Key**: Get your API key from [themoviedb.org](https://www.themoviedb.org/settings/api)

## Deployment Steps

### 1. Connect GitHub Repository

1. Log into your Render dashboard
2. Click "New +" → "Web Service"
3. Connect your GitHub account and select your repository
4. Choose the branch to deploy (usually `main`)

### 2. Configure Service Settings

Use these settings in the Render dashboard:

**Basic Settings:**
- **Name**: `actorsync` (or your preferred name)
- **Environment**: `Ruby`
- **Region**: `Oregon (US West)` (or closest to your users)
- **Branch**: `main`

**Build & Deploy:**
- **Build Command**: `bundle install`
- **Start Command**: `bundle exec ruby app.rb`

**Plan:**
- **Instance Type**: `Free` (0.5 CPU, 512MB RAM)

### 3. Environment Variables

Add these environment variables in the Render dashboard:

**Required:**
- `TMDB_API_KEY`: Your TMDB API key
- `RACK_ENV`: `production`

**Optional:**
- `POSTHOG_API_KEY`: Your PostHog API key (if using analytics)
- `POSTHOG_HOST`: `https://app.posthog.com` (default)

### 4. Deploy

1. Click "Create Web Service"
2. Render will automatically deploy your application
3. Monitor the build logs for any issues
4. Once deployed, you'll get a URL like: `https://actorsync-xxxx.onrender.com`

## Configuration Files

The following files are included for Render deployment:

### render.yaml
```yaml
services:
  - type: web
    name: actorsync
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec ruby app.rb
    envVars:
      - key: RACK_ENV
        value: production
      - key: PORT
        value: 10000
      - key: TMDB_API_KEY
        sync: false
    healthCheckPath: /
    numInstances: 1
    plan: free
    region: oregon
    runtime: ruby-3.1.0
```

### Procfile
```
web: bundle exec ruby app.rb -p $PORT
```

## Free Tier Limitations

**Render.com Free Tier includes:**
- 512MB RAM
- 0.5 CPU
- Apps sleep after 15 minutes of inactivity
- 750 hours/month runtime (enough for personal projects)
- Custom domains not included (upgrade to paid plan)

## Post-Deployment

### Health Check
- Render automatically monitors your app at the root path `/`
- If the app doesn't respond, it will restart automatically

### Monitoring
- Check logs in the Render dashboard
- Monitor performance and uptime
- Set up alerts for deployment failures

### Updates
- Push to your GitHub repository
- Render will auto-deploy on pushes to the main branch
- Enable auto-deploy in your service settings

## Production Optimizations

For better performance on the free tier:

1. **Enable caching** (already implemented in the app)
2. **Optimize images** (responsive images already included)
3. **Minimize API calls** (TMDB caching implemented)
4. **Use CDN** for static assets (upgrade to paid plan)

## Troubleshooting

### Common Issues

**Build Failures:**
- Check Ruby version compatibility
- Ensure all gems are in Gemfile
- Verify environment variables are set

**App Won't Start:**
- Check start command syntax
- Verify port binding (app listens on 0.0.0.0:PORT)
- Check for missing environment variables

**Performance Issues:**
- Free tier sleeps after 15 minutes
- First request after sleep takes longer
- Consider paid plan for production use

### Logs
Access logs in the Render dashboard:
1. Go to your service
2. Click "Logs" tab
3. Monitor real-time logs or download historical logs

## Scaling

To handle more traffic:

1. **Upgrade Plan**: Switch to paid plan for more resources
2. **Horizontal Scaling**: Add more instances
3. **Database**: Add PostgreSQL or Redis for session storage
4. **CDN**: Enable CDN for static assets

## Security

Production security is configured:
- Environment variables for secrets
- HTTPS enabled by default
- Session security enabled
- Input validation implemented

## Support

For Render-specific issues:
- Check [Render documentation](https://render.com/docs)
- Contact Render support
- Community forums and Discord

For app-specific issues:
- Check application logs
- Verify environment variables
- Test API endpoints manually