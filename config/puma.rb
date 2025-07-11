# frozen_string_literal: true

# Puma configuration for production deployment

# Port to bind to (Render sets this automatically)
port ENV.fetch('PORT', 4567)

# Environment
environment ENV.fetch('RACK_ENV', 'development')

# Threads configuration
threads_count = ENV.fetch('PUMA_THREADS', 5)
threads threads_count, threads_count

# Workers (keep at 1 for free tier)
workers ENV.fetch('WEB_CONCURRENCY', 0)

# Preload the application for better memory usage
preload_app! if ENV.fetch('WEB_CONCURRENCY', 0).to_i > 1

# Restart command
plugin :tmp_restart