# Sitepress 5 Native Sources and Covers

## Goal

Remove the application's Sitepress 4 compatibility usage and adopt Sitepress
5 source types for writing resources and post-cover metadata. Convert every
canonical SVG post cover to WebP, remove the SVG compatibility paths, and
render intrinsic image dimensions wherever a cover appears.

## Scope

This change will:

- Replace every application and test use of `Sitepress::Resource#asset` with
  `Sitepress::Resource#source`.
- Replace test construction through `Sitepress::Asset` with the appropriate
  Sitepress 5 source type, normally `Sitepress::Page`.
- Remove `Writing::ResourcePipeline::DraftPreviewResource`, whose
  `renderable?` override duplicates Sitepress 5's base resource behavior.
- Construct remapped preview resources with `source:` rather than the legacy
  `asset:` keyword.
- Convert the seven canonical post-cover SVGs to 1200-by-630 WebP images.
- Delete all eleven SVG cover files, including four obsolete `.html.svg`
  duplicates.
- Remove the SVG cover generator, its Rake task, and its tests.
- Add a cover abstraction backed by `Sitepress::Image` and render its width
  and height in article and featured-writing image markup.

This change will not:

- Move covers into the Sitepress pages tree or Propshaft.
- Add multiple cover formats, responsive variants, or an SVG fallback.
- Require every writing resource to have a cover.
- Add a replacement image generator, permanent conversion tool, or build step.
- Change publication paths, ordering, metadata, or draft visibility.

## Sitepress 5 Source Boundary

Writing code will treat `Sitepress::Resource#source` as the sole source-file
interface. A writing resource is expected to carry a `Sitepress::Page`, which
provides the file path, parsed frontmatter, body, and persistence behavior.

`Writing::ResourcePipeline`, `Writing::Catalogue`, and the Sitepress
controller will derive `Writing::Path` values from `resource.source.path`.
Collision diagnostics and integration assertions will use the same API. Test
factories will create `Sitepress::Page` objects and pass them into resources
with `source:`.

The draft-preview remapping will use an ordinary `Sitepress::Resource`.
Sitepress 5 already defines `renderable?` as the presence of a handler, so the
application-specific subclass is redundant. The remapped resource retains the
original page source and explicitly sets its HTML format, Markerb handler, and
HTML MIME type.

After migration, application and test code must contain no references to
`Sitepress::Asset`, `resource.asset`, or the `asset:` resource initializer
keyword. Rails' unrelated `asset_path` helper remains valid.

## Cover Model

`Writing::Cover` will own cover discovery and metadata. Given a writing
resource, it derives the slug from the resource request path and looks only
for:

```
public/images/posts/<slug>.webp
```

When the file does not exist, lookup returns `nil`; a missing cover is a valid
text-only presentation. When the file exists, `Writing::Cover` verifies the
file content is WebP, constructs a `Sitepress::Image`, reads its intrinsic
width and height, and exposes:

- `src`: the public `/images/posts/<slug>.webp` URL.
- `width`: the positive intrinsic pixel width.
- `height`: the positive intrinsic pixel height.

Content format detection must inspect the file rather than trusting its
extension. A PNG, JPEG, GIF, or other file renamed to `.webp` is invalid. If
the file is not WebP or Sitepress cannot read positive dimensions, lookup
raises a cover-specific error that names the source path. There is no SVG,
alternate-extension, or dimensionless fallback. This makes broken generated
media fail during tests or page rendering rather than silently degrading.

`PostCoverHelper` will expose the cover lookup to controllers and components.
It will return the cover object instead of a string path. The Sitepress
controller passes that object to `ApplicationLayout`; `CollectionComponent`
uses the same object for the featured article.

## Rendering

`ApplicationLayout#cover_image` accepts a `Writing::Cover`. Article cover
markup uses the cover's `src`, `width`, and `height`, preserving the current
decorative empty alternative text and CSS classes.

The homepage feature uses the same three attributes. Supplying intrinsic
dimensions lets the browser reserve the cover's 1200-by-630 aspect ratio
before the image loads without changing the visual layout.

Articles without covers continue to use the existing text-only layout and CSS
modifier classes.

## Asset Conversion

The seven canonical SVGs will be rendered at their existing 1200-by-630
viewBox through a browser-capable SVG renderer so text and web-compatible SVG
features are preserved. The rendered pixels will be encoded as lossless WebP.
Each generated image will be checked for:

- WebP format.
- Lossless WebP encoding as reported by a bitstream-aware WebP inspector.
- Exactly 1200-by-630 pixels.
- Successful `Sitepress::Image` dimension extraction.
- Visual equivalence to its SVG source before the source is deleted.

Canonical output names omit the obsolete `.html` suffix. The four duplicate
`.html.svg` files and all seven canonical SVG inputs will be removed only
after their WebP replacements have been verified.

The conversion is a one-time repository migration. The existing
`PostImageGenerator`, `images:generate_posts` Rake task, and generator tests
will be deleted because they can only recreate the removed SVG format. No
replacement generator, conversion script, or runtime dependency will be
added. Future covers are supplied directly as validated WebP files.

## Error Handling

- Missing WebP: return `nil` and render the existing text-only presentation.
- Existing file with non-WebP content: raise `Writing::Cover::Invalid` with
  the file path.
- Existing WebP with unreadable or non-positive dimensions: raise
  `Writing::Cover::Invalid` with the file path.
- Non-page writing resource entering the writing pipeline: raise
  `Writing::ResourcePipeline::Invalid` with the source path and source class.
- Duplicate canonical writing paths and invalid publication metadata retain
  their existing errors, now expressed through `source.path`.

## Testing

Implementation follows test-driven red-green-refactor cycles.

Focused tests will cover:

- Finding a WebP cover with `src`, width, and height.
- Returning `nil` when no WebP exists.
- Rejecting readable non-WebP content stored with a `.webp` extension.
- Raising for a present image whose dimensions cannot be read.
- Article layout markup containing `src`, `width`, and `height`.
- Featured-writing markup containing the same intrinsic dimensions.
- Text-only behavior when a cover is absent.
- Draft preview remapping through `source:` and an ordinary
  `Sitepress::Resource`.
- Rejection of a non-`Sitepress::Page` writing source.
- The absence of legacy Sitepress asset APIs in application and test code.

Verification will include focused cover and resource-pipeline tests, the full
Rails test suite, system tests, StandardRB, `git diff --check`, and inspection
of every generated WebP through both the operating-system image tools and
`Sitepress::Image`. A bitstream-aware WebP inspector will also verify that
each output uses lossless encoding rather than relying on its extension or
visual appearance.

## Acceptance Criteria

- All seven canonical covers are lossless 1200-by-630 WebP files.
- No post-cover SVG remains in `public/images/posts`.
- The obsolete SVG generator, Rake task, and generator tests are removed.
- Every rendered cover includes correct `width` and `height` attributes.
- Missing covers remain valid and render text-only layouts.
- Existing files that are not genuine, dimensioned WebP images fail loudly.
- Application and test code contain no Sitepress asset compatibility API
  references.
- The custom draft-preview resource subclass is removed.
- Publication routing, filtering, and ordering remain unchanged.
- Focused, full, system, and style verification passes.
