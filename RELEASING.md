# Releasing SqueezeBatch

Pushing a version tag (`v*`) triggers
[.github/workflows/release.yml](.github/workflows/release.yml):
build Release → package `.zip` + `.dmg` → publish a GitHub Release.
This mirrors the TablePro flow, minus paid signing/notarization
(the app is ad-hoc signed; users first-launch via right-click → Open).

## Normal release

```bash
# 1. Bump the version (tag MUST match this exactly)
#    project.yml -> info.properties.CFBundleShortVersionString
#    e.g. 0.1.0 -> 0.2.0

# 2. Commit the bump on main
git add project.yml
git commit -m "Release v0.2.0"
git push origin main

# 3. Tag and push the tag (this starts the release build)
git tag v0.2.0
git push origin v0.2.0

# 4. Watch it: GitHub repo -> Actions -> "Release"
#    Result: GitHub repo -> Releases -> v0.2.0
#    with SqueezeBatch-0.2.0-macOS.zip + SqueezeBatch-0.2.0-macOS.dmg
```

One-liner for steps 2–3 (after the version bump is committed):

```bash
git push origin main && git tag v0.2.0 && git push origin v0.2.0
```

## Rules

- Tag format is `v<version>`, e.g. `v0.2.0`. The `v` prefix is required;
  the workflow strips it (`v0.2.0` → `0.2.0`).
- Tag must equal `CFBundleShortVersionString` in `project.yml`.
  `v0.2.0` with `project.yml` still at `0.1.0` fails the build on purpose.
- Tags containing `-beta`, `-alpha`, or `-rc` (e.g. `v0.3.0-beta.1`)
  publish as a **prerelease**. Everything else publishes as a full release.
- Each tag run is fenced by `concurrency: release-<ref>` with
  `cancel-in-progress: false`, so re-pushing a tag queues behind the
  run in flight instead of racing it.

## Fixing a bad tag

If you tagged the wrong commit or version, delete and re-push:

```bash
# delete locally + remotely
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0

# fix, re-commit, re-tag, re-push
git tag v0.2.0
git push origin v0.2.0
```

If a Release was already published, delete it first
(Releases page → delete) or publish a new patch version instead —
re-cutting the same version hides what testers already downloaded.

## Testing without publishing

`release.yml` also has `workflow_dispatch`: run it by hand from
Actions → Release → Run workflow. A manual run builds and uploads the
`.zip`/`.dmg` as workflow **artifacts** (90-day retention) but does
**not** create a GitHub Release — only tag pushes do that.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `tag vX does not match CFBundleShortVersionString` | Bump `project.yml` to the tagged version, commit, delete + re-push the tag |
| Release has no files | `Package .zip and .dmg` step failed — open that step's log in Actions |
| Downloaded app won't open | Expected: ad-hoc signed. Right-click → Open → Open (once per machine) |
| Accidentally pushed tag from a feature branch | Tags build whatever commit they point at — move the tag to `main` (see above) |
