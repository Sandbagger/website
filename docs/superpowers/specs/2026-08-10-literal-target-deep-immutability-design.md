# Literal Target Deep Immutability Design

## Goal

Make `Writing::ResourcePipeline::Target` a genuinely immutable structural value
by protecting its `node_names` array and every string inside it from caller
mutation. Preserve its constructor, readers, type checks, equality, hashing,
and pipeline behavior.

## Property seal

Change the existing property declaration to use Literal's built-in
`DeepImmutable` seal:

```ruby
prop :node_names, _Array(String), &DeepImmutable
```

`Immutable` is insufficient because it only freezes a copied outer array; its
string members would remain mutable. `DeepImmutable` copies a mutable object
graph and makes the stored array and strings Ractor-shareable and frozen. It
does not mutate caller-owned inputs. Literal may retain an input that is already
deeply immutable and shareable.

The seal applies through both ordinary initialization and Literal's
`from_props` final-value constructor. Literal applies the seal before checking
the declared `_Array(String)` type and assigning the property.

## Behavioral contract

For a mutable caller-owned node-name array:

- appending, removing, or replacing elements after target construction cannot
  change `target.node_names`;
- mutating a caller-owned string after construction cannot change the
  corresponding stored node name;
- the stored array and all stored strings are frozen;
- the target's structural equality and hash remain stable after caller
  mutation;
- the caller's array and strings remain mutable and unfrozen.

The same guarantees apply when constructing a target with `from_props`.

Valid `_Array(String)` values are always compatible with `DeepImmutable`.
Invalid values that the seal can copy, including the currently tested integer
member, continue through the declared type check and raise `Literal::TypeError`.
Because Literal runs seals before type checks, an invalid graph containing an
unshareable object such as a `Proc` or `Thread` may instead raise Ruby's
seal-stage `TypeError` or `Ractor::IsolationError`. Do not add duplicate
prevalidation, translate those errors, or replace the built-in seal merely to
preserve an exception guarantee for invalid internal input.

The `format` property, constructor signature, readers, target
lookup/materialization methods, and callers remain unchanged.

## Scope

This change is limited to `Writing::ResourcePipeline::Target#node_names` and
its focused tests. It does not:

- add seals to any other property;
- change `Writing::Path` or Sitepress path handling;
- replace the plain array with a Literal typed collection;
- introduce coercion or normalization;
- begin the separate typed-frontmatter and article project.

## Tests and verification

Extend `Writing::ResourcePipelineTest` with behavioral tests for ordinary and
`from_props` construction. Each test supplies mutable node-name strings and a
mutable array, constructs a target, mutates the caller's graph, and verifies
stored content, deep frozen state, caller mutability, object separation, and
stable hashing.

Retain the existing invalid-member and invalid-format tests as regression
coverage for type errors. Run the focused resource-pipeline tests first, then
the complete Minitest suite, Standard Ruby, a Rails boot check, Bundler's
dependency check, and a clean-diff check.
