import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:watcher/watcher.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data'; // For Uint8List
// For date formatting
// import 'dart:math'; // No longer needed here after removing _formatFileSize

import 'media_detail_dialog.dart'; // Import the new dialog

// Helper class for the directory tree structure
class DirectoryNode {
  final Directory directory;
  final List<DirectoryNode> children;
  bool isExpanded; // To manage expansion state in the UI

  DirectoryNode(this.directory, this.children, {this.isExpanded = false});
}

void main(List<String> args) {
  runApp(MediaBrowserApp(initialPath: args.isNotEmpty ? args[0] : null));
}

class MediaBrowserApp extends StatefulWidget {
  final String? initialPath;

  const MediaBrowserApp({super.key, this.initialPath});

  @override
  State<MediaBrowserApp> createState() => _MediaBrowserAppState();
}

class _MediaBrowserAppState extends State<MediaBrowserApp> {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Browser',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Consider further customizing your light theme here
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue, // Or a different color for dark theme
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Consider further customizing your dark theme here
      ),
      themeMode: _themeMode,
      home: MediaHomePage(
        currentThemeMode: _themeMode,
        toggleThemeMode: _toggleThemeMode,
        initialPath: widget.initialPath,
      ),
    );
  }
}

class MediaHomePage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final VoidCallback toggleThemeMode;
  final String? initialPath;

  const MediaHomePage({
    super.key,
    required this.currentThemeMode,
    required this.toggleThemeMode,
    this.initialPath,
  });

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  String? _selectedDirectory;
  Map<String, List<FileSystemEntity>> _mediaFiles = {};
  StreamSubscription<WatchEvent>? _directoryChangesSubscription;
  bool _isLoading = false;
  DirectoryNode? _directoryTreeRoot;
  String?
  _activeFilterPath; // Path of the folder selected in sidenav for filtering
  bool _isSidenavExpanded = true; // State for sidenav visibility

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      // Use a post-frame callback to ensure context is available for ScaffoldMessenger
      // and to avoid issues if setState is called during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
          _selectAndLoadDirectory(widget.initialPath!);
        }
      });
    }
  }

  void _toggleSidenav() {
    setState(() {
      _isSidenavExpanded = !_isSidenavExpanded;
    });
  }

  Future<void> _selectAndLoadDirectory(String path) async {
    // Validate if the path is a directory and exists
    final directory = Directory(path);
    if (!await directory.exists()) {
      print("Error: Provided path is not a valid directory or does not exist: $path");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Invalid directory path '$path'")),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading indicator is turned off
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedDirectory = path;
        _mediaFiles = {}; // Clear previous files
        _directoryTreeRoot = null; // Clear previous tree
        _activeFilterPath = null; // Reset filter
        _isLoading = true;
      });
    } else {
      // If not mounted, do not proceed with loading.
      return;
    }
    
    await _loadMediaFiles(path);
    await _buildDirectoryHierarchy(path);
    _watchDirectory(path);
  }

  Future<void> _pickDirectory() async {
    try {
      final String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        print("Directory picked: $path"); // Logging
        await _selectAndLoadDirectory(path);
      }
    } catch (e) {
      print("Error picking directory: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking directory: $e")),
        );
      }
    }
  }

  Future<void> _loadMediaFiles(String path) async {
    print("Starting _loadMediaFiles for path: $path"); // Logging
    final directory = Directory(path);
    if (!await directory.exists()) {
      print("Directory does not exist: $path");
      if (mounted) { // Ensure mounted before calling setState
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final Map<String, List<FileSystemEntity>> categorizedFiles = {};
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          // Skip .DS_Store files
          if (entity.path.split(Platform.pathSeparator).last == '.DS_Store') {
            continue;
          }
          final mimeType = lookupMimeType(entity.path) ?? 'unknown';
          // print("Processing file: ${entity.path}, MIME: $mimeType"); // Verbose logging

          // Ignore all mime types starting with application/
          if (mimeType.startsWith('application/')) {
            continue;
          }

          // Ignore files with unknown MIME type
          if (mimeType == 'unknown') {
            // print("Skipping unknown MIME type for file: ${entity.path}"); // Logging
            continue;
          }

          categorizedFiles.putIfAbsent(mimeType, () => []).add(entity);
        }
      }
    } catch (e) {
      print("Error listing files in _loadMediaFiles: $e"); // Logging
      // Handle error
    }

    // Sort files by modification date (most recent first) within each category
    categorizedFiles.forEach((key, value) {
      value.sort((a, b) {
        try {
          // a and b are FileSystemEntity, confirmed to be File instances by prior logic
          final statA = File(a.path).statSync();
          final statB = File(b.path).statSync();

          // Sort by modification date in descending order (most recent first)
          int comparisonResult = statB.modified.compareTo(statA.modified);

          // If modification times are identical, sort by name as a secondary criterion
          if (comparisonResult == 0) {
            return a.path.toLowerCase().compareTo(b.path.toLowerCase());
          }
          return comparisonResult;
        } catch (e) {
          print("Error getting file stats for sorting: $e. File A: ${a.path}, File B: ${b.path}. Falling back to name sort."); // Logging
          // Fallback to sorting by path if stats are unavailable
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        }
      });
    });

    // Sort categories by name
    final sortedCategorizedFiles = Map.fromEntries(
      categorizedFiles.entries.toList()
        ..sort((e1, e2) => e1.key.compareTo(e2.key)),
    );
    
    if (mounted) { // Ensure mounted before calling setState
      setState(() {
        _mediaFiles = sortedCategorizedFiles;
        _isLoading = false;
      });
    }
    print("Finished _loadMediaFiles for path: $path. Found ${categorizedFiles.length} categories."); // Logging
  }

  void _watchDirectory(String path) {
    _directoryChangesSubscription?.cancel(); // Cancel previous subscription
    print("Setting up directory watcher for path: $path"); // Logging

    final newWatcher = DirectoryWatcher(path);
    _directoryChangesSubscription = newWatcher.events.listen((event) {
      print("File system event: ${event.type} on ${event.path}"); // Logging
      // Reload all files on any change for simplicity
      if (_selectedDirectory != null && mounted) { // Ensure mounted
        // Debounce or delay might be useful here in future
        print("Reloading due to watcher event."); // Logging
        _loadMediaFiles(_selectedDirectory!);
        _buildDirectoryHierarchy(_selectedDirectory!);
      }
    }, onError: (error) { // Add onError for the stream
      print("Error in directory watcher stream: $error"); // Logging
    });
    print("Watching directory: $path");
  }

  @override
  void dispose() {
    _directoryChangesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _buildDirectoryHierarchy(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (await rootDir.exists()) {
      _directoryTreeRoot = await _buildNode(rootDir);
      setState(() {}); // Update UI with the new tree
    }
  }

  Future<DirectoryNode> _buildNode(Directory dir) async {
    final List<DirectoryNode> children = [];
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          // Skip hidden directories (like .git, .vscode, etc.)
          if (!entity.path.split(Platform.pathSeparator).last.startsWith('.')) {
            children.add(await _buildNode(entity));
          }
        }
      }
      // Sort children by name
      children.sort(
        (a, b) => a.directory.path.toLowerCase().compareTo(
          b.directory.path.toLowerCase(),
        ),
      );
    } catch (e) {
      print("Error building directory node for ${dir.path}: $e");
      // Optionally, handle permissions errors or other issues here
    }
    return DirectoryNode(dir, children);
  }

  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    try {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 120, // Corresponds to preview width
        quality: 25,
      );
      return thumbnailBytes;
    } catch (e) {
      print("Error generating video thumbnail for $videoPath: $e");
      return null;
    }
  }

  Widget _buildFolderTile(DirectoryNode node, {int depth = 0}) {
    bool isCurrentlySelected = _activeFilterPath == node.directory.path;

    if (node.children.isEmpty) {
      return ListTile(
        leading: Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: Icon(
            Icons.folder_outlined,
            color: isCurrentlySelected
                ? Theme.of(context).colorScheme.secondary
                : null,
          ),
        ),
        title: Text(node.directory.path.split(Platform.pathSeparator).last),
        selected: isCurrentlySelected,
        onTap: () {
          setState(() {
            _activeFilterPath = node.directory.path;
          });
        },
      );
    }

    return ExpansionTile(
      key: PageStorageKey<String>(
        node.directory.path,
      ), // Preserve expansion state
      leading: Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: Icon(
          Icons.folder_outlined,
          color: isCurrentlySelected
              ? Theme.of(context).colorScheme.secondary
              : null,
        ),
      ),
      title: Text(node.directory.path.split(Platform.pathSeparator).last),
      initiallyExpanded: node.isExpanded,
      onExpansionChanged: (expanded) {
        // Defer the setState call until after the build phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Check if the widget is still in the tree
            setState(() {
              node.isExpanded = expanded;
            });
          }
        });
      },
      trailing: IconButton(
        icon: const Icon(Icons.filter_list),
        iconSize: 20.0, // Make the icon itself smaller
        padding: EdgeInsets.zero, // Remove default padding around the icon
        constraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
          maxWidth: 30,
          maxHeight: 30,
        ), // Constrain the button's size
        visualDensity: VisualDensity.compact, // Use a more compact layout
        tooltip: 'Filter by this folder',
        color: isCurrentlySelected
            ? Theme.of(context).colorScheme.secondary
            : null,
        onPressed: () {
          setState(() {
            _activeFilterPath = node.directory.path;
          });
        },
      ),
      children: node.children
          .map((child) => _buildFolderTile(child, depth: depth + 1))
          .toList(),
    );
  }

  Widget _buildFolderHierarchySidenav() {
    if (_directoryTreeRoot == null) {
      return const Center(
        child: Text("No directory selected or hierarchy not built."),
      );
    }
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.folder_special_outlined,
              color: _activeFilterPath == null
                  ? Theme.of(context).colorScheme.secondary
                  : null,
            ),
            title: const Text('All Files'),
            selected: _activeFilterPath == null,
            onTap: () {
              setState(() {
                _activeFilterPath = null;
              });
            },
          ),
          const Divider(),
          _buildFolderTile(_directoryTreeRoot!),
        ],
      ),
    );
  }

  Widget _buildMediaCard(FileSystemEntity file) {
    final String fileName = file.path.split(Platform.pathSeparator).last;
    final String mimeType = lookupMimeType(file.path) ?? 'unknown';
    // print("Building media card for: ${file.path}, MIME: $mimeType"); // Verbose logging
    Widget previewWidget;

    if (mimeType.startsWith('image/')) {
      previewWidget = Image.file(
        File(file.path),
        width: 120,
        height: 80,
        fit: BoxFit.cover,
        key: ValueKey(file.path + File(file.path).statSync().modified.toString()), // Attempt to bust cache on modification
        errorBuilder: (context, error, stackTrace) {
          print("Error loading image preview for ${file.path}: $error"); // Logging
          return const Icon(Icons.broken_image_outlined, size: 50);
        },
      );
    } else if (mimeType.startsWith('video/')) {
      previewWidget = FutureBuilder<Uint8List?>(
        future: _getVideoThumbnail(file.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: 120,
              height: 80,
              fit: BoxFit.cover,
            );
          } else if (snapshot.hasError) {
            print(
              "Error loading video thumbnail from FutureBuilder for ${file.path}: ${snapshot.error}", // Logging
            );
            return const Icon(Icons.broken_image_outlined, size: 50);
          }
          // Show placeholder while loading or if no data and no error yet
          return const Icon(
            Icons.movie_creation_outlined,
            size: 50,
          ); 
        },
      );
    } else if (mimeType.startsWith('audio/')) {
      previewWidget = const Icon(Icons.audiotrack_outlined, size: 50);
    } else if (mimeType == 'application/pdf') { // This was text/pdf, should be application/pdf
      previewWidget = const Icon(Icons.picture_as_pdf_outlined, size: 50);
    } else {
      previewWidget = const Icon(Icons.insert_drive_file_outlined, size: 50);
    }

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return MediaDetailDialog(
              fileEntity: file,
              currentThemeMode: widget.currentThemeMode,
            );
          },
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 80, // Fixed height for the preview area
                width: 120, // Fixed width for the preview area
                child: Center(child: previewWidget),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  fileName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;
    if (_selectedDirectory == null) {
      mainContent = Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.folder_open),
          label: const Text('Select Media Directory'),
          onPressed: _pickDirectory,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      );
    } else if (_isLoading) {
      mainContent = const Center(child: CircularProgressIndicator());
    } else if (_mediaFiles.isEmpty && _directoryTreeRoot == null) {
      // This case might occur if directory is empty or inaccessible before tree is built
      mainContent = const Center(
        child: Text('No media files found or directory is empty.'),
      );
    } else {
      // Filter media files based on _activeFilterPath
      Map<String, List<FileSystemEntity>> filteredMediaFiles = {};
      if (_activeFilterPath == null) {
        filteredMediaFiles = _mediaFiles;
      } else {
        _mediaFiles.forEach((mimeType, files) {
          final List<FileSystemEntity> categoryFiles = files
              .where((file) => file.path.startsWith(_activeFilterPath!))
              .toList();
          if (categoryFiles.isNotEmpty) {
            filteredMediaFiles[mimeType] = categoryFiles;
          }
        });
      }

      if (filteredMediaFiles.isEmpty && _activeFilterPath != null) {
        mainContent = Center(
          child: Text(
            'No media files found in "${_activeFilterPath!.split(Platform.pathSeparator).last}".',
          ),
        );
      } else if (filteredMediaFiles.isEmpty &&
          _activeFilterPath == null &&
          _mediaFiles.isNotEmpty) {
        // This case should ideally not be hit if _mediaFiles is not empty,
        // but as a fallback if filtering somehow results in empty.
        mainContent = const Center(
          child: Text('No media files to display with current filter.'),
        );
      } else if (filteredMediaFiles.isEmpty && _mediaFiles.isEmpty) {
        mainContent = const Center(
          child: Text('No media files found in the selected directory.'),
        );
      } else {
        mainContent = ListView.builder(
          itemCount: filteredMediaFiles.keys.length,
          itemBuilder: (context, index) {
            final String mimeType = filteredMediaFiles.keys.elementAt(index);
            final List<FileSystemEntity> files = filteredMediaFiles[mimeType]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12.0).copyWith(bottom: 4.0),
                  child: Text(
                    mimeType,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SizedBox(
                  height: 180, // Height of the horizontal row
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: files.length,
                    itemBuilder: (context, fileIndex) {
                      return _buildMediaCard(files[fileIndex]);
                    },
                  ),
                ),
                const Divider(),
              ],
            );
          },
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: (_selectedDirectory != null)
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Toggle Folder View',
                onPressed: _toggleSidenav,
              )
            : null,
        title: Text(
          _selectedDirectory?.split(Platform.pathSeparator).last ??
              'Media Browser',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.currentThemeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: widget.toggleThemeMode,
          ),
          // Add Global Refresh Button here
          if (_selectedDirectory != null) // Only show if a directory is selected
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Media',
              onPressed: () async {
                if (_selectedDirectory != null) {
                  print("Global refresh triggered for: $_selectedDirectory");
                  // Set loading state true immediately for better UX
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                    });
                  }
                  await _selectAndLoadDirectory(_selectedDirectory!);
                  // _isLoading will be set to false at the end of _loadMediaFiles
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Directory',
            onPressed: _pickDirectory,
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          if (_selectedDirectory != null && _directoryTreeRoot != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidenavExpanded ? 250.0 : 0.0,
              child: _isSidenavExpanded
                  ? ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth:
                            0.0, // Can be 0 as child Container specifies width
                        maxWidth:
                            250.0, // Allow child to layout up to this width
                        child:
                            _buildFolderHierarchySidenav(), // This returns a Container(width: 250)
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          Expanded(child: mainContent),
        ],
      ),
    );
  }
}
