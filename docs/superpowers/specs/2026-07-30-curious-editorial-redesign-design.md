# Curious Editorial Site Redesign

## Context

William Neal’s site is a small Rails 8, Phlex, Sitepress, and Markdown publication with a CUBE CSS-inspired cascade:

1. Global styles establish tokens and element defaults.
2. Compositions provide low-specificity layout primitives.
3. Utilities apply focused overrides.
4. Blocks style named interface regions.

The redesign must retain this architecture while making the site more distinctive, easier to scan, and more useful for attracting professional opportunities. The positioning should remain exploratory rather than claim expertise William is still developing.

The visual direction combines:

- The Creative Independent’s curious, authorial personality and small moments of surprise.
- Works in Progress’ editorial hierarchy and structured presentation of ideas.
- Dense Discovery’s warm, humane, independent-publication feel.

The result should be inspired by those qualities without reproducing any one reference site.

## Goal

Create a warm editorial identity for a software engineer and emerging practitioner-writer whose interests span agentic workflows, smaller language models, European technology, political economy, and macroeconomics.

The site should communicate breadth and thoughtfulness quietly. It should foreground published work and developing interests without presenting William as an established authority on every topic.

## Success Criteria

- The CUBE cascade remains explicit and ordered as global → compositions → utilities → blocks.
- The homepage identifies William, communicates his developing interests, and gives selected writing clear hierarchy.
- Article pages feel related to the homepage but become calmer and narrower for long-form reading.
- The layout works from small phones through wide desktop screens without horizontal overflow.
- Existing posts continue to render without new mandatory frontmatter.
- Missing dates, topics, or generated covers degrade gracefully.
- Navigation and document structure use valid, accessible HTML.
- No remote font, JavaScript interaction, CMS, filtering, search, or newsletter system is introduced.

## Visual Direction

### Palette

- Paper: `#f2eadb` for the site canvas.
- Deep paper: `#e7dcc8` for quiet inset surfaces such as blockquotes.
- Ink: `#172c35` for text and structural rules.
- Coral: `#d95136` for links, active states, markers, and small graphic accents.
- Blush: `#e8a7a0` for labels and offset cover shadows.

Color should be used sparingly. Ink and paper carry most of the interface; coral and blush identify hierarchy and personality.

### Typography

- Display headings: a system serif stack beginning with `ui-serif` and falling back to Georgia.
- Body copy: a system sans-serif stack beginning with `ui-sans-serif`.
- Navigation, dates, topics, and small labels: the existing local Space Mono face.

This avoids a new network dependency while creating a clear editorial hierarchy. Article body copy uses a comfortable line height and a maximum measure of roughly 68 characters.

### Graphic Language

- Strong ink-colored rules divide the major regions.
- Small coral section markers and a single star-like glyph provide personality.
- Blush labels may be rotated by approximately one degree to feel made rather than machine-perfect.
- Generated post covers receive a simple ink border and, on article pages, a small blush offset shadow.
- Decoration remains subordinate to content and is removed or flattened where necessary on narrow screens.

## Information Architecture

The primary navigation contains:

- Home
- Writing
- About
- Elsewhere

“Elsewhere” groups or exposes the existing Mastodon and Bluesky links. RSS remains available in the footer. External destinations retain appropriate `target` and `rel` attributes.

The shared page shell contains a semantic header, navigation, main region, and footer inside the document body.

## Homepage

The homepage is a professional personal index, not a high-volume magazine front page.

### Introduction

The approved direction uses:

- Eyebrow: “From Brussels, with questions”
- Heading: “Thinking in systems.”
- Introduction: “I’m William, a software engineer writing about building software, political economy, and the questions that sit between them.”

The tone is clear but provisional. It does not claim specialist status in agentic AI or European technology policy.

### Currently Exploring

The label is “Currently exploring,” replacing the more literary “Current preoccupations.”

The initial list is:

- Agentic workflows
- Smaller language models
- European technology
- Macroeconomic imbalances

These are interests, not article links or claims of expertise. The list can be edited directly in the homepage content without changing application code.

### Selected Writing

The latest published resource is visually featured using its existing generated cover when available. It shows:

- Title
- Topic when present
- Publication date when present

It does not automatically extract an excerpt from Markdown and does not require a new summary field.

The next published resources appear as compact rows with the same available metadata. A link leads to the complete Writing archive.

If the latest resource has no cover, the feature becomes a text-led article with the same border and spacing treatment. If no published resources exist, the section renders a quiet empty state instead of failing.

## Writing Archive

The Writing page uses the same structured article-row treatment as the homepage without artificially featuring every item. Resources remain sorted by publication date in descending order.

Each item renders only metadata already available in frontmatter. A missing topic or date is omitted cleanly rather than replaced with placeholder text.

## Article Pages

### Header

The article header contains:

- Available topic and publication date metadata.
- A large serif title.
- Existing leading copy supplied by the article itself.
- The generated cover when present.

The application does not generate or duplicate a lede from arbitrary Markdown. Existing content flows directly into the article body.

### Reading Layout

Wide screens use a small facts rail beside a reading column. The facts rail repeats only existing topic and publication metadata. It disappears on narrow screens, where the article becomes a single column.

