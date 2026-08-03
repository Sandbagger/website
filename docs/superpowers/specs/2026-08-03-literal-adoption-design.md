# Literal Adoption Design

## Goal

Install the `literal` gem and introduce it where the application already uses
small immutable production value objects. Preserve existing behavior and public
call sites while adding runtime checks at those value-object boundaries.

## Dependency

Add `literal` as a runtime dependency constrained with `~> 1.9.0` to the
compatible 1.9.x series. Bundler will resolve and lock the exact version.

## Initial adoption

Replace these anonymous `Data.define` classes with named subclasses of
`Literal::Data`:

- `Writing::Catalogue::Entry`
- `Writing::ResourcePipeline::Target`
- `Writing::ResourcePipeline::Entry`

Use these property schemas:

- `Catalogue::Entry`: `resource` is `Sitepress::Resource`; `path` is
  `Writing::Path`.
- `ResourcePipeline::Target`: `node_names` is `_Array(String)`; `format` is
  `Symbol`.
- `ResourcePipeline::Entry`: `resource` is `Sitepress::Resource`; `path` is
  `Writing::Path`; `target` is `_Nilable(Target)` because drafts do not have a
  canonical target.

Literal treats nilable properties as optional. Define an explicit keyword
initializer on `ResourcePipeline::Entry` that still requires `target:` and
delegates assignment and validation to `Literal::Data`. This preserves the
existing `Data.define` constructor contract. Existing readers remain unchanged.

Do not convert service objects such as `Writing::Catalogue`,
`Writing::PublicationPolicy`, `Writing::Path`, or `Writing::ResourcePipeline`.
Their initializers perform coercion, parsing, dependency injection, or other
behavior beyond carrying immutable data. Do not convert test-only `Data` or
`Struct` doubles because doing so would couple test fixtures to the production
typing dependency without improving a production boundary.

## Loading

Rely on Bundler and Rails application boot to load the gem. The nested classes
remain in their current files so Zeitwerk ownership and the surrounding public
constant names do not change.

## Errors and compatibility

Literal will reject incorrectly typed properties at construction time. The
migration guarantees compatibility only for the APIs used here: keyword
construction, property readers, same-class `==`/`eql?`/`hash`, and frozen
instances. `Literal::Data` inspection, subclass equality, and the Ruby `Data`
APIs `.members` and `#with` are not compatibility guarantees. No rescue or
coercion layer will be added; a type mismatch represents a programming error.

## Tests and verification

Add focused unit coverage for keyword construction, readers, same-class `==`,
`eql?`, `hash`, frozen instances, the required `target:` keyword, and
`Literal::TypeError` for invalid values. Run the focused tests first, then the
complete test suite and the repository's formatter/linter. Confirm the Rails
application boots with the new dependency.

## Further candidates

After the initial conversion, report other potential uses separately. Favor
stable value objects and constrained domain values. Avoid recommending Literal
for Active Record models, framework resources, view components, or service
objects unless a future change exposes a concrete type-safety benefit.
