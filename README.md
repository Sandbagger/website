# Lite-Rails

Inspired by Stephen Margheim's talk https://fractaledmind.github.io/2023/12/23/rubyconftw/ with some opinionated additions for the view layer.

## compilation settings for sqlite

bundle config set build .sqlite3 "--with-sqlite-cflags='-DSQLITE_DQS=0 -DSQLITE_THREADSAFE=0 -DSQLITE_DEFAULT_MEMSTATUS=0 -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS -DSQLITE_MAX_EXPR_DEPTH=0 -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_SHARED_CACHE -DSQLITE_USE_ALLOCA -DSQLITE_ENABLE_FTS5'"

## Production database durability

Production SQLite and Active Storage persist on the host-mounted
`/srv/apps/website/shared` path. The application does not manage off-host
database backups; configure and test host snapshots or backups separately.

## Phlex

- a boon for view composition
- as an alternative to machine-gunning utility classes I am following the philosophy of https://every-layout.dev/ in the of layout primitives. Each layout primitive is its own component.

## Standard.site / AT Protocol

Published writing can be registered on AT Protocol using the Standard.site
publication and document lexicons. The checked-in registry at
`config/standard_site.json` maps local article slugs to their AT URIs. Rails
uses it to expose the publication verification endpoint and document discovery
links without making network requests while serving pages.

Create an app password for the configured AT Protocol account, then publish or
update all currently public articles with:

```sh
bin/rails standard_site:publish
```

Use an app password rather than the account password. The command prompts for
it without echoing and never writes it to the repository. For non-interactive
use, pass it in `ATPROTO_APP_PASSWORD`. The task is idempotent: it creates
missing records, updates known records, and persists returned AT URIs after
every successful write. Commit the resulting `config/standard_site.json`
changes, deploy them, and verify
`/.well-known/site.standard.publication` plus each article's
`<link rel="site.standard.document">` tag.

## Design system (work in progess)

- embrace the cascade — the order of require statements in the application.css is important.
- minimal, opinionated Rails-like framework
- no preprocessor
- inspired by https://cube.fyi/ and https://every-layout.dev/.
