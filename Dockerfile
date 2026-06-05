# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0.4
ARG UV_VERSION=0.11.15

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ruby:${RUBY_VERSION}-slim AS base
COPY --from=uv /uv /uvx /usr/local/bin/

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

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    rm -rf node_modules log/* tmp/*

FROM base AS runtime

LABEL org.opencontainers.image.source="https://github.com/anteo/zoe-ai"

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      git \
      libpq5 \
      libyaml-0-2 \
      libvips && \
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
