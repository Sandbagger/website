# Typed Writing Frontmatter Design

## Goal

Create a typed writing domain boundary around Sitepress resources. Every file
directly under `app/content/pages/writing/drafts/` or
`app/content/pages/writing/posts/` must have valid, closed-schema frontmatter.
After ingestion, the writing pipeline, catalogue, publication policy,
controllers, feed, and components work with `Writing::Article` objects instead
of reading frontmatter through `resource.data`.

Invalid writing frontmatter must stop application boot in every environment
before the Sitepress resource tree is mutated.

## Content contract

Writing frontmatter permits exactly three keys:

```yaml
---
title: Example title
topic:
  - ruby
  - rails
emoji: 🦄
---
```

- `title` is required and must be a nonblank `String` without leading or
  trailing whitespace.
- `topic` is required and must be a non-empty YAML array.
- Every `topic` member must be a nonblank `String` without leading or trailing
  whitespace.
- Topics retain their authored capitalization.
- Topics must be unique when compared case-insensitively.
- `emoji` is optional. When present, it must be a nonblank `String` without
  leading or trailing whitespace.
- Unknown keys are rejected. There is no compatibility path for `date`,
  `topics`, `status`, `published`, `publish_at`, comma-separated topics, or
  arbitrary extensions.

Publication state and date remain properties of the physical path. A draft is
under `writing/drafts/`; a post is under `writing/posts/` and begins with an ISO
publication date. Frontmatter cannot override those facts.

## Domain types

### `Writing::Frontmatter`

`Writing::Frontmatter` is an immutable `Literal::Data` value object with these
properties:

- `title`: constrained nonblank `String`
- `topics`: constrained non-empty array of unique, nonblank strings
- `emoji`: nilable constrained nonblank `String`

The source key remains `topic`, while the domain reader is pluralized to
`topics` because it always contains an array.

`Writing::Frontmatter.from(data, source_path:)` accepts Sitepress's
`Sitepress::Data::Record` interface, checks the exact key set, extracts values,
and constructs the typed object. A YAML array is exposed by Sitepress as a
`Sitepress::Data::Collection`; the factory copies that collection into a plain
Ruby array before construction. It does not mutate or freeze Sitepress-owned
values and does not silently trim, split, downcase, or otherwise normalize
authored values.

Because `Literal::Data` freezes its receiver but not nested values, the factory
copies and freezes `title`, every topic string, the topics array, and `emoji`
before construction. Frontmatter equality and hashes therefore cannot change
after ingestion even if Sitepress retains mutable source data.

Missing keys, unknown keys, and Literal type failures are translated into one
frontmatter-specific error containing the source path and failing property.
The original `Literal::TypeError` remains available as the exception cause
when applicable.

### `Writing::Article`

`Writing::Article` is a frozen `Literal::Object` domain projection with these
typed properties:

- `path`: `Writing::Path`
- `frontmatter`: `Writing::Frontmatter`

`Writing::Article.from(resource)` parses the resource's physical asset path and
frontmatter and returns a fully valid article. The Sitepress resource is an
ingestion input, not retained state. This makes the article independent of the
resource's mutable node, format, and handler while keeping Sitepress at the
application boundary.

The facade exposes this intentional API:

- `title`
- `topics`
- `emoji`
- `publication_date`
- `draft?`
- `post?`
- `request_path`
- `url`

`request_path` and `url` both come from `Writing::Path#request_path`, so their
values are stable before and after Sitepress canonical remapping. The remaining
methods delegate explicitly to `frontmatter` or `path`. There is no
`method_missing`, `SimpleDelegator`, retained Sitepress resource, or public
`data` escape hatch.

The article object freezes itself after initialization, and `Writing::Path`
also freezes after successful parsing. `Writing::Article` deliberately keeps
normal object-identity equality and hashing rather than pretending that a
domain projection containing collaborator objects is a structural value.
Structural equality and stable hashes are guaranteed only for the deeply
immutable `Writing::Frontmatter` value object.

## Pipeline data flow

`Writing::ResourcePipeline#process` performs work in this order:

1. Discover resources physically located below the configured writing root.
2. Construct a `Writing::Article` for every discovered resource.
3. Stop immediately on invalid paths or frontmatter. No resource has been
   removed, moved, replaced, or amended at this point.
4. Validate slug uniqueness and canonical request-path collisions across the
   valid articles.
5. Remove production drafts, prepare development/test draft previews, and move
   posts to canonical Sitepress nodes.

`ResourcePipeline::Entry` retains the mutable `Sitepress::Resource` required for
tree operations alongside the typed `article` and pipeline-only `target`.
Separate `path` storage becomes unnecessary because it is available through
the article. The existing `Target` value object remains responsible for
canonical Sitepress node lookup and materialization.

The old legacy-key validation is removed because the closed frontmatter schema
rejects those keys along with every other unknown key.

The pipeline no longer writes `resource.data["publish_at"]`. Publication dates
are exposed by `Article#publication_date`, derived from `Writing::Path`.

## Application integration

### Catalogue and publication policy

