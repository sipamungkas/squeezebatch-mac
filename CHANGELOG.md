# Changelog

Entries here become the GitHub Release body: on release day, rename
`## [Unreleased]` to `## [<version>]` (must equal
`CFBundleShortVersionString` in `project.yml`). The release workflow
extracts that section and publishes it on top of GitHub's
auto-generated What's Changed list.

## [0.2.0]

### Added

- Automatic update check against GitHub Releases, with a
  "Download / Skip / Later" alert, a `Check for Updates…` menu item
  (Shift-Cmd-U), and update status in the About window.

### Changed

- Release `.dmg` now shows the app next to an `Applications` alias,
  so it installs with a drag and drop.

## [0.1.0]

First public release.

### Added

- Bulk image conversion (PNG · JPEG · WebP · HEIC · TIFF · BMP · GIF)
  with quality, resize, and destination controls.
- Per-image crop editor with aspect presets and exact-size mode.
- About window with the current version.
