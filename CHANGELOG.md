# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
- Image file bytes are now read in the background isolate and cached in memory, significantly improving UI performance and responsiveness.
- Switched from `Image.file` to the `cached_memory_image` package for image previews to implement a more robust in-memory caching strategy, improving scrolling performance.
- File metadata (like modification time) is now fetched asynchronously when the directory is scanned, rather than synchronously within the build method.
- Restored the categorized, row-based layout for media files while ensuring performant lazy-loading of horizontal lists.
