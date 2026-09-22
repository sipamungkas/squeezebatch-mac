# AGENTS.md — SqueezeBatch

## Build

- `project.yml` is the source of truth. Never edit `SqueezeBatch.xcodeproj`
  by hand — change `project.yml`, re-run `xcodegen generate`.
- CI: `.github/workflows/build.yml` (every push/PR, uploads `.app` artifact).

## Release (mandatory)

**Before doing anything release-related (version bump, tag, push tag,
workflow dispatch, "ship it", "publish a release"), read `RELEASING.md`
in full and follow it exactly.** The checklist:

1. Bump `CFBundleShortVersionString` in `project.yml`, commit on `main`.
2. Tag `v<version>` (must equal the bumped version — CI fails otherwise),
   `git push origin v...`.
3. Never invent your own release steps, never tag from a feature branch,
   never re-cut a published version — `RELEASING.md` covers the fixes.

Release workflow: `.github/workflows/release.yml` (tag `v*` → Release build →
`.zip` + `.dmg` → GitHub Release).
