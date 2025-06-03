# Media Browser

This Flutter application allows users to browse and view media files within a selected directory and its subdirectories. While initially focused on macOS, it can also be built and run on Linux.

**Key Features:**

*   **Directory Selection:** Users can pick a root directory on their system.
*   **Recursive Media Listing:** Displays media files (images, videos, audio) from the chosen directory and all its nested folders.
*   **File Type Filtering:**
    *   Ignores hidden `.DS_Store` files.
    *   Excludes all files with `application/*` MIME types (e.g., `application/pdf`, `application/json` are not listed in the main browser but specific viewers exist if they were to be loaded).
    *   Skips files with an 'unknown' MIME type.
*   **Collapsible Folder Hierarchy Sidenav:**
    *   A sidebar displays the folder structure of the selected root directory.
    *   This sidebar can be collapsed or expanded.
    *   Selecting a folder in the sidebar filters the main view to show only media within that specific folder.
    *   An "All Files" option in the sidebar displays all media from the root directory and its children.
*   **Media Previews:**
    *   **Images:** Shows a preview thumbnail in the media card.
    *   **Videos:** Displays a generated thumbnail in the media card.
    *   **Audio:** Shows a generic audio icon.
*   **Media Detail Dialog:**
    *   **Images:** Opens an enlarged, interactive (zoomable) view of the image.
    *   **Videos:** Provides a video player with play/pause controls, a progress indicator, and current/total time display.
    *   **Audio:** Offers an audio player with play/pause/stop controls and a timeline slider with current/total time display.
    *   **Text/Markdown:** Renders Markdown content in a scrollable view.
    *   **JSON:** Displays JSON content with syntax highlighting in a scrollable view.
    *   **Metadata:** Shows the full file path, size, last modified date, and MIME type for the selected file.
*   **Light/Dark Mode:**
    *   Defaults to the system's current light or dark theme on startup.
    *   Includes a toggle button in the app bar to manually switch between light and dark modes for the current session.
*   **Live Directory Watching:** Automatically updates the displayed media files and the folder hierarchy in the sidebar if changes (additions, deletions, modifications) occur within the selected directory.

## Flutter Version

This project requires a Flutter SDK that includes Dart `^3.9.0-100.2.beta` or compatible.

## Build & Release

### macOS

The following will create `build/macos/Build/Products/Release/Media Browser.app`

```bash
flutter build macos --release  
```

On MacOS, you can provide a path at opening e.g.

```bash
open Media\ Browser.app --args ~/genmedia/pip_storyboard
```

### Linux (e.g., on a Chromebook with Crostini)

**Prerequisites:**

Ensure you have the following development libraries and tools installed. On Debian/Ubuntu-based systems, you can use:

```bash
sudo apt-get update && sudo apt-get install -y \
    clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
    libasound2-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    zenity
```

*   `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`: General Flutter Linux build dependencies.
*   `libasound2-dev`, `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`: For audio playback capabilities via the `audioplayers` plugin.
*   `zenity`: For native file/directory picker dialogs used by the `file_picker` plugin.

**Building:**

1.  **Enable Linux platform support** (if not already done):
    ```bash
    flutter create --platforms linux .
    ```
2.  **Get dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Build the release application:**
    ```bash
    flutter build linux --release
    ```
    If you encounter build issues related to install paths, try cleaning first:
    ```bash
    flutter clean && flutter build linux --release
    ```

**Running:**

The executable will be located at `build/linux/x64/release/bundle/media_browser_app`.
Run it from the project root directory:

```bash
./build/linux/x64/release/bundle/media_browser_app
```

# License
Apache 2.0; see LICENSE for details.

# Disclaimer
This project is not an official Google project. It is not supported by Google and Google specifically disclaims all warranties as to its quality, merchantability, or fitness for a particular purpose.
