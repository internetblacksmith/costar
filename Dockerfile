# syntax = docker/dockerfile:1

# Use the official Ruby image
ARG RUBY_VERSION=3.4.6
FROM ruby:$RUBY_VERSION-slim as base

# Sinatra app lives here
WORKDIR /app

# Set production environment
ENV RACK_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    PORT="4567"

# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config gnupg

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl gnupg bash ca-certificates && \
    curl -Ls --tlsv1.2 --proto "=https" --retry 3 \
      https://cli.doppler.com/install.sh | bash && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 ruby && \
    useradd ruby --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /app/tmp/pids /app/data && \
    chown -R ruby:ruby /app
USER ruby:ruby

# Entrypoint prepares the environment
ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 4567
CMD ["doppler", "run", "--", "bundle", "exec", "puma", "-C", "config/puma.rb"]
