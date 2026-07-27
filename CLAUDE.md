# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

Rails 8 + SQLite (via Litestack) + Phlex views + Sitepress for static content + Markdown-Rails + Propshaft + jsbundling (esbuild) + Hotwire. Ruby 3.3.5. Deployed via Kamal v2 (container image on GHCR → shared Hetzner host); see `docs/DEPLOY.md`.

## Commands

- `./go up` / `bin/dev` — run app via `Procfile.dev` (Rails server + `yarn build --watch`). Default port 3000.
- `./go install` — `bundle install`, `yarn install`, `db:create`, `db:migrate` (dev + test).
- `./go spec` — runs `bundle exec rspec` (note: test suite is actually Minitest under `test/`; use `bin/rails test` for those).
- `bin/rails test test/controllers/feed_controller_test.rb` — run a single test file.
- `bundle exec standardrb` — lint (uses the `standard` gem).
- `./go write` — scaffold a new `app/content/pages/writing/<slug>.makerb` from the template and fill in the title.
- `bin/rails images:generate_posts[true]` — regenerate deterministic SVG cover images in `public/images/posts/` (pass `true` to overwrite).
- `bin/deploy` — production deploy via Kamal (loads `.env.deploy`, delegates to `bundle exec kamal`). See `docs/DEPLOY.md`.

## Architecture

### Content pipeline (Sitepress + Markdown-Rails + Phlex)

Pages are not controllers. Routes end in `sitepress_pages` + `sitepress_root` (`config/routes.rb`), so anything under `app/content/pages/` is served at the corresponding URL. The RSS feed is the only conventional Rails route.

- **`.markerb` files** render as plain markdown (via Redcarpet/`ApplicationMarkdown`). The extension is retained for historical reasons; there is no ERB preprocessing step — it was removed because it executes arbitrary Ruby and no post used it. If you ever need embedded Ruby in a post, prefer a Phlex partial over reintroducing ERB in markdown.
- **Front matter** on pages drives `PageModel` (`app/content/models/page_model.rb`) which exposes `title` and a `**/*.html*` collection. `status: index` / `layout: writing` etc. route pages through alternate layouts.
- **Layouts** live in `app/views/layouts/` as Phlex classes (`ApplicationLayout`). The layout exposes DSL methods (`page_title`, `cover_image`, `markdown`, `partial`) that `.markerb` pages call to configure the chrome around their content.
- **Phlex components** live in `app/views/components/`. `ApplicationComponent` provides shortcut methods (`center`, `box`, `stack`, `cluster`) that render layout-primitive components — follow the every-layout.dev pattern; do not machine-gun utility classes.

### CSS

No preprocessor. `app/assets/stylesheets/application.css` imports in a load-bearing order: `global` → `compositions` → `utilities` → `blocks`. The cascade is intentional — adding imports out of order will change specificity outcomes. Composition CSS corresponds 1:1 to Phlex layout-primitive components (`box`, `center`, `cluster`, `stack`, `flow`).

### Post cover images

`PostImageGenerator` (`lib/post_image_generator.rb`) reads frontmatter from every writing page and deterministically hashes the slug into an SVG (gradient + circles + title). Run via the `images:generate_posts` rake task. Skips existing files unless `overwrite: true`.

### SQLite configuration

SQLite is compiled with aggressive pragmas (see README.md). The Dockerfile re-applies these flags via `bundle config set --local build.sqlite3 ...` before `bundle install` — if you change the flags, update both the README and the Dockerfile. Litestack provides queue/cache/cable. Production SQLite persists only on the mounted `/srv/apps/website/shared` host path. A separate durable `/srv` filesystem is the default; `ALLOW_ROOT_DISK_STORAGE=1` is an explicit exception under which state survives deploys and reboots but is lost with a deleted, rebuilt, or failed root disk. Same-disk `/srv/backups` is not disaster recovery.

### Deployment

`config/deploy.yml` runs the `web` role and mounts `/srv/apps/website/shared` → `/rails/storage`, where SQLite and Active Storage persist. Secrets (`RAILS_MASTER_KEY`, `KAMAL_REGISTRY_PASSWORD`) come from `.env.deploy` at deploy time, sourced from 1Password. The repository does not provide off-host backup or replication; see `docs/DEPLOY.md` for the storage exception and recovery consequences.

## Conventions

- `standard` is the linter — match its style (frozen_string_literal, double quotes, etc.).
- New blog posts go in `app/content/pages/writing/` — prefer `./go write` over hand-creating files so they inherit `template.makerb`.
- When adding a layout primitive, add both the Phlex component (in `app/views/components/`) and the corresponding CSS file (in `app/assets/stylesheets/compositions/`), then import it in `application.css` in the correct cascade position.
