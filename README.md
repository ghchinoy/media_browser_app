# Media Browser

A fast, sandboxed desktop media and asset browser built with Flutter for macOS and Linux.

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-v3.29%2B-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

![Media Browser Screenshot](https://github.com/ghchinoy/media_browser_app/releases/download/v1.0.0-assets/media_browser.png)

Originally designed to streamline reviewing generated media from the [Gemini CLI](https://github.com/google-gemini/gemini-cli), Claude Desktop, and [MCP Tools for GenMedia](https://goo.gle/vertex-genmedia-mcp).

---

## Table of Contents

- [Quickstart](#quickstart)
- [Key Features](#key-features)
- [Supported Formats](#supported-formats)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [macOS Integration & Sandboxing](#macos-integration--sandboxing)
- [Development & Testing](#development--testing)
- [Performance Architecture](#performance-architecture)
- [Contributing](#contributing)
- [License](#license)

---

## Quickstart

### Run with Flutter

Clone the repository and launch the app on macOS or Linux:

```bash
git clone https://github.com/ghchinoy/media_browser_app.git
cd media_browser_app
flutter pub get
flutter run -d macos
```

### Build Release App

```bash
# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

The macOS application bundle will be created at `build/macos/Build/Products/Release/Media Browser.app`.

---

## Key Features

- **Multi-Layout View Modes:**
  - **Categories View (`Cmd+1`):** Traditional grouped horizontal carousels by MIME type.
  - **Grid View (`Cmd+2`):** Responsive desktop card grid with thumbnail previews and file badges.
  - **List View (`Cmd+3`):** Compact details list showing filenames, formatted file sizes, file types, and modification timestamps.
- **Real-Time Search & Category Chips:**
  - Instant live search bar (`Cmd+F`) matching file names and extensions.
  - Fast category filter chips: `All`, `Images`, `Videos`, `Audio`, `Documents`, `Code & Text`, and `Other`.
- **Sorting Options:**
  - Sort by Date Modified (Newest/Oldest), Name (A–Z / Z–A), File Size (Largest/Smallest), or File Type.
- **Interactive Lightbox Viewer:**
  - Full-screen / modal media dialog with previous (`←`) and next (`→`) carousel navigation.
  - Interactive zoomable image viewer.
  - Video player with play/pause, seek slider, and full-screen controls.
  - Audio player with timeline slider, elapsed/total time, and playback controls.
  - Markdown renderer and multi-language syntax highlighter (Dart, Python, Rust, Swift, C/C++, JavaScript, JSON, YAML).
  - Quick action toolbar: **Reveal in Finder** (`open -R`), **Open with Default App** (`open`), and **Copy File Path**.
  - Collapsible metadata inspector.
- **Live Directory Watching:**
  - Automatically updates file lists and the sidebar hierarchy when files are added, modified, or deleted on disk.
- **Collapsible Directory Sidenav:**
  - Hierarchical folder navigation tree with subfolder drilldown and filter scoping.
- **Adaptive Theme:**
  - Follows macOS/system light and dark appearance with one-click manual toggle.

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

| Shortcut | Action |
|---|---|
| <kbd>Cmd</kbd> + <kbd>O</kbd> / <kbd>Ctrl</kbd> + <kbd>O</kbd> | Open directory picker |
| <kbd>Cmd</kbd> + <kbd>F</kbd> / <kbd>Ctrl</kbd> + <kbd>F</kbd> | Focus real-time search bar |
| <kbd>Cmd</kbd> + <kbd>R</kbd> / <kbd>Ctrl</kbd> + <kbd>R</kbd> | Refresh current directory |
| <kbd>Cmd</kbd> + <kbd>1</kbd> | Switch to **Categories** view |
| <kbd>Cmd</kbd> + <kbd>2</kbd> | Switch to **Grid** view |
| <kbd>Cmd</kbd> + <kbd>3</kbd> | Switch to **List** view |
| <kbd>←</kbd> / <kbd>→</kbd> *(in Lightbox)* | Navigate to previous / next media file |
| <kbd>Esc</kbd> *(in Lightbox)* | Close viewer dialog |

---

## macOS Integration & Sandboxing

The application runs inside the macOS App Sandbox (`com.apple.security.files.user-selected.read-write`).

To open a specific directory on launch:

1. **Drag and Drop:** Drag any folder from Finder directly onto the `Media Browser.app` Dock or application icon.
2. **Command Line:** Use macOS `open` with user-granted directory scope:

```bash
# Open app with a specific folder
open -a "/Applications/Media Browser.app" ~/Pictures
```

> [!NOTE]
> Passing directory paths via command-line arguments (e.g. `--args /path`) is restricted by the macOS sandbox. Use `open -a` or the in-app picker to ensure proper sandbox access.

---

## Development & Testing

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.29.0` or compatible)
- macOS Xcode developer tools (for macOS builds)
- Linux build prerequisites (for Linux builds):
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

# Run macOS debug build
flutter build macos --debug
```

For developer architecture guides, see [`DEVELOPERS.md`](DEVELOPERS.md).

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