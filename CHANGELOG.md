# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Saturday, August 29, 2026

#### Added
- **Multi-Layout View Modes:** Added responsive Grid view (`Cmd+2`), detail List view (`Cmd+3`), alongside classic Category Carousels (`Cmd+1`).
- **Real-Time Search & Filtering:** Added instant filename/extension search bar (`Cmd+F`) and category filter chips (`All`, `Images`, `Videos`, `Audio`, `Documents`, `Code & Text`, `Other`).
- **Sorting Support:** Added sort options by Date Modified (Newest/Oldest), Name (A-Z/Z-A), Size (Largest/Smallest), and File Type.
- **Lightbox Carousel & Quick Actions:** Added previous/next keyboard and button navigation in `MediaDetailDialog`, "Reveal in Finder" (`open -R`), "Open with Default App" (`open`), and "Copy File Path" to clipboard.
- **Syntax Highlighting & Markdown Viewer:** Upgraded Markdown rendering with `flutter_markdown_plus` and added multi-language code/data syntax viewer (`flutter_syntax_view`) for Dart, Python, Rust, Swift, JavaScript, C/C++, JSON, and YAML.
- **Desktop Keyboard Shortcuts:** Added `Cmd+O` (Open), `Cmd+F` (Search), `Cmd+R` (Refresh), `Cmd+1/2/3` (View Modes), and `←`/`→`/`Esc` in the Lightbox viewer.
- **Automated Tests:** Added test suites covering `determineCategory`, `sortMediaFiles`, sorting orders, and widget smoke/theme tests.

#### Changed
- **Memory & Performance Optimization:** Replaced eager byte reading with lightweight `MediaFile` descriptors and GPU-layer `cacheWidth`/`cacheHeight` decoding, eliminating memory bloat on large media folders.
- **Video Thumbnail Cache:** Implemented LRU in-memory cache for video thumbnails.
- **Package Updates:** Upgraded to `flutter_markdown_plus: ^1.0.12` and removed discontinued packages.

---

### Saturday, June 7, 2025

#### Fixed
- Resolved an issue where image thumbnails would appear "broken" or not update correctly. This was fixed by using the file's modification timestamp to create a unique key for the image widget, ensuring it reloads when the file changes.
- Addressed a `MissingPluginException` for video thumbnails on macOS by manually registering the `video_thumbnail` plugin in the `GeneratedPluginRegistrant.swift` file.
- Removed a non-functional, duplicate volume slider from the audio player detail view.
- Removed a confusing and non-functional volume slider from the video player detail view.
- Corrected an issue where the `audioplayers` plugin could throw a "duplicate response" error by removing a redundant `release()` call.

#### Added
- Introduced a `MediaService` class to encapsulate all file system logic, improving code organization and separating concerns.
- Implemented improved error handling to display user-friendly `SnackBar` messages for issues like invalid directory paths or file loading errors.
- Implemented skeleton loaders (`shimmer` effect) for a better loading UX when scanning a directory.
- Added a fade-in animation for image thumbnails for a smoother UI.
- Implemented click-to-play/pause functionality in the full-screen video player view.
- Added a close button to exit the full-screen video player.

#### Changed
- Refactored file and directory scanning to run in a background isolate using `compute`, preventing the UI from freezing when loading large directories.
- File metadata (like modification time) is now fetched asynchronously when the directory is scanned, rather than synchronously within the build method.
- Restored the categorized, row-based layout for media files while ensuring performant lazy-loading of horizontal lists.
