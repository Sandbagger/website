# Responsive Post Cover Variants

## Goal

Serve appropriately sized post-cover images through `srcset` and `sizes`
without weakening the strict `Writing::Cover` boundary introduced for
Sitepress 5. Keep responsive covers deterministic by committing every variant
as a lossless WebP rather than generating images at request or deploy time.

## Scope

This change will:

- Replace each canonical unsuffixed 1200-by-630 cover with three consistently
  width-suffixed lossless WebP files.
- Extend `Writing::Cover` to discover and validate the complete variant set.
- Represent variant metadata immutably and derive a `srcset` from it.
- Render context-specific `sizes` attributes for the homepage feature and
  article cover.
- Preserve fallback `src`, intrinsic `width` and `height`, decorative empty
  alternative text, current CSS classes, crop behavior, and text-only layouts.

This change will not:

- Add runtime or deployment-time image generation.
- Add an image-processing gem, service, controller, route, or cache.
- Add JPEG, PNG, AVIF, SVG, or lossy WebP alternatives.
- Make covers mandatory for writing resources.
- Generalize the work into a site-wide responsive-image component.
- Change cover art, publication metadata, routes, or writing selection.

## Asset Contract

Each covered writing slug has exactly these public assets:

```text
public/images/posts/<slug>-480w.webp
public/images/posts/<slug>-768w.webp
public/images/posts/<slug>-1200w.webp
```

The expected dimensions are:

| Candidate | Width | Height |
| --- | ---: | ---: |
| `480w` | 480 | 252 |
| `768w` | 768 | 403 |
| `1200w` | 1200 | 630 |

The 768-pixel height rounds the source's 40:21 ratio to the nearest whole
pixel. Every file must contain a genuine VP8L lossless WebP bitstream. The
current unsuffixed `<slug>.webp` files are removed; there is no compatibility
lookup or redirect for those URLs.

The variants are created once from the current verified 1200-by-630 lossless
masters and committed. Image conversion is an implementation operation, not
a permanent application workflow. The repository retains no generator, Rake
task, runtime dependency, or deployment hook.

## Cover Model

`Writing::Cover` remains the only cover discovery and validation boundary.
Given a writing resource, it derives the slug from `request_path` and checks
the three exact width-suffixed paths.

The cover exposes immutable metadata:

- `variants`: the ordered 480w, 768w, and 1200w candidates, each with a public
  `src`, intrinsic `width`, and intrinsic `height`.
- `src`: the 1200w candidate URL used as the ordinary image fallback.
- `srcset`: the three candidate URLs paired with their width descriptors.
- `width`: 1200, the fallback candidate's intrinsic width.
- `height`: 630, the fallback candidate's intrinsic height.

Variant ordering is ascending by width, making `srcset` deterministic. The
model owns URLs, dimensions, and candidate selection data; it does not own the
layout-dependent `sizes` hint.

Validation must inspect content instead of trusting file extensions. For each
candidate, `Writing::Cover` verifies:

- The path exists as a regular file.
- `FastImage` recognizes WebP content.
- The WebP RIFF payload uses the lossless `VP8L` chunk.
- `Sitepress::Image` reports the exact expected width and height.

The variant collection and its nested strings are owned and frozen so a
caller cannot mutate cover identity or hash behavior after construction.

## Missing and Invalid Covers

A writing resource without any of the three candidate files has no cover.
`Writing::Cover.find` returns `nil`, and the existing text-only presentation
continues unchanged.

Once any candidate exists, the cover is expected to be complete. A partial
set raises `Writing::Cover::Invalid`; it must never silently fall back to one
large image. The same error is raised if a candidate has the wrong format,
uses a lossy WebP bitstream, has unreadable dimensions, or has dimensions that
do not match its filename. Error messages identify the invalid or missing
path so repository mistakes are actionable.

## Rendering

Both rendering contexts use the cover's 1200w fallback `src`, complete
`srcset`, and fallback intrinsic `width="1200"` and `height="630"`. Keeping
intrinsic dimensions reserves layout space before the selected candidate
loads. Current `object-fit` rules continue to control the different visual
crops.

The homepage feature supplies this layout hint:

```text
(max-width: 48rem) calc(100vw - clamp(2.2rem, 8vw, 6rem)), min(60vw, 47rem)
```

It models the full-width mobile feature and the wider column of the desktop
homepage grid, capped near its maximum rendered width.

The article cover supplies this layout hint:

```text
(max-width: 48rem) min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), 22rem
```

It models the mobile cover's existing 36rem cap and the narrower desktop
article-header column. Browser device-pixel ratio and viewport width determine
which of the three candidates is fetched.

Articles without any cover candidates retain their existing text-only CSS
modifier classes and render no image attributes. Partial sets are invalid and
raise before rendering.

## Testing

Implementation follows test-driven red-green-refactor cycles.

Model tests will cover:

- Returning the three ordered immutable variants for a canonical cover.
- Deriving the exact fallback `src`, `srcset`, width, and height.
- Returning `nil` when all three candidates are absent.
- Raising for each partial-set shape.
- Rejecting non-WebP content with a `.webp` suffix.
- Rejecting a lossy WebP candidate.
- Rejecting unreadable or unexpected dimensions.
- Preventing mutation of nested variant URLs and the variant collection.

Repository asset tests will assert that:

- Exactly 21 width-suffixed files exist for the seven canonical covers.
- No unsuffixed cover, SVG, or alternate image format remains.
- Every candidate has the dimensions declared by its suffix.
- Every candidate is a genuine lossless VP8L WebP readable by
  `Sitepress::Image`.

View, component, and integration tests will assert exact `src`, `srcset`,
`sizes`, `width`, `height`, and empty `alt` attributes for article and homepage
covers. Existing missing-cover tests continue to prove text-only behavior.

Verification will run focused model/rendering/integration tests, the full
serial Rails suite, system tests, StandardRB, `bundle check`, and
`git diff --check`. `webpinfo` will independently inspect all 21 committed
files for VP8L lossless encoding, expected dimensions, and bitstream errors.

## Acceptance Criteria

- Every canonical cover has exactly 480w, 768w, and 1200w lossless WebP
  candidates with expected dimensions.
- No unsuffixed post cover or previous image-format fallback remains.
- A complete cover returns immutable variants and deterministic fallback and
  `srcset` metadata.
- A wholly absent cover remains valid and renders text-only.
- A partial or invalid variant set fails loudly with a path-specific error.
- Homepage and article images render correct context-specific `sizes` values.
- Both images retain fallback intrinsic dimensions and decorative empty alt
  text.
- No image generator or runtime/deployment image-processing dependency is
  introduced.
- Focused, full, system, style, dependency, diff, and binary checks pass.