`Writing::Catalogue` converts candidate Sitepress resources with
`Writing::Article.from`. Non-writing resources remain outside the catalogue.
Its private `Entry` tuple becomes unnecessary and is removed. `#published`
returns `Writing::Article` instances newest first and applies exclusions using
`article.request_path`.

`Writing::PublicationPolicy` receives articles rather than paths. It determines
draft, post, due, and accessibility state through the article's explicit API.

### Controllers and presentation

The Sitepress controller constructs an article when the current page is a
writing resource. It uses article readers for title, topics, publication date,
cover lookup, and publication access. Non-writing pages continue through their
existing Sitepress layout paths.

`CollectionComponent` accepts article collections. It renders titles, topics,
dates, paths, URLs, and cover images through article methods and never accesses
`resource.data`.

`ApplicationLayout#page_metadata` accepts `topics:` as an array and joins it for
display. It no longer parses comma-separated strings.

The feed receives article objects and renders `title`, `publication_date`, and
`url` directly. Writing presentation code must not access frontmatter through
`resource.data` after this change.

Helpers that need only `request_path` may continue using that small interface;
they do not need to depend on the entire article class.

## Draft scaffolding

`./go write` continues to prompt for a title, then prompts once for a
comma-separated topic list. The command:

- trims the title before validating, deriving the slug, and writing it;
- rejects an empty title after trimming;
- splits the prompt on commas;
- trims each token;
- rejects blank tokens and an empty list;
- rejects case-insensitive duplicates;
- serializes the title and every topic as quoted, YAML-safe scalars;
- writes the topics as a canonical YAML array under `topic`;
- retains its existing atomic creation, collision detection, permissions, and
  no-overwrite behavior.

Comma-separated input is a CLI convenience only. Hand-authored frontmatter and
Sitepress ingestion accept YAML arrays exclusively.

The writing template is updated to match the canonical array structure used by
the command.

## Existing content migration

Every current draft and post moves from comma-separated `topic` strings to YAML
arrays. The draft containing `date` and `topics` drops `date`, renames `topics`
to `topic`, and uses an array. Optional `emoji` values remain unchanged.

This migration lands atomically with the validator so the application remains
bootable at every completed commit.

## Error behavior

Frontmatter errors use one domain exception type and include the physical
source path. Messages identify the offending key or property and the expected
contract, for example:

```text
Invalid writing frontmatter in ".../drafts/example.markerb":
topic[1] expected a nonblank String, got nil
```

Errors are raised in development, test, and production. Drafts do not receive a
validation exemption. Validation happens before all pipeline mutation, so a
failed boot cannot leave a partially remapped in-memory resource tree.

When a record contains multiple problems, validation reports the first problem
in this deterministic order: sorted unknown keys; missing `title`; missing
`topic`; invalid `title`; invalid topic container; invalid topic members by
index; duplicate topics; invalid `emoji`. This keeps errors predictable without
adding an aggregate-error protocol.

## Testing

### Frontmatter unit tests

Cover:

- valid construction and readers;
- value equality, matching hashes, and frozen instances;
- omitted and present emoji;
- missing title or topic;
- blank or whitespace-padded strings;
- scalar and empty topic values;
- invalid topic members;
- case-insensitive duplicate topics;
- unknown and legacy keys;
- file-specific error messages and preserved Literal causes.

### Article unit tests

Cover explicit readers, draft/post predicates, publication dates, stable request
paths and URLs across resource remapping, identity equality, and a frozen
article wrapper. Confirm that the Sitepress resource is not retained and that
invalid paths and frontmatter cannot produce an article.

### Pipeline tests

Update ordinary writing fixtures to contain valid frontmatter. Add malformed
frontmatter cases in every environment and assert that the complete Sitepress
tree snapshot is unchanged after failure. Preserve existing path, collision,
draft-preview, and canonical-node coverage while asserting through articles
where appropriate.

### Catalogue and policy tests

Assert that the catalogue returns articles, ordering and exclusion still work,
scheduled posts remain unpublished, and draft/production access rules are
unchanged.

### Presentation and integration tests

Update component, controller, layout, feed, boot-validation, and publication
integration tests to use YAML topic arrays and article APIs. Verify topic arrays
render with the existing separator and the feed's public output is unchanged.

### Scaffold tests

Extend the shell tests for the topic prompt, canonical YAML-array output, blank
tokens, duplicates, failed reads, atomic cleanup, collisions, and preserved file
permissions.

## Verification

Run focused tests during each red-green-refactor cycle, followed by:

```bash
bin/rails test
bundle exec standardrb
bin/rails runner 'puts "booted"'
rg -n 'resource\.data|page\.data' app/controllers app/views app/models/writing lib/writing
```

The final search may still find non-writing page metadata access. It must not
find writing title, topic, emoji, or publication-date access that bypasses
`Writing::Article`.

## Non-goals

- Converting all Sitepress pages to typed objects.
- Persisting articles or frontmatter in Active Record.
- Replacing Sitepress resources or the current filesystem publication model.
- Adding compatibility for old frontmatter forms.
- Introducing generic delegation from articles to Sitepress resources.
- Converting Phlex components, service objects, or test doubles to
  `Literal::Data` without a separate value-object reason.
- Adopting Literal enums, flags, checked collections, or Result types as part of
  this change.