The prose treatment includes:

- A maximum measure of approximately 68 characters.
- Serif section headings with small coral section markers.
- Deep-paper blockquotes with a coral inset rule.
- Distinct but restrained inline code and code-block treatments.
- Responsive images that never exceed the reading column.

The current “Latest” collection after an article becomes a compact “More writing” section. It continues to exclude the current article.

No generated table of contents, reading-time estimator, footnote system, or margin-note authoring syntax is added.

## About Page

The About page receives the same narrow prose treatment. Its copy should mention William’s background in international relations as context for his interdisciplinary interests, not as a homepage credential.

The copy should communicate:

- William is a software engineer based in Brussels.
- He has a master’s degree in international relations.
- He is exploring practical agentic systems and smaller language models.
- He is developing writing around political economy, macroeconomics, and European technology.

The tone remains candid about this being a developing direction.

## CUBE CSS Architecture

### Global

`global/variables.css` defines color, type, spacing, measure, border, and gutter tokens. `global/reset.css` retains normalization but does not impose page-level body padding. `global/styles.css` owns base body, heading, link, list, image, code, and blockquote behavior.

### Compositions

The redesign reuses the current `center`, `cluster`, `flow`, and `stack` primitives. `center` becomes configurable through custom properties so it can provide both the wide site frame and narrow reading measures.

Unique homepage and article grids remain inside their block styles. No generic composition is added for a layout with only one consumer.

### Utilities

Utilities remain few and purpose-specific:

- `active` for current navigation state.
- `lede` for intentionally enlarged introductory copy.
- `prose` for long-form flow and measure.
- `sr-only` for accessible hidden text.

### Blocks

Named blocks cover:

- Site header and primary navigation.
- Homepage hero.
- Currently exploring list.
- Selected-writing collection, feature, and article rows.
- Article header, facts rail, cover, and “More writing” section.
- Site footer.

Block classes must not depend on long utility-class chains. Component markup should carry only the composition, utility, and block hooks it needs.

### Import Order

`application.css` retains the load-bearing order:

1. Global
2. Compositions
3. Utilities
4. Blocks

The current duplicate import of `compositions/flow.css` is removed.

## Phlex and Content Changes

### Application Layout

`ApplicationLayout` renders the body before shared site chrome. The header/navigation, main content, and footer all live inside `<body>`. The current inline `.cover` style moves into the block stylesheet.

The layout continues to accept page title, cover, Markdown, and partial content from the Sitepress controller. It adds page-context classes or attributes only where required for styling.

### Navigation

`NavComponent` renders a semantic header and navigation list. Headings are not children of unordered lists, and lists are not nested without list-item parents. Existing current-page behavior remains visible and programmatically determinable.

### Collection

`CollectionComponent` receives an explicit presentation context:

- Homepage: one featured resource followed by compact rows.
- Writing archive: compact rows for all published resources.
- Article page: compact “More writing” rows excluding the current resource.

It remains responsible only for presenting an already selected collection. Publication filtering and sorting stay in the Sitepress controller.

### Content Flow

The Sitepress controller continues to:

1. Resolve the requested resource and layout.
2. Attach a generated cover only when its file exists.
3. Render Markdown through the existing handler.
4. Select published resources by `publish_at`.
5. Pass the selected resources and presentation context to `CollectionComponent`.

The homepage supplies its introduction and “Currently exploring” list through its existing content file.

## Accessibility and Semantics

- Header, navigation, main, article, aside, and footer landmarks use appropriate elements.
- The current navigation item retains a visible state and gains `aria-current="page"`.
- Decorative glyphs and generated-cover repetition use empty alternative text when the adjacent title already provides the same information.
- Focus states remain visible and use more than color alone.
- Links remain underlined in prose.
- Type remains legible when zoomed, and fluid sizes use bounded `clamp()` values.
- Motion is not required; any hover movement respects reduced-motion preferences.
- Heading levels remain sequential on the homepage, archive, About page, and article pages.

## Responsive Behavior

- The wide site frame uses fluid gutters.
- Header navigation wraps instead of overflowing.
- Homepage hero and selected-writing layouts collapse to one column below their content-driven threshold.
- Article covers lose decorative rotation on narrow screens.
- The article facts rail is hidden when there is insufficient space.
- Long titles, URLs, code, and preformatted content wrap or scroll within their own containers without widening the page.

## Verification

Implementation is complete only when:

- Existing Rails tests pass.
- Integration tests confirm valid document ordering and the shared landmarks.
- Navigation tests confirm the active link and `aria-current`.
- Collection tests cover homepage feature selection, descending order, article exclusion, and missing metadata.
- Page smoke tests still render every Sitepress HTML resource successfully.
- CSS assets resolve through Propshaft in development and test.
- Ruby changes pass StandardRB.
- The homepage, Writing archive, About page, a covered article, and an article without a cover are checked at phone and desktop widths.

## Out of Scope

- Search, filters, topic archive pages, or pagination.
- Newsletter signup.
- A contact form or dedicated opportunities call to action.
- Client-side navigation or animation.
- Remote fonts.
- Generated excerpts, reading time, table of contents, margin notes, or new required frontmatter.
- Rewriting existing articles.
- Deployment.
