# ImageManager

<!-- TODO: replace YOUR_GITHUB_USERNAME with your GitHub username/org once pushed,
     then the badge below will track the build workflow in .github/workflows/build.yml -->
![Build](https://github.com/YOUR_GITHUB_USERNAME/image-manager/actions/workflows/build.yml/badge.svg)
![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)
![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS_14%2B-lightgrey.svg)

A native macOS app for bulk image conversion and compression. Drag & drop
images (or whole folders) to convert between PNG, JPEG, WebP, HEIC, TIFF
and BMP — with lossless or lossy compression, resizing, and live savings stats.

## Features

- **Drag & drop** files and folders (folders are expanded recursively)
- **Bulk convert** with a concurrent queue, per-file status, and total savings
- **Output formats:** PNG · JPEG · WebP · HEIC · TIFF · BMP
- **Compression:** lossless toggle (PNG/WebP/TIFF/BMP) + quality slider
  (JPEG/HEIC/WebP lossy)
- **Resize:** none, max dimension, or scale percentage
- **Destination:** same folder as source or a custom folder, with overwrite
  protection (`name-2.ext` auto-numbering)
- **Metadata:** EXIF orientation/camera info preserved where the format
  supports it

> **Why libwebp?** ImageIO on macOS can *decode* WebP but cannot *encode* it,
> so WebP output goes through Google's `libwebp` (via
> [SDWebImage/libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode),
> BSD-3-Clause). Everything else uses native ImageIO.

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 16+
- [Homebrew](https://brew.sh/) (for `xcodegen`)
- `xcodegen` — the `.xcodeproj` is generated, never edited by hand

## Quick start

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/image-manager.git
cd image-manager
brew install xcodegen
xcodegen generate
open ImageManager.xcodeproj   # press ⌘R to run
```

## Build from terminal

```bash
# 1. Prerequisites
xcode-select -p                        # must point to /Applications/Xcode.app/Contents/Developer
brew install xcodegen                   # only once

# 2. Generate the Xcode project
xcodegen generate

# 3. Fetch SwiftPM deps (libwebp for WebP encode)
xcodebuild -resolvePackageDependencies \
  -project ImageManager.xcodeproj -scheme ImageManager

# 4. Build (Debug)
xcodebuild -project ImageManager.xcodeproj \
  -scheme ImageManager -configuration Debug build

# 5. Run the built app
open ~/Library/Developer/Xcode/DerivedData/ImageManager-*/Build/Products/Debug/ImageManager.app
```

Release build and archive:

```bash
xcodebuild -project ImageManager.xcodeproj \
  -scheme ImageManager -configuration Release build

xcodebuild -project ImageManager.xcodeproj \
  -scheme ImageManager -configuration Release archive \
  -archivePath ./build/ImageManager.xcarchive
```

Clean rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ImageManager-*
xcodegen generate
xcodebuild -project ImageManager.xcodeproj \
  -scheme ImageManager -configuration Debug build
```

Every push/PR is also built on GitHub Actions
(see [.github/workflows/build.yml](.github/workflows/build.yml)).

## Usage

1. Drop images onto the window (or **Add images…** / **Add folder…**).
2. Pick format, quality/lossless, resize, and destination in the sidebar.
3. Hit **Convert all** — sizes and savings % appear inline per file.
4. Right-click a converted row → **Show in Finder**.

## Project layout

```
project.yml                  # xcodegen spec — source of truth for the Xcode project
ImageManager/
  ImageManagerApp.swift      # App entry point
  Models/
    ConversionSettings.swift # OutputFormat, quality, resize, destination
    ImageItem.swift          # Per-file state (thumbnail, status, sizes)
  Services/
    ImageConverter.swift     # ImageIO convert path + output naming
    WebPCodec.swift          # libwebp encode wrapper (WebP output)
    ImageStore.swift         # Observable queue, bulk conversion
  Views/
    ContentView.swift        # Split view, drop target, list, footer
    SettingsView.swift       # Sidebar controls
    ImageRowView.swift       # File row with status + savings
.github/workflows/build.yml # CI: xcodegen → resolve → build Debug + Release
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and PRs are welcome —
please run a Debug build before submitting.

## License

Copyright (c) 2026 Ragil Burhanudin Pamungkas.

All third party components are licensed under their original licenses.
Everything else is available under the **GNU Affero General Public License
v3.0 or later** — see [LICENSE](LICENSE) for the full text.
