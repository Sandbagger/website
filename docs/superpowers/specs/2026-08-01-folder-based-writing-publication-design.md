# Folder-Based Writing Publication Design

## Summary

Replace front-matter publication status with a filesystem convention that makes
the editorial state of every writing resource visible from the file tree.
Drafts live in `writing/drafts/`. Posts committed for publication live in
`writing/posts/` and carry their publication date in the filename.

The public URL remains `/writing/<slug>`. Drafts and future-dated posts are
previewable in development and test, but unavailable in production. Scheduled
posts become public automatically at midnight in the `Europe/Brussels` time
zone, without a deploy, application restart, or filesystem mutation.

## Goals

- Make draft, scheduled, and published state visible without opening a post.
- Preserve automatic scheduled publication.
- Preserve every existing published `/writing/<slug>` URL.
- Allow local browser previews of drafts and scheduled posts.
- Return 404 for drafts and not-yet-published posts in production.
- Remove `status`, `published`, and `publish_at` as competing sources of truth.
- Give the homepage, archive, recommendations, and RSS feed one shared query for
  published writing.

## Non-goals

- Add an administrative publishing interface.
- Add authentication or secret preview links.
- Mutate or commit files automatically when a scheduled date arrives.
- Change article design, Markdown rendering, or post contents.
- Change existing published URLs or cover-image URLs.

## Filesystem Convention

```text
app/content/pages/writing/
|-- drafts/
|   `-- unfinished-post.markerb
`-- posts/
    |-- 2024-03-10-capture-request-referrer-via-css.html.markerb
    `-- 2026-09-15-future-article.markerb
```

Directory and filename together define editorial state:

| Location | Date | State |
|---|---|---|
| `drafts/<slug>` | none | Draft |
| `posts/YYYY-MM-DD-<slug>` | future Brussels date | Scheduled |
| `posts/YYYY-MM-DD-<slug>` | current or past Brussels date | Published |

`posts/` means that the author has committed the article for publication. It is
deliberately not named `published/`, because it may contain future-dated posts.

The filename date is authoritative. Writing front matter must not contain
`status`, `published`, or `publish_at`. Other metadata such as `title`, `topic`,
and `emoji` remains unchanged.

## Path and Metadata Parsing

A small writing-path value object owns filename parsing. For a post path it:

1. Removes Sitepress handler and optional HTML extensions.
2. Requires a valid leading `YYYY-MM-DD-` date.
3. Parses the prefix into a real calendar date.
4. Treats the remaining basename as the canonical slug.
5. Exposes the publication date, slug, and canonical request path.

For example:

```text
writing/posts/2024-03-10-example.html.markerb
  publication date: 2024-03-10
  slug:             example
  request path:     /writing/example
```

Draft filenames do not require a date prefix. Their development preview path is
`/writing/drafts/<slug>`.

The parser is shared by Sitepress mapping, collection queries, validation,
authoring tools, and cover generation so those systems cannot disagree about a
slug or date.

## Sitepress Resource Mapping

A dedicated Sitepress resource-pipeline component maps physical writing paths
to request paths before routing:

- Every resource under `writing/posts/` is remapped to
  `/writing/<date-stripped-slug>`.
- The original `/writing/posts/...` path is removed and never routable.
- Draft resources remain at `/writing/drafts/<slug>` in development and test.
- Draft resources are removed from the production Sitepress tree.
- Duplicate canonical slugs fail during resource indexing.

All post resources, including scheduled ones, receive derived publication-date
metadata for the existing layout and collection presentation code. The derived
value may use the existing `publish_at` data key internally during migration,
but it is never read from front matter.

Scheduled resources must remain mapped in the running production application.
Removing them at boot would require a restart on publication day. Instead, a
request-time publication policy checks the current Brussels date before a post
is rendered. A future-dated post returns 404 in production and becomes available
automatically when its date arrives. Development and test may render it for
preview.

The policy uses an explicit `Europe/Brussels` clock and accepts an injected date
in tests. It must not depend on the server's local timezone.

## Published Writing Catalogue

A single writing catalogue owns collection membership and ordering. Its
published query:

- Considers only resources physically sourced from `writing/posts/`.
- Includes dates on or before today in `Europe/Brussels`.
- Excludes future-dated posts and all drafts.
- Sorts newest publication date first.
- Can exclude the current request path for article recommendations.

The Sitepress page controller, feed controller, homepage collection, writing
archive, and article-tail recommendations all consume this query. Presentation
components continue to accept already-selected resources and do not acquire
publication logic.

## Authoring Workflow

`./go write` changes to create a new post in `writing/drafts/` from a template
kept outside the routable post directories.

Publishing or scheduling is an explicit file move:

```bash
git mv \
  app/content/pages/writing/drafts/my-post.markerb \
  app/content/pages/writing/posts/2026-09-15-my-post.markerb
