# syntax=docker/dockerfile:1
# Production image for williamneal.dev. Multi-stage: build layer has node + gcc,
# runtime layer is slim. SQLite is rebuilt from source with the project's
# custom compile flags (DQS=0, FTS5, etc. — see README.md).

ARG RUBY_VERSION=3.3.5
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# ---- build stage ---------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Node 22 LTS + yarn for jsbundling/esbuild.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY Gemfile Gemfile.lock ./

# Rebuild the sqlite3 gem's vendored SQLite with project-specific flags.
# Must run before `bundle install` so the compile picks them up.
RUN bundle config set --local build.sqlite3 \
      "--with-sqlite-cflags='-DSQLITE_DQS=0 -DSQLITE_THREADSAFE=0 -DSQLITE_DEFAULT_MEMSTATUS=0 -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS -DSQLITE_MAX_EXPR_DEPTH=0 -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_SHARED_CACHE -DSQLITE_USE_ALLOCA -DSQLITE_ENABLE_FTS5'" && \
    bundle install && \
    rm -rf /usr/local/bundle/cache /usr/local/bundle/ruby/*/cache

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

# Precompile bootsnap + assets. SECRET_KEY_BASE_DUMMY lets assets:precompile
# boot the app without a real key.
RUN bundle exec bootsnap precompile --gemfile app/ lib/ config/ && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# ---- runtime stage -------------------------------------------------------
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libyaml-0-2 \
      tzdata && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid rails --create-home --shell /bin/bash rails && \
    mkdir -p /rails/storage /rails/log /rails/tmp && \
    chown -R rails:rails /rails /usr/local/bundle

USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
