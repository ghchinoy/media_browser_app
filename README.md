# Media Browser

A fast, cross-platform desktop media and asset browser built with Flutter for macOS, Windows, and Linux.

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-v3.29%2B-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey.svg)]()
[![Release](https://github.com/ghchinoy/media_browser_app/actions/workflows/release.yml/badge.svg)](https://github.com/ghchinoy/media_browser_app/actions/workflows/release.yml)

![Media Browser Screenshot](https://github.com/ghchinoy/media_browser_app/releases/download/v1.0.0-assets/media_browser.png)

Originally designed to streamline reviewing generated media from the [Gemini CLI](https://github.com/google-gemini/gemini-cli), Claude Desktop, and [MCP Tools for GenMedia](https://goo.gle/vertex-genmedia-mcp).

---

## Table of Contents

- [Quickstart](#quickstart)
- [Key Features](#key-features)
- [Supported Formats](#supported-formats)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Platform Integration & Sandboxing](#platform-integration--sandboxing)
- [Development & Testing](#development--testing)
- [Automated Releases](#automated-releases)
- [Performance Architecture](#performance-architecture)
- [Contributing](#contributing)
- [License](#license)

---

## Quickstart

### Quick Commands (Makefile)

```bash
make help           # View all available make targets
make run            # Run app on macOS in debug mode
make build          # Build release macOS .app bundle
make install        # Install release app to /Applications/Media Browser.app
make test           # Run all unit and widget tests
make clean          # Clean build artifacts and caches
```

### Run with Flutter

Clone the repository and launch the app:

```bash
git clone https://github.com/ghchinoy/media_browser_app.git
cd media_browser_app
flutter pub get

# Launch on macOS, Windows, or Linux
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```

### Build Release App

```bash
# macOS (builds .app bundle in build/macos/Build/Products/Release/)
flutter build macos --release

# Windows (builds executable in build/windows/x64/runner/Release/)
flutter build windows --release

# Linux (builds bundle in build/linux/x64/release/bundle/)
flutter build linux --release
```

---

## Key Features

- **Multi-Layout View Modes:**
  - **Categories View (`Cmd+1` / `Ctrl+1`):** Grouped horizontal carousels by MIME type.
  - **Grid View (`Cmd+2` / `Ctrl+2`):** Responsive desktop card grid with thumbnail previews and file badges.
  - **List View (`Cmd+3` / `Ctrl+3`):** Compact details list showing filenames, formatted file sizes, file types, and modification timestamps.
- **Real-Time Search & Category Chips:**
  - Instant live search bar (`Cmd+F` / `Ctrl+F`) matching file names and extensions.
  - Fast category filter chips: `All`, `Images`, `Videos`, `Audio`, `Documents`, `Code & Text`, and `Other`.
- **Sorting Options:**
  - Sort by Date Modified (Newest/Oldest), Name (A–Z / Z–A), File Size (Largest/Smallest), or File Type.
- **Interactive Lightbox Viewer:**
  - Full-screen / modal media dialog with previous (`←`) and next (`→`) carousel navigation.
  - Interactive zoomable image viewer.
  - Video player with play/pause, seek slider, and full-screen controls.
  - Audio player with timeline slider, elapsed/total time, and playback controls.
  - Markdown renderer and multi-language syntax highlighter (Dart, Python, Rust, Swift, C/C++, JavaScript, JSON, YAML).
  - Quick action toolbar: **Reveal in File Explorer / Finder**, **Open with Default App**, and **Copy File Path**.
  - Collapsible metadata inspector.
- **Live Directory Watching:**
  - Automatically updates file lists and the sidebar hierarchy when files are added, modified, or deleted on disk.
- **Collapsible Directory Sidenav:**
  - Hierarchical folder navigation tree with subfolder drilldown and filter scoping.
- **Adaptive Theme:**
  - Follows system light and dark appearance with one-click manual toggle.

---

## Supported Formats

| Category | Extensions | Viewer Capabilities |
|---|---|---|
| **Images** | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.svg`, `.ico` | GPU-accelerated thumbnails, interactive zoom/pan |
| **Videos** | `.mp4`, `.mov`, `.avi`, `.mkv`, `.webm`, `.m4v` | Cached video frame thumbnails, in-app video player with scrubbing |
| **Audio** | `.mp3`, `.wav`, `.aac`, `.m4a`, `.flac`, `.ogg` | Audio player with waveform controls and time scrubber |
| **Documents** | `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.csv` | Document badges and file inspection |
| **Code & Text** | `.md`, `.json`, `.yaml`, `.yml`, `.dart`, `.py`, `.rs`, `.swift`, `.js`, `.ts`, `.cpp`, `.c`, `.h`, `.sql`, `.toml`, `.xml`, `.log`, `.txt` | Rich Markdown rendering & syntax-highlighted code viewer |

---

## Keyboard Shortcuts

| Shortcut (macOS / Windows & Linux) | Action |
|---|---|
| <kbd>Cmd</kbd> + <kbd>O</kbd> / <kbd>Ctrl</kbd> + <kbd>O</kbd> | Open directory picker |
| <kbd>Cmd</kbd> + <kbd>F</kbd> / <kbd>Ctrl</kbd> + <kbd>F</kbd> | Focus real-time search bar |
| <kbd>Cmd</kbd> + <kbd>R</kbd> / <kbd>Ctrl</kbd> + <kbd>R</kbd> | Refresh current directory |
| <kbd>Cmd</kbd> + <kbd>1</kbd> / <kbd>Ctrl</kbd> + <kbd>1</kbd> | Switch to **Categories** view |
| <kbd>Cmd</kbd> + <kbd>2</kbd> / <kbd>Ctrl</kbd> + <kbd>2</kbd> | Switch to **Grid** view |
| <kbd>Cmd</kbd> + <kbd>3</kbd> / <kbd>Ctrl</kbd> + <kbd>3</kbd> | Switch to **List** view |
| <kbd>←</kbd> / <kbd>→</kbd> *(in Lightbox)* | Navigate to previous / next media file |
| <kbd>Esc</kbd> *(in Lightbox)* | Close viewer dialog |

---

## Platform Integration & Sandboxing

### macOS
The app is sandboxed (`com.apple.security.files.user-selected.read-write`). To launch with a specific folder:
- **Drag & Drop:** Drag any folder from Finder onto the app icon.
- **CLI:** `open -a "/Applications/Media Browser.app" ~/Pictures`

### Windows & Linux
- **Drag & Drop:** Drag folders directly into the app window.
- **In-App Picker:** Click "Open Folder" (`Ctrl+O`) to select any accessible directory.

---

## Development & Testing

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.29.0` or compatible)
- **macOS:** Xcode developer tools
- **Windows:** Visual Studio 2022 with "Desktop development with C++"
- **Linux:** System development packages:
  ```bash
  sudo apt-get update && sudo apt-get install -y \
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
      libasound2-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev zenity
  ```

### Quality Gates

Run analyzer and tests:

```bash
# Analyze codebase
flutter analyze

# Run all unit and widget tests
flutter test

# Run debug build
flutter build macos --debug    # macOS
flutter build windows --debug  # Windows
flutter build linux --debug    # Linux
```

For developer architecture guides, see [`DEVELOPERS.md`](DEVELOPERS.md).

---

## Automated Releases

Releases are automated via GitHub Actions ([`.github/workflows/release.yml`](.github/workflows/release.yml)).

Whenever a version tag is pushed:

```bash
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

The CI pipeline automatically builds and publishes release binaries for all three platforms:
- 🍎 `Media-Browser-macOS.zip`
- 🪟 `Media-Browser-Windows-x64.zip`
- 🐧 `Media-Browser-Linux-x64.tar.gz`

---

## Performance Architecture

- **Low-Memory Asset Streaming:** Uses lightweight metadata objects instead of eagerly reading whole byte arrays into Dart memory. Thumbnails are decoded directly on the GPU layer via `cacheWidth` and `cacheHeight`.
- **LRU Video Thumbnail Cache:** Caches generated video frame thumbnails in memory with automatic eviction.
- **Background Isolate Scanning:** Directory traversal and stat fetching run in a background isolate via `compute()` to prevent main UI thread stutters.
- **Directory Stream Watching:** Efficient `DirectoryWatcher` streams trigger incremental refreshes on file system events.

---

## Contributing

Contributions, bug reports, and feature suggestions are welcome!

1. Fork the repository and create your feature branch: `git checkout -b feature/my-feature`.
2. Ensure all quality gates pass: `flutter analyze && flutter test`.
3. Commit your changes and open a Pull Request.

Please see [`DEVELOPERS.md`](DEVELOPERS.md) for architecture details and [`AGENTS.md`](AGENTS.md) for agent guidelines.

---

## License

Apache 2.0; see [`LICENSE`](LICENSE) for details.

### Disclaimer
This project is not an official Google project. It is not supported by Google and Google specifically disclaims all warranties as to its quality, merchantability, or fitness for a particular purpose.