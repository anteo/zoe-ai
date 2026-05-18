# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0.4

FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libpq-dev \
      libyaml-dev \
      libvips \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json bun.lock bun.config.js postcss.config.js tailwind.config.js ./
RUN bun install --frozen-lockfile

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

FROM base AS runtime

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libpq5 \
      libyaml-0-2 \
      libvips \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    mkdir -p /rails/log /rails/storage /rails/tmp/pids && \
    chown -R rails:rails /rails

USER rails:rails

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["web"]
