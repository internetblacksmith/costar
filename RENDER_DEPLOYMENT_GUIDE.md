# Quick Start - Render.com Deployment

This is a simplified guide to get ActorSync deployed on Render.com in minutes.

## Prerequisites

- [ ] GitHub account with your code pushed
- [ ] Render.com account (sign up for free)
- [ ] TMDB API key from [themoviedb.org](https://www.themoviedb.org/settings/api)
- [ ] Environment variables configured (TMDB_API_KEY, etc.)

## Step-by-Step Deployment

### 1. Prepare Your Code

```bash
# Run the deployment preparation script
./scripts/deploy.sh

# Or manually check:
bundle install
git add .
git commit -m "Deploy to Render.com"
git push origin main
```

### 2. Create Render Service

1. Go to [render.com](https://render.com) and sign in
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository
4. Select your repository and branch (`main`)

### 3. Configure Service

**Build & Deploy Settings:**
- **Environment**: `Ruby`
- **Build Command**: `bundle install`
- **Start Command**: `bundle exec ruby app.rb`

**Environment Variables:**
Click "Add Environment Variable" and add:

**Environment Variables (synced from Doppler automatically):**
- `TMDB_API_KEY` = `your_actual_tmdb_api_key`
- `RACK_ENV` = `production`
- `POSTHOG_API_KEY` = `your_posthog_key` (optional)

### 4. Deploy

1. Click **"Create Web Service"**
2. Wait for deployment (usually 2-5 minutes)
3. Your app will be available at: `https://your-app-name.onrender.com`

## Post-Deployment

### Verify Deployment
- [ ] App loads successfully
- [ ] Search functionality works
- [ ] Actor comparison displays correctly
- [ ] Images load properly

### Monitor
- Check logs in Render dashboard
- Monitor for any errors
- Test with different actors

## Free Tier Limitations

- **512MB RAM** - Sufficient for the app
- **Apps sleep after 15 minutes** - First request may be slow
- **750 hours/month** - Enough for personal projects

## Next Steps

1. **Custom Domain** (paid plan): Add your own domain
2. **Monitoring**: Set up alerts for downtime
3. **Analytics**: Add PostHog API key for user tracking
4. **Performance**: Upgrade to paid plan for better performance

## Troubleshooting

**Common Issues:**
- **Build fails**: Check Ruby version in render.yaml
- **App won't start**: Verify environment variables
- **Images don't load**: Check TMDB API key
- **Slow first load**: Normal on free tier (app sleeps)

**Get Help:**
- Check build logs in Render dashboard
- Verify environment variables are set
- Test API endpoints manually

That's it! Your ActorSync app should now be live on Render.com 🎉