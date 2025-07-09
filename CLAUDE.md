# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ActorSync is a web application for comparing actor filmographies in a timeline format. Built with Ruby/Sinatra backend and HTMX frontend.

## Architecture

- **Backend**: Ruby with Sinatra framework
- **Frontend**: HTMX for dynamic interactions
- **Database**: None (uses TMDB API directly)
- **Styling**: Modern CSS with responsive design

## Development Commands

- **Install dependencies**: `bundle install`
- **Run development server**: `bundle exec rerun ruby app.rb`
- **Run production server**: `bundle exec ruby app.rb`
- **Test**: No test framework currently configured
- **Lint**: `bundle exec rubocop -A`

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
│   └── styles.css        # Styling
└── .claude/              # Claude Code configuration
```

## Key Development Notes

- API key stored in `.env` file (server-side only)
- HTMX handles frontend interactions without JavaScript
- ERB templates for server-side rendering
- Responsive design with mobile support
- Clean git history with logical commits

## Project Context

A detailed project context file (CONTEXT.md) is automatically loaded with each session and contains:
- Current project status and progress
- Architecture decisions and tech stack
- Key features and requirements
- Development notes and next steps

## Git Workflow

- Clean commit history with descriptive messages
- Logical commit separation (config, backend, frontend, styling)
- Use conventional commit format when appropriate
- Always include Claude Code attribution in commits