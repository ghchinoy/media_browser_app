# Media Browser Application Overview

This Flutter application allows users to browse and view media files (images, videos, audio) within a selected directory and its subdirectories. It is primarily designed for macOS but is also compatible with Linux.

## Key Features

- **Recursive Directory Browsing:** Select any folder to view all media contained within it and its nested subfolders.
- **Live Updates:** The view automatically refreshes if files are added, removed, or changed in the watched directory.
- **Rich Media Previews:** Displays thumbnails for images and videos, and provides a full-featured detail view with playback controls for video/audio and an interactive zoom for images.
- **Platform-Idiomatic Integration:** On macOS, the application can be opened with a specific directory by dragging a folder onto the app icon or using the standard `open -a` command.

---

# Lessons Learned: Building and Testing on macOS

Based on an analysis of the development and troubleshooting process for this application, here are the key insights and lessons learned for future projects.

### 1. Native Integration is Key for OS-Level Features

- **Insight:** Passing data to a Flutter app from the operating system (like a file path at launch) cannot be handled by Dart code alone. It requires writing native platform code.
- **Lesson:** For macOS, this means modifying `macos/Runner/AppDelegate.swift`. We used a `FlutterMethodChannel` as the bridge to send data from the native Swift environment to the Dart environment in a clean and maintainable way.

### 2. Understanding and Respecting the macOS Sandbox is Crucial

- **Insight:** The macOS App Sandbox is a powerful security feature that strictly controls an application's access to the file system. This was the root cause of our most significant challenges.
- **Lesson 1: Entitlements are necessary but not sufficient.** We learned that adding an entitlement (like `com.apple.security.files.user-selected.read-write`) in the `.entitlements` files is the first step, allowing the app to *request* file access. However, it does not grant unilateral permission to read any path the app receives.
- **Lesson 2: User Intent is paramount.** The sandbox requires clear user intent to grant access. We discovered the critical difference between:
    - **Programmatic Access (which fails):** Passing a path as a command-line flag (`--args`) is seen by the sandbox as the app trying to access a file on its own, which is blocked.
    - **User-Initiated Access (which succeeds):** Using the in-app `FilePicker`, dragging a folder onto the app icon, or using the `open -a ... /path/to/folder` command are all actions that the OS recognizes as explicit user consent, thereby granting the necessary permissions for that session.

### 3. There is a "Right Way" to Test and Run macOS Apps

- **Insight:** A macOS `.app` file is not a single executable but a directory bundle.
- **Lesson 1: Execution from the command line.** You cannot simply execute the `.app` bundle. You must either use the `open` command (`open -a /path/to/App.app`) or run the actual binary located inside the bundle (`/path/to/App.app/Contents/MacOS/App`).
- **Lesson 2: Build artifacts can cause issues.** When encountering strange build errors, especially after moving the project directory, running `flutter clean` is a critical first step to remove stale caches and precompiled headers that can cause conflicts.

### Summary for Future Projects

For any future Flutter macOS development involving file system access, we should remember this workflow:

1.  **For file access, always assume the app is sandboxed.**
2.  Add the necessary `com.apple.security.files.*` entitlements to `DebugProfile.entitlements` and `Release.entitlements` from the start.
3.  To open the app with a specific file or folder, implement the `application(_:openFiles:)` method in `AppDelegate.swift`. Do not rely on parsing command-line arguments with `--args`.
4.  Use a `MethodChannel` to communicate the file path from the native side to the Flutter UI.
5.  When testing, always use the `open -a` command or drag-and-drop, and remember to `flutter clean` if you encounter unexpected build failures.