```

A past or current date publishes on the next application reload or deploy. A
future date schedules publication. Once deployed, the request-time policy and
catalogue make the post live when the Brussels date changes, without another
deploy.

Moving a post back to `drafts/` withdraws it on the next deploy. Deployed files
remain immutable; no runtime job edits the repository.

## Development and Production Behavior

| Resource | Development/test | Production |
|---|---|---|
| Draft | `/writing/drafts/<slug>` renders | 404; no Sitepress resource |
| Scheduled post | `/writing/<slug>` renders | 404 until publication date |
| Published post | `/writing/<slug>` renders | `/writing/<slug>` renders |
| Physical `posts` URL | 404 | 404 |

Draft and scheduled previews use the normal article layout so they accurately
represent the final page. They are never included in the homepage, archive,
recommendations, or RSS feed in any environment.

## Validation and Failure Handling

Content validation runs during tests and application initialization. It fails
fast with the source filename and a specific message when:

- A file under `posts/` lacks a date prefix.
- A date prefix is not a valid calendar date.
- The dated filename has no slug.
- Two writing files resolve to the same canonical post slug.
- A writing file contains legacy `status`, `published`, or `publish_at` keys.

Invalid publication metadata must never silently hide or expose content. A
future date is valid and is not a validation error.

## Existing Content Migration

The four currently published resources move to `posts/` using their existing
`publish_at` dates:

- `2024-02-27-markdown-in-rails-with-phlex-and-sitepress.html.markerb`
- `2024-03-03-tag-overriding-in-phlex-and-markdown.html.markerb`
- `2024-03-10-capture-request-referrer-via-css.html.markerb`
- `2025-10-12-pettis-good-tariffs-vs-bad.markerb`

Resources currently excluded from published collections move to `drafts/`.
The template moves outside both routable directories. Legacy publication keys
are removed from every migrated file.

Migration must assert that each currently published request path resolves to
the same post after the move. Existing external links therefore continue to
work.

## Cover Images

Cover lookup continues to use the canonical request-path slug. Post image
generation uses the shared path parser so the physical date prefix and `posts/`
directory never appear in image filenames.

Existing covers such as `public/images/posts/pettis-good-tariffs-vs-bad.svg`
remain valid. Cover generation may inspect drafts and posts, but publishing a
dated file must not change its cover slug.

## Testing

Focused tests cover:

- Valid post paths, optional HTML extensions, invalid dates, missing dates, and
  missing slugs.
- Date classification immediately before, on, and after a publication date in
  the Brussels timezone.
- Duplicate canonical slug and legacy-front-matter validation failures.
- Draft previews in development/test and draft absence from the production
  resource tree.
- Scheduled previews outside production and production 404 responses before
  publication.
- Automatic scheduled availability when the injected current date reaches the
  filename date, without rebuilding the Sitepress tree.
- Absence of physical `/writing/posts/...` routes.
- Stable request paths for all migrated published articles.
- Homepage, archive, recommendation, and RSS exclusion of drafts and scheduled
  posts.
- Descending publication ordering and current-article exclusion.
- Stable cover-image slugs after date-prefixed migration.
- `./go write` creating a draft rather than a routable post.

The full Rails and system suites remain the final regression gate.

## Trade-offs

The filename becomes part of the content model, so rescheduling requires a file
rename. This is intentional: it makes the schedule visible in the repository
and gives Git a useful history of publication decisions.

The Sitepress mapping adds a small layer between physical paths and public URLs.
That complexity is preferable to exposing directory names in URLs, duplicating
status across front matter and folders, or requiring runtime Git mutations.
