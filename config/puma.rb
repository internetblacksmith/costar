# frozen_string_literal: true

# Puma configuration for production deployment

# Port to bind to
port ENV.fetch('PORT') { 4567 }

# Environment
environment ENV.fetch('RACK_ENV') { 'development' }

# Number of workers and threads
workers ENV.fetch('WEB_CONCURRENCY') { 1 }
threads_count = ENV.fetch('RAILS_MAX_THREADS') { 1 }
threads threads_count, threads_count

# Preload the application for better memory usage in production
preload_app!

# Bind to all interfaces
bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { 4567 }}"

# Pidfile location
pidfile ENV.fetch('PIDFILE') { 'tmp/pids/server.pid' }

# Enable serving static files
# (Render handles this, but keeping for compatibility)
serve_static_files = ENV.fetch('RAILS_SERVE_STATIC_FILES') { false }

# Logging
stdout_redirect ENV.fetch('RAILS_LOG_TO_STDOUT') { 'log/puma_stdout.log' },
                ENV.fetch('RAILS_LOG_TO_STDOUT') { 'log/puma_stderr.log' },
                true

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # This is only needed for when using ActiveRecord
end