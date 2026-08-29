# Developer's Guide: Media Browser

## 1. Introduction for Developers

### Purpose of the Guide

Welcome to the Media Browser project! This guide is designed to onboard developers, explain the project's architecture, and outline the patterns used across the app.

---

## 2. High-Level Architecture

The application separates concerns cleanly between file system operations/models and UI presentation:

- **`MediaService` ([`lib/media_service.dart`](lib/media_service.dart)):** Core business logic for scanning folders, parsing MIME types and file extensions into [`MediaCategory`](lib/media_service.dart), sorting with [`SortOption`](lib/media_service.dart), building the [`DirectoryNode`](lib/media_service.dart) tree, and listening to file system change events via `DirectoryWatcher`.
- **`MediaHomePage` ([`lib/main.dart`](lib/main.dart)):** Main desktop UI with search controller, category filter chips, sort options, view mode switcher (`Categories`, `Grid`, `List`), folder sidebar, and desktop keyboard shortcuts (`Cmd+O`, `Cmd+F`, `Cmd+R`, `Cmd+1/2/3`).
- **`MediaDetailDialog` ([`lib/media_detail_dialog.dart`](lib/media_detail_dialog.dart)):** Full-featured media Lightbox viewer. Manages image zoom/pan, video/audio playback lifecycles, markdown rendering, syntax highlighting for code/JSON/YAML, previous/next carousel navigation, and system quick actions ("Reveal in Finder", "Open in Default App", "Copy Path").

---

## 3. Performance & Memory Model

Handling directories with thousands of high-resolution images and videos requires strict memory management:

### 1. Lazy GPU Image Decoding
Instead of reading full raw image byte arrays into Dart heap memory (which causes OOM crashes on large media folders), `MediaFile` stores only file references and lightweight stats. Images are decoded directly at target display resolution on the GPU layer using Flutter's native `cacheWidth` and `cacheHeight` properties:

```dart
Image.file(
  file,
  width: width,
  height: height,
  fit: BoxFit.cover,
  cacheWidth: (width * 2).toInt(),
  cacheHeight: (height * 2).toInt(),
)
```

### 2. Video Thumbnail LRU Caching
Video frame extraction via native platform channels is expensive. [`VideoThumbnailCache`](lib/media_service.dart) caches thumbnail byte buffers in an in-memory LRU map with a 200-entry capacity limit and async deduplication.

### 3. Background Isolate Scanning
Directory scanning and recursive stat gathering execute off the UI thread via Flutter's `compute(loadAllMediaData, path)`. The UI remains 60fps responsive even during heavy directory traversal.

---

## 4. UI Components & Layouts

### View Modes (`ViewLayoutMode`)
The main viewport supports three user-selectable layouts:
1. **Category Carousels (`ViewLayoutMode.category`):** Vertical list of horizontal carousels grouped by MIME type.
2. **Responsive Grid (`ViewLayoutMode.grid`):** Auto-fitting multi-column grid (`SliverGridDelegateWithFixedCrossAxisCount`) displaying aspect-ratio thumbnail cards.
3. **Detail List (`ViewLayoutMode.list`):** Compact table list with file type badges, names, formatted sizes, and timestamps.

### Real-Time Filter Pipeline
Files are filtered reactively through three stages:
1. **Directory Scope:** Match against `_activeFilterPath`.
2. **Category Selection:** Match against `_selectedCategory` (`Images`, `Videos`, `Audio`, `Documents`, `Code & Text`, `Other`).
3. **Query Search:** Case-insensitive match on file name or extension.
4. **Sort Order:** Sorted by `_selectedSort` (`Name`, `Date Modified`, `Size`, `Type`).

---

## 5. Media Detail Lightbox (`MediaDetailDialog`)

### Carousel Navigation
The dialog accepts a `fileList` and `initialIndex`. Users can browse through the active filtered list sequentially using on-screen buttons or desktop arrow keys (<kbd>←</kbd> / <kbd>→</kbd>).

### Native Desktop Actions
- **Reveal in Finder:** Invokes `Process.run('open', ['-R', file.path])` on macOS.
- **Open in Default App:** Invokes `Process.run('open', [file.path])` on macOS / `xdg-open` on Linux.
- **Copy File Path:** Uses `Clipboard.setData(ClipboardData(text: file.path))`.

### Media Playback Lifecycle
Controllers for `VideoPlayerController` and `AudioPlayer` are initialized in `initState()` / `_initActiveFile()` and properly disposed in `dispose()` to prevent memory leaks and unreleased audio handles.

---

## 6. Testing & Quality Gates

Run the test suite and analyzer:

```bash
flutter analyze
flutter test
flutter build macos --debug
```
