import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_memory_image/cached_memory_image.dart';
import 'media_detail_dialog.dart';
import 'media_service.dart';

// The main entry point for the application.
void main(List<String> args) {
  runApp(MediaBrowserApp(initialPath: args.isNotEmpty ? args[0] : null));
}

// The root widget of the application.
class MediaBrowserApp extends StatefulWidget {
  final String? initialPath;

  const MediaBrowserApp({super.key, this.initialPath});

  @override
  State<MediaBrowserApp> createState() => _MediaBrowserAppState();
}

// The state for the root widget of the application.
class _MediaBrowserAppState extends State<MediaBrowserApp> {
  ThemeMode _themeMode = ThemeMode.system;

  // Toggles the theme of the application between light and dark mode.
  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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

// The home page of the application.
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

// The state for the home page of the application.
class _MediaHomePageState extends State<MediaHomePage> {
  final MediaService _mediaService = MediaService();
  String? _selectedDirectory;
  Map<String, List<MediaFile>> _mediaFiles = {};
  StreamSubscription<void>? _directoryWatcherSubscription;
  bool _isLoading = false;
  DirectoryNode? _directoryTreeRoot;
  String? _activeFilterPath;
  bool _isSidenavExpanded = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectDirectory(widget.initialPath!);
        }
      });
    }
  }

  // Toggles the visibility of the side navigation panel.
  void _toggleSidenav() {
    setState(() {
      _isSidenavExpanded = !_isSidenavExpanded;
    });
  }

  // Opens a directory picker and loads the media files from the selected directory.
  Future<void> _pickDirectory() async {
    try {
      final String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        _selectDirectory(path);
      }
    } catch (e) {
      _showError("Error picking directory: $e");
    }
  }

  // Loads the media files from the given directory path.
  Future<void> _selectDirectory(String path) async {
    setState(() {
      _selectedDirectory = path;
      _mediaFiles = {};
      _directoryTreeRoot = null;
      _activeFilterPath = null;
      _isLoading = true;
    });

    await _loadAllData(path);
    _directoryWatcherSubscription?.cancel();
    _directoryWatcherSubscription = _mediaService.watchDirectory(path).listen((_) {
      _loadAllData(path);
    }, onError: (error) {
      _showError("Error watching directory: $error");
    });
  }

  // Loads all media data from the given path.
  Future<void> _loadAllData(String path) async {
    try {
      final mediaData = await compute(loadAllMediaData, path);
      if (mounted) {
        setState(() {
          _mediaFiles = mediaData.mediaFiles;
          _directoryTreeRoot = mediaData.directoryTree;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Error loading media: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Shows an error message in a snackbar.
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _directoryWatcherSubscription?.cancel();
    _mediaService.dispose();
    super.dispose();
  }

  // Generates a thumbnail for the given video path.
  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    try {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 120,
        quality: 25,
      );
      return thumbnailBytes;
    } catch (e) {
      print("Error generating video thumbnail for $videoPath: $e");
      return null;
    }
  }

  // Builds a widget for a single folder in the directory hierarchy.
  Widget _buildFolderTile(DirectoryNode node, {int depth = 0}) {
    bool isCurrentlySelected = _activeFilterPath == node.directory.path;

    if (node.children.isEmpty) {
      return ListTile(
        leading: Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: Icon(
            Icons.folder_outlined,
            color: isCurrentlySelected ? Theme.of(context).colorScheme.secondary : null,
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
      key: PageStorageKey<String>(node.directory.path),
      leading: Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: Icon(
          Icons.folder_outlined,
          color: isCurrentlySelected ? Theme.of(context).colorScheme.secondary : null,
        ),
      ),
      title: Text(node.directory.path.split(Platform.pathSeparator).last),
      initiallyExpanded: node.isExpanded,
      onExpansionChanged: (expanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              node.isExpanded = expanded;
            });
          }
        });
      },
      trailing: IconButton(
        icon: const Icon(Icons.filter_list),
        iconSize: 20.0,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
          maxWidth: 30,
          maxHeight: 30,
        ),
        visualDensity: VisualDensity.compact,
        tooltip: 'Filter by this folder',
        color: isCurrentlySelected ? Theme.of(context).colorScheme.secondary : null,
        onPressed: () {
          setState(() {
            _activeFilterPath = node.directory.path;
          });
        },
      ),
      children: node.children.map((child) => _buildFolderTile(child, depth: depth + 1)).toList(),
    );
  }

  // Builds the side navigation panel with the directory hierarchy.
  Widget _buildFolderHierarchySidenav() {
    if (_directoryTreeRoot == null) {
      return const Center(
        child: Text("No directory selected or hierarchy not built."),
      );
    }
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.folder_special_outlined,
              color: _activeFilterPath == null ? Theme.of(context).colorScheme.secondary : null,
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

  // Builds a card widget for a single media file.
  Widget _buildMediaCard(MediaFile mediaFile) {
    final file = mediaFile.file as File;
    final stat = mediaFile.stat;
    final String fileName = file.path.split(Platform.pathSeparator).last;
    final String mimeType = lookupMimeType(file.path) ?? 'unknown';
    Widget previewWidget;

    if (mimeType.startsWith('image/')) {
      if (mediaFile.bytes != null) {
        previewWidget = CachedMemoryImage(
          uniqueKey: file.path + stat.modified.toIso8601String(),
          bytes: mediaFile.bytes,
          width: 120,
          height: 80,
          fit: BoxFit.cover,
          placeholder: const Center(child: Icon(Icons.image_outlined, size: 50)),
          errorWidget: const Icon(Icons.broken_image_outlined, size: 50),
        );
      } else {
        previewWidget = const Icon(Icons.broken_image_outlined, size: 50);
      }
    } else if (mimeType.startsWith('video/')) {
      previewWidget = FutureBuilder<Uint8List?>(
        future: _getVideoThumbnail(file.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: 120,
              height: 80,
              fit: BoxFit.cover,
            );
          } else if (snapshot.hasError) {
            return const Icon(Icons.broken_image_outlined, size: 50);
          }
          return const Icon(Icons.movie_creation_outlined, size: 50);
        },
      );
    } else if (mimeType.startsWith('audio/')) {
      previewWidget = const Icon(Icons.audiotrack_outlined, size: 50);
    } else if (mimeType == 'application/pdf') {
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
                height: 80,
                width: 120,
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
      mainContent = Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 3 / 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 12, // Placeholder for shimmer
          itemBuilder: (context, index) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 120,
                      height: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 100,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      Map<String, List<MediaFile>> filteredMediaFiles = {};
      if (_activeFilterPath == null) {
        filteredMediaFiles = _mediaFiles;
      } else {
        _mediaFiles.forEach((mimeType, files) {
          final List<MediaFile> categoryFiles = files.where((mediaFile) => mediaFile.file.path.startsWith(_activeFilterPath!)).toList();
          if (categoryFiles.isNotEmpty) {
            filteredMediaFiles[mimeType] = categoryFiles;
          }
        });
      }

      if (filteredMediaFiles.isEmpty) {
        mainContent = Center(
          child: Text(
            _activeFilterPath == null
                ? 'No media files found in the selected directory.'
                : 'No media files found in "${_activeFilterPath!.split(Platform.pathSeparator).last}".',
          ),
        );
      } else {
        mainContent = ListView.builder(
          itemCount: filteredMediaFiles.keys.length,
          itemBuilder: (context, index) {
            final String mimeType = filteredMediaFiles.keys.elementAt(index);
            final List<MediaFile> files = filteredMediaFiles[mimeType]!;
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
                  height: 180, // This is crucial for lazy loading the horizontal list
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
          _selectedDirectory?.split(Platform.pathSeparator).last ?? 'Media Browser',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: widget.toggleThemeMode,
          ),
          if (_selectedDirectory != null)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Media',
                    onPressed: () {
                      if (_selectedDirectory != null) {
                        _loadAllData(_selectedDirectory!);
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
                        minWidth: 0.0,
                        maxWidth: 250.0,
                        child: _buildFolderHierarchySidenav(),
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
