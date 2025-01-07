# ActorSync - Project Context

## Project Overview
A web application that allows users to enter two actor names and visualize their filmographies in a timeline, highlighting movies they appeared in together. Built with Ruby/Sinatra backend and HTMX frontend for secure API key handling.

## Current Status
- **Phase**: Production Ready
- **Last Updated**: 2025-07-07
- **Current State**: Fully functional application with secure architecture

## Architecture & Tech Stack
- **Backend**: Ruby with Sinatra framework
- **Frontend**: HTML, CSS, HTMX for dynamic interactions
- **API**: The Movie Database (TMDB) API (called from backend)
- **Styling**: Modern CSS with responsive design
- **Security**: API key stored securely on server-side
- **Version Control**: Git with clean commit history

## Key Features
- Actor name search with autocomplete
- Filmography retrieval from TMDB API
- Vertical timeline visualization by year
- Highlighting of common movies between actors
- Responsive design for desktop and mobile
- Secure server-side API handling

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

## Important Notes
- **App Name**: ActorSync
- **Architecture**: Ruby/Sinatra backend + HTMX frontend
- **Security**: API key stored server-side in .env file
- **Port**: Runs on localhost:4567
- **Dependencies**: Ruby 3.0+, Bundler
- **Repository**: Clean git history with logical commits
- Fully functional timeline visualization
- Highlights shared movies between actors

## Development Workflow
1. Install dependencies: `bundle install`
2. Configure environment: `cp .env.example .env` and add TMDB API key
3. Run application: `bundle exec ruby app.rb`
4. Development mode: `bundle exec rerun ruby app.rb`
5. Git workflow: feature branches, clean commits, descriptive messages

## Next Steps
- Optional: Add movie posters and ratings
- Optional: Add user favorites/watchlists
- Optional: Add export functionality
- Optional: Add advanced filtering options

---
*This context file is automatically loaded and should be updated as the project evolves*