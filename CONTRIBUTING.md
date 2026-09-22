# Contributing to SqueezeBatch

Thanks for wanting to contribute! This guide covers the development setup
and the ground rules for pull requests.

## How can I contribute?

- [Report a bug](../../issues/new) — include macOS/Xcode versions, input
  format, output settings, and the error text from the failed row.
- Suggest a feature via a GitHub issue.
- Submit a PR for a bug fix or a small, focused feature.

## Development requirements

- macOS 14+
- Xcode 16+
- Homebrew + `xcodegen` (`brew install xcodegen`)

## Setup

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/squeezebatch-mac.git
cd squeezebatch-mac
xcodegen generate
open SqueezeBatch.xcodeproj
```

Then press **⌘R** in Xcode, or build from the terminal (see README.md).

> **Important:** `SqueezeBatch.xcodeproj` is generated from `project.yml`.
> Never edit the `.xcodeproj` by hand — change `project.yml` and re-run
> `xcodegen generate`. The generated project is git-ignored on purpose.

## Project conventions

- **SwiftUI + AppKit where needed.** Thumbnails and panels live in
  `SqueezeBatch/Views`, conversion logic in `SqueezeBatch/Services`.
- **Keep it native.** Prefer ImageIO / CoreGraphics over new dependencies.
  WebP encoding is the one exception (`libwebp` via SwiftPM) because
  ImageIO can't encode WebP.
- **Keep it concise.** Short functions, no decorative comments, no emojis
  in UI strings.
- **Verify before you claim.** If you fix a bug or add a format path, prove
  it: build Debug *and* convert a real file (PNG → your format), then paste
  the before/after sizes and `file` output in the PR.

## Pull requests

1. Fork, branch from `main` (`feat/...`, `fix/...`).
2. Keep PRs small and focused — one feature/fix per PR.
3. Make sure `xcodebuild ... -configuration Debug build` passes locally;
   CI ([build.yml](.github/workflows/build.yml)) builds Debug + Release.
4. Describe what changed, why, and how you verified it.

## License

By contributing, you agree that your contributions will be licensed under
the GNU Affero General Public License v3.0 or later (see [LICENSE](LICENSE)).
