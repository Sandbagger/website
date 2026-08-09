# Literal Property Seals Design

## Goal

Adopt Literal's unreleased property-seal support for the writing value objects
that currently copy and freeze property values in `after_initialize`. Preserve
their public constructors, validation errors, equality, hashing, and ordinary
initialization behavior while making immutability apply consistently to every
Literal construction path.

## Dependency

The published Literal 1.9.0 release does not contain property seals. Change the
existing Literal dependency from the RubyGems release to the exact current
main-branch commit `e51ef7c3e6a03127977acc06071a020b497be24e`. Retain the
`~> 1.9.0` version requirement because that commit still declares version
1.9.0, and record the Git source and revision in `Gemfile.lock`.

Pin an exact revision rather than tracking the moving `main` branch so local,
CI, and production installs resolve identical code. The Docker build stage
already installs Git before `bundle install`, so the Git-backed dependency does
not require an image change.

## Property seals

Use Literal's built-in `Immutable` seal on these properties:

- `Writing::Topic#label`
- `Writing::ResourcePipeline::Entry#topics`
- `Writing::Catalogue::Entry#topics`
- `Writing::Cover::Variant#src`
- `Writing::Cover#variants`

`Immutable` makes a shallow frozen copy of a mutable value without freezing the
caller's object. If the caller supplies an already frozen value, Literal may
retain it. Shallow immutability matches the current behavior: the sealed arrays
contain `Writing::Topic` or `Writing::Cover::Variant` instances that are
themselves immutable, and the sealed scalar values are strings.

Do not use `DeepImmutable`. These object graphs do not need Ractor
shareability, and a deep-copying seal would expand the change beyond the
existing ownership contract.

## Hooks and validation

Remove `after_initialize` entirely from:

- `Writing::ResourcePipeline::Entry`
- `Writing::Catalogue::Entry`
- `Writing::Cover::Variant`

Those hooks only perform the copy-and-freeze operation replaced by the seal.

Keep `Writing::Topic#after_initialize` and `Writing::Cover#after_initialize`,
but remove their instance-variable reassignment. They continue to enforce the
existing topic-label and responsive-dimension invariants with the same
exception classes and messages. Literal applies the seal before assigning the
property and then invokes the validation hook.

Do not change constructor signatures, property types, readers, derived methods,
or surrounding service objects.

## Construction paths

Ordinary constructors must retain their existing behavior:

- a mutable input string or array remains mutable;
- mutating the caller's input after construction cannot change the value
  object;
- stored strings and arrays are frozen;
- invalid property types still raise `Literal::TypeError`;
- topic and cover domain validation still raises the existing domain errors.

Additionally, immutability must now hold when objects are constructed with
Literal's final-value `from_props` API. That API deliberately bypasses
`initialize` and `after_initialize`, but seals still apply. This is the
behavioral reason to move the ownership rule into the property declarations.

## Scope

This change only migrates the five existing defensive-copy assignments. It
does not add seals to properties that currently lack explicit defensive-copy
behavior, adopt coercions or `DeepImmutable`, convert additional classes to
Literal, or use other unreleased Literal features.

## Tests and verification

Extend the focused value-object tests to construct representative string and
array properties through `from_props`. Assert that each stored value is frozen,
does not share a mutable caller-owned container or string, and cannot be
changed by later caller mutation. Preserve the existing ordinary-construction
tests as regression coverage for caller ownership and validation.

Run the focused topic, resource-pipeline, catalogue, and cover tests first.
Then run the complete Minitest suite, Standard Ruby, a Rails boot check, and
Bundler's dependency check. Confirm the lockfile resolves Literal from the
pinned Git revision and that no migrated class still assigns its sealed
property in `after_initialize`.
