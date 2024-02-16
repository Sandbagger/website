# Lite-Rails

Inspired by Stephen Margheim's talk https://fractaledmind.github.io/2023/12/23/rubyconftw/ with some opinionated additions for the view layer.

## compilation settings for sqlite

bundle config set build .sqlite3 "--with-sqlite-cflags='-DSQLITE_DQS=0 -DSQLITE_THREADSAFE=0 -DSQLITE_DEFAULT_MEMSTATUS=0 -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS -DSQLITE_MAX_EXPR_DEPTH=0 -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_SHARED_CACHE -DSQLITE_USE_ALLOCA -DSQLITE_ENABLE_FTS5'"

## Phlex

- a boon for view composition
- as an alternative to machine-gunning utility classes I am following the philosophy of https://every-layout.dev/ in the of layout primitives. Each layout primitive is its own component.

## Design system (work in progess)

- embrace the cascade - the order of require statements in the application.css is important.
- no preprocessor
- inspired by https://cube.fyi/ and https://every-layout.dev/.
