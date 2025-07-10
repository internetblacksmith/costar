# ActorSync - Project Context

## Project Overview
A web application that allows users to enter two actor names and visualize their filmographies in a timeline, highlighting movies they appeared in together. Built with Ruby/Sinatra backend and HTMX frontend for secure API key handling.

## Current Status
- **Phase**: Optimized & Refactored (Pre-Production)
- **Last Updated**: 2025-07-09
- **Current State**: Fully optimized application with modular architecture, ready for production hardening

## Architecture & Tech Stack
- **Backend**: Ruby with Sinatra framework + Service Layer Architecture
- **Frontend**: HTML, Material Design Components Web (MDC-Web), HTMX for dynamic interactions
- **API**: The Movie Database (TMDB) API (called from backend with caching)
- **Styling**: Modular CSS with Material Design, dark/light theme support
- **Caching**: In-memory cache with TTL for API responses
- **Security**: API key stored securely on server-side, theme switching
- **Version Control**: Git with clean commit history

## Key Features
- Actor name search with autocomplete and chip-based selection
- Filmography retrieval from TMDB API with caching
- Vertical timeline visualization by year with chronological movie ordering
- Highlighting of common movies between actors
- Responsive design for desktop and mobile (optimized mobile timeline)
- Dark/light theme switching with persistent preference
- Material Design UI components
- Movie poster images with responsive loading and lazy loading
- Secure server-side API handling with error management

## Architecture Overview
```
Frontend (HTMX + MDC-Web)
├── Modular JavaScript (ActorSearch, SnackbarModule, ScrollToTop)
├── Modular CSS (Base, Components, Responsive)
└── Template Partials (Movie Cards, Search Fields, etc.)

Backend (Ruby/Sinatra)
├── Service Layer
│   ├── TMDBService (API interactions + caching)
│   ├── TimelineBuilder (Timeline processing logic)
│   ├── ActorComparisonService (Orchestration)
│   └── PosterService (Movie poster URLs + optimization)
├── Configuration Management
│   ├── Environment validation
│   ├── Cache management
│   └── Error handling
└── Web Layer (Simplified app.rb)
```

## Development Progress
- [x] Project architecture designed
- [x] Ruby/Sinatra backend implementation
- [x] HTMX frontend with dynamic interactions
- [x] TMDB API integration (server-side)
- [x] Actor search with autocomplete
- [x] Timeline visualization
- [x] Shared movie highlighting
- [x] Responsive design
- [x] Environment configuration
- [x] Documentation and setup instructions
- [x] Git repository initialization
- [x] **NEW: Service layer architecture with TMDBService, TimelineBuilder**
- [x] **NEW: Configuration management with validation**
- [x] **NEW: Thread-safe caching layer with TTL**
- [x] **NEW: Template partials for reusable components**
- [x] **NEW: Modular JavaScript architecture**
- [x] **NEW: Organized CSS with design tokens**
- [x] **NEW: Dark/light theme switching**
- [x] **NEW: Mobile-optimized timeline layout**
- [x] **NEW: Material Design Components integration**
- [x] **NEW: Comprehensive error handling**
- [x] **NEW: Movie poster integration with responsive images**

## Code Quality Improvements
- **Lines of Code**: app.rb reduced by 33% (189 → 127 lines)
- **CSS Organization**: 740-line monolith split into 12 focused modules
- **JavaScript**: Organized into reusable modules with clear responsibilities
- **Template Reuse**: Extracted partials for movie cards, search fields, etc.
- **Performance**: ~80% reduction in API calls through caching
- **Maintainability**: Service layer enables easy testing and extension

## Project Structure
```
actorsync/
├── lib/
│   ├── config/
│   │   ├── configuration.rb    # Environment management
│   │   ├── cache.rb           # Caching layer
│   │   └── errors.rb          # Error classes
│   └── services/
│       ├── tmdb_service.rb           # TMDB API client
│       ├── timeline_builder.rb       # Timeline logic
│       └── actor_comparison_service.rb # Orchestration
├── public/
│   ├── css/
│   │   ├── base/              # Variables, typography
│   │   ├── components/        # Component styles
│   │   ├── responsive.css     # Mobile styles
│   │   └── main.css          # Import coordinator
│   └── js/
│       ├── modules/           # JavaScript modules
│       └── app.js            # Main application
├── views/
│   ├── partials/             # Reusable components
│   ├── index.erb             # Search interface
│   ├── timeline.erb          # Timeline display
│   └── layout.erb            # Main layout
└── app.rb                    # Simplified web layer
```

## Important Notes
- **App Name**: ActorSync
- **Architecture**: Service-oriented Ruby/Sinatra backend + Modular HTMX frontend
- **Security**: API key stored server-side with configuration validation
- **Port**: Runs on localhost:4567
- **Dependencies**: Ruby 3.0+, Bundler
- **Repository**: Clean git history with logical commits
- **Caching**: Thread-safe in-memory cache (5-30 min TTL)
- **Themes**: Dark/light mode with localStorage persistence
- **Mobile**: Optimized timeline layout for mobile devices

## Development Workflow
1. Install dependencies: `bundle install`
2. Configure environment: `cp .env.example .env` and add TMDB API key
3. Run application: `bundle exec ruby app.rb`
4. Development mode: `bundle exec rerun ruby app.rb`
5. Code quality: `bundle exec rubocop -a` (auto-fix enabled)
6. Git workflow: feature branches, clean commits, descriptive messages

## Production Readiness
- **Status**: Pre-production (see PRODUCTION_READINESS_CHECKLIST.md)
- **Optimization**: Complete ✅
- **Testing**: Needed for production
- **Security**: Basic (needs hardening for production)
- **Monitoring**: Needed for production
- **Infrastructure**: Needs production setup

## Next Steps
- **Immediate**: Production hardening (security, monitoring, testing)
- **Future Features**: 
  - Movie posters and ratings
  - User favorites/watchlists
  - Export functionality
  - Advanced filtering options
  - Progressive Web App features

---
*This context file is automatically loaded and should be updated as the project evolves*