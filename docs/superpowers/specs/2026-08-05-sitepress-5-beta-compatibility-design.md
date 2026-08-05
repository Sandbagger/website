# Sitepress 5 Beta Compatibility Upgrade

## Goal

Upgrade the Rails site from Sitepress 4.1.1 to the published `sitepress-rails`
`5.0.0.beta4` release without changing the site's behavior or adopting the new
Sitepress 5 source and mounting architecture.

## Scope

The upgrade will:

- Pin `sitepress-rails` exactly to `5.0.0.beta4` so future prereleases or the
  final 5.0 release are not adopted implicitly.
- Resolve and record the beta's transitive dependencies in `Gemfile.lock`.
- Replace the removed `collection glob:` PageModel declaration with Sitepress
  5's supported `def self.all = glob(...)` form.
- Preserve the custom Sitepress controller, writing resource pipeline,
  canonical post paths, draft handling, publication policy, feed behavior and
  current single-site routing.
- Make further compatibility changes only when a failing existing test or Rails
  boot check demonstrates that one is required.

The upgrade will not:

- Register multiple Sitepress sites.
- Refactor resources from the backwards-compatible `asset` API to `source`.
- Replace `Writing::ResourcePipeline` with Sitepress 5 directories, mounts or
  custom sources.
- Adopt the standalone Falcon development server or new static compilation
  tasks.
- Change page content, URLs, layouts, publication rules or deployment behavior.

## Compatibility Approach

`Gemfile` will use an exact beta version rather than a pessimistic prerelease
range. This keeps production and development resolution deterministic while the
dependency is unstable.

The existing application integration remains the compatibility boundary.
Sitepress 5 retains `Resource#asset` and the `Sitepress::Asset` alias for
backwards compatibility, so the custom pipeline will continue using those APIs
unless verification exposes a concrete incompatibility. The PageModel
collection declaration is the one known source change because the beta removes
the old keyword-based collection syntax.

## Failure Handling

The dependency will be updated before application compatibility edits so Rails
boot and focused tests can expose real migration failures. Each failure will be
investigated to its upstream API change, then addressed with the smallest local
change that restores existing behavior. Unrelated warnings, refactors and beta
feature adoption remain outside the migration.

If the beta cannot preserve the current controller, resource pipeline or
publication behavior without a substantial redesign, the migration will stop
and the trade-off will be brought back for approval instead of expanding scope.

## Testing

The existing behavior suite is the migration contract. Verification will cover:

- Rails application boot and the resolved Sitepress gem versions.
- PageModel collection loading with the supported Sitepress 5 API.
- Writing resource mapping, draft previews, canonical URLs and collision
  validation.
- Publication access, archives, feeds and page rendering.
- The complete Rails test suite and system test suite.
- StandardRB, `bundle check`, lockfile inspection and `git diff --check`.

Dependency and lockfile edits are configuration changes, so no artificial
version assertion will be added solely to make a pre-upgrade test fail. New
behavior tests will be added only if investigation finds a compatibility
requirement not already covered by the existing suite.

## Success Criteria

- `sitepress-rails` and `sitepress-core` resolve to the versions required by
  `5.0.0.beta4`.
- The application boots without Sitepress deprecation or removed-API errors.
- Existing public paths, draft visibility, publication filtering, feeds and
  rendered pages behave unchanged.
- Focused, full and system tests pass.
- Formatting and dependency checks pass.
- Only files required for the compatibility upgrade are changed; unrelated
  worktree changes remain untouched.
