# 🎬 ActorSync

A web application that visualizes actor filmographies in a timeline format, highlighting movies that two actors have appeared in together. Built with Ruby/Sinatra backend and HTMX frontend for secure API key handling.

## Features

- **Actor Search**: Search for actors with autocomplete suggestions
- **Timeline Visualization**: View filmographies organized by year in a vertical timeline
- **Shared Movies Highlighting**: Common movies between actors are highlighted in red
- **Responsive Design**: Works on desktop and mobile devices
- **TMDB Integration**: Uses The Movie Database API for accurate film data
- **Secure Backend**: API key stored server-side for security

## Prerequisites

- Ruby 3.0+ installed
- Bundler gem installed (`gem install bundler`)

## Setup

1. **Clone and Install Dependencies**:
   ```bash
   bundle install
   ```

2. **Get a TMDB API Key**:
   - Visit [The Movie Database](https://www.themoviedb.org/settings/api)
   - Create a free account and request an API key
   - Copy your API key

3. **Configure Environment**:
   
   **Option A: Using Doppler (Recommended)**
   ```bash
   # Install Doppler CLI
   brew install dopplerhq/cli/doppler  # macOS
   
   # Setup Doppler
   doppler login
   doppler setup --project actorsync --config development
   doppler secrets set TMDB_API_KEY="your_api_key"
   ```
   
   **Option B: Using .env file**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and add your API keys:
   ```
   TMDB_API_KEY=your_actual_api_key_here
   POSTHOG_API_KEY=your_posthog_api_key_here
   POSTHOG_HOST=https://app.posthog.com
   ```

4. **Run the App**:
   
   **With Doppler**:
   ```bash
   doppler run -- bundle exec ruby app.rb
   # Or with auto-reload
   doppler run -- bundle exec rerun ruby app.rb
   ```
   
   **Without Doppler**:
   ```bash
   bundle exec ruby app.rb
   # Or with auto-reload
   bundle exec rerun ruby app.rb
   ```

5. **Open in Browser**:
   - Direct app: `http://localhost:4567`
   - Shotgun: `http://localhost:9393`

## How to Use

1. Enter the name of the first actor in the "First Actor" field
2. Select the correct actor from the autocomplete suggestions
3. Repeat for the second actor
4. Click "Compare Filmographies"
5. View the timeline showing both actors' movies by year
6. Shared movies are highlighted in red with a "Shared Movies!" indicator

## Project Structure

```
actorsync/
├── app.rb                 # Main Sinatra application
├── config.ru             # Rack configuration
├── Gemfile               # Ruby dependencies
├── .env.example          # Environment variables template
├── views/                # ERB templates
│   ├── layout.erb        # Main layout
│   ├── index.erb         # Home page
│   ├── suggestions.erb   # Actor search suggestions
│   └── timeline.erb      # Timeline visualization
├── public/               # Static assets
│   └── styles.css        # Styling and responsive design
└── README.md            # This file
```

## API Endpoints

- `GET /` - Main application page
- `GET /api/actors/search?q=query&field=actor1` - Search for actors
- `GET /api/actors/compare?actor1_id=123&actor2_id=456` - Compare two actors

## Technology Stack

- **Backend**: Ruby with Sinatra framework
- **Frontend**: HTML, CSS, HTMX for dynamic interactions
- **API**: The Movie Database (TMDB) API v3
- **Templating**: ERB (Embedded Ruby)
- **Styling**: Modern CSS with responsive design

## Security Features

- API key stored securely on server-side
- No client-side API key exposure
- Server-side API request handling

## Development

For development with auto-reloading:
```bash
bundle exec shotgun config.ru
```

Alternative with rerun:
```bash
bundle exec rerun ruby app.rb
```

### Code Quality

Run RuboCop to check code style and automatically fix issues:
```bash
bundle exec rubocop -A
```

## Analytics Setup (Optional)

ActorSync includes PostHog analytics integration to track usage and growth:

1. **Create PostHog Account**: Visit [PostHog](https://posthog.com) and create a free account
2. **Get API Key**: Copy your project API key from PostHog settings
3. **Add to Environment**: Add `POSTHOG_API_KEY` to your `.env` file
4. **Privacy Compliant**: Analytics only activate when API key is present

### Tracked Events:
- **Page views**: Track overall site visits
- **Actor selections**: Monitor search usage
- **Comparison starts**: Track user engagement 
- **Comparison completions**: Measure successful interactions

### Monetization Tracking:
With ~75,000-100,000 monthly page views, you'll be ready to approach TMDB for commercial licensing to add advertising revenue.

## TMDB API Compliance

This application uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.

**Important**: This is a non-commercial personal project. For commercial use, you must obtain a commercial agreement with TMDB.

### Commercial Use Definition
According to TMDB terms, the following activities require a commercial license:
- Adding advertising or any form of monetization
- Charging users fees or subscriptions
- Generating revenue through the application
- Using TMDB content for commercial recommendations

### Monetization Plans?
If you plan to monetize this application (including ads), you **must** contact TMDB for a commercial agreement before implementing any revenue-generating features.

**Terms of Use**: Please review [TMDB API Terms of Use](https://www.themoviedb.org/api-terms-of-use) before using this application.

## License

MIT License

**Note**: While this code is MIT licensed, the TMDB API has its own terms of use that must be followed when using the application.