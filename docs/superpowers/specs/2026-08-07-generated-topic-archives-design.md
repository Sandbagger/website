# Generated Topic Archives Design

## Goal

Turn writing topic metadata into reader-facing archive pages while exercising
Sitepress 5's generated-source and resource-tree APIs. Each topic displayed on
an article or writing collection links to a real Sitepress resource at
`/writing/topics/<slug>`. Topic archives list only currently published posts
and preserve the existing filesystem-based publication model.

## Content contract

The existing singular frontmatter key remains `topic`, but its value becomes a
strict YAML array:

```yaml
---
title: Markdown in Rails with Phlex and Sitepress
topic:
  - Ruby on Rails
  - Sitepress
  - Phlex
---
```

Every writing post and draft must provide a non-empty array of nonblank strings.
Labels retain their authored capitalization and must not contain leading or
trailing whitespace. Topics within one article must be unique when compared
case-insensitively. Comma-separated strings are no longer accepted; there is no
compatibility parser.

All existing writing content, the writing scaffold template, and the draft
generator move to this canonical representation in the same implementation.

## Topic identity

`Writing::Topic` is an immutable value object with two readers:

- `label`: the authored display label
- `slug`: `label.parameterize`, used in the public URL

An empty generated slug is invalid. Across the complete writing collection,
labels with the same slug represent the same topic only when their labels match
case-insensitively. A different label producing the same slug is a collision and
stops Sitepress tree construction. This prevents ambiguous routes such as `C`
and `C++` both claiming `/writing/topics/c`.

When capitalization differs across articles for the same case-insensitive
label, tree construction also fails and asks the author to choose one canonical
display label. The topic page therefore never depends on filesystem iteration
order to select its heading.

## Generated Sitepress resources

`Writing::TopicPage` is a generated Sitepress page source. It reuses one
physical Markerb template for rendering behavior while supplying per-topic
data: the topic label, topic slug, page title, and `topic` layout name.

The existing `Writing::ResourcePipeline` separates validation from mutation.
It performs a complete preflight against every discovered post and draft in
every environment, then mutates the tree only after that preflight succeeds:

1. Discover every physical writing resource and validate its topic array.
2. Build an all-resource topic registry and validate global display-label
   consistency, slug uniqueness, and collisions with the untouched Sitepress
   tree.
3. Validate the existing canonical post targets and every planned topic target.
4. Stop without changing the tree if any validation fails.
5. Perform existing draft removal/preview preparation and canonical post moves.
6. Select topics from the resources that remain in the current environment.
7. Add one HTML resource below `/writing/topics/<slug>` for each selected topic.

Generated resources use `source:` and native `Sitepress::Page` behavior. The
application does not introduce `asset:` compatibility calls or mount the public
cover directory into the Sitepress tree.

Validation always includes drafts, including in production, so conflicting or
malformed content cannot pass in one environment and fail in another.
Draft-only topics are not generated in production because production drafts
are removed during the later mutation phase. Topics belonging to scheduled
posts are generated so they can become available on the publication day
without an application restart.

## Draft scaffolding

`./go write` continues to ask for the draft title and adds one required prompt
for a comma-separated list of topics. The command trims the input, rejects an
empty list, blank members, and case-insensitive duplicates, then serializes the
values as YAML-safe strings in a canonical array under `topic`.

Comma separation is only a command-line input convenience. Sitepress ingestion
accepts YAML arrays exclusively. If topic input is invalid or cannot be read,
the command exits without creating or partially writing a draft. The physical
template also contains an obvious valid example array for authors who create a
file without the command.

## Publication behavior

`Writing::Catalogue#published` accepts an optional topic and continues to apply
`Writing::PublicationPolicy` before filtering by that topic. Topic matching uses
the validated topic identity rather than substring or comma parsing.

The controller's topic layout requests the matching published collection at
render time. When the collection is empty, it raises the normal Sitepress
resource-not-found error. Consequently:

- drafts never appear in topic archives;
- scheduled posts do not appear before their Brussels publication day;
- a scheduled-only topic route returns 404 until its first post is due;
- the page becomes available on its publication day without rebuilding the
  cached resource tree.

Article URLs, canonical post remapping, archive ordering, and exclusion of the
current article remain unchanged.

## Presentation

A small shared Phlex component renders a list of `Writing::Topic` values as
links separated by the existing middle-dot treatment. It is used in:

- collection feature and row metadata;
- article-header metadata;
- the article facts rail.

The topic archive uses the standard application layout, archive page kind, and
the existing compact writing rows. Its heading is `Writing about <label>` and
its entries remain in descending publication order. No new visual system or
topic-cloud interface is introduced.

Links use `/writing/topics/<slug>` directly from the topic value object, so
display capitalization never affects routing.

## Error behavior

Invalid topic metadata raises `Writing::ResourcePipeline::Invalid` during the
existing boot validation pass. Messages include the physical source path and
the failing topic or slug. The preflight covers all resources and every planned
canonical or topic target before any Sitepress resource is moved, removed,
replaced, or generated, preserving the pipeline's atomic failure behavior.

Generation also fails before mutation when a topic route collides with an
existing resource or when two different topic labels resolve to the same slug.

## Testing

### Topic value tests

Cover label retention, stable slug generation, equality, frozen values, and
rejection of blank labels or empty slugs.

### Pipeline tests

Cover strict YAML-array validation, blank and padded members, within-article
duplicates, inconsistent capitalization, slug collisions, existing-resource
collisions, generated source types/data, production draft exclusion, and
scheduled-topic generation. Failure tests assert that the resource tree remains
unchanged.

### Catalogue tests

Cover filtering by topic, publication-first behavior, descending order, and
the existing exclusion option.

### Presentation and integration tests

Verify topic links in collection rows and article metadata, successful topic
archive routing, heading and canonical URL, matching-post membership, ordering,
404 behavior for an archive with no due posts, and exclusion of drafts,
scheduled posts, and posts from other topics.

### Content migration and scaffold tests

Assert that every writing resource uses the singular `topic` key with a YAML
Cover topic prompting, trimming, YAML-safe serialization, empty or duplicate
input, failed reads, and atomic cleanup.

## Verification

Run focused tests during every red-green-refactor cycle, followed by:

```bash
bin/rails test
bundle exec standardrb
bin/rails runner 'puts "booted"'
```

Inspect the built Sitepress tree to confirm that every generated topic resource
uses `Writing::TopicPage` as its native source and resolves at its canonical
request path.

## Non-goals

- Adding a Rails topics controller or conventional topic routes.
- Creating topic descriptions, indexes, clouds, counts, feeds, or pagination.
- Changing article URLs or publication dates.
- Moving cover images into the Sitepress source tree.
- Completing the broader typed-writing-frontmatter migration.
- Accepting legacy comma-separated topic strings.
