import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'media_detail_dialog.dart';
import 'media_service.dart';

final _logger = Logger('MediaBrowserApp');

/// View display modes for media files.
enum ViewLayoutMode {
  category('Categories', Icons.view_agenda_outlined),
  grid('Grid', Icons.grid_view),
  list('List', Icons.view_list);

  final String label;
  final IconData icon;
  const ViewLayoutMode(this.label, this.icon);
}

void main(List<String> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(MediaBrowserApp(initialPath: args.isNotEmpty ? args[0] : null));
}

/// Root widget of the application.
class MediaBrowserApp extends StatefulWidget {
  final String? initialPath;

  const MediaBrowserApp({super.key, this.initialPath});

  @override
  State<MediaBrowserApp> createState() => _MediaBrowserAppState();
}

class _MediaBrowserAppState extends State<MediaBrowserApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066CC),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3399FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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

/// Home page of the Media Browser application.
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
  static const platform = MethodChannel('com.example.media_browser/args');
  final MediaService _mediaService = MediaService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedDirectory;
  Map<String, List<MediaFile>> _mediaFiles = {};
  StreamSubscription<void>? _directoryWatcherSubscription;
  bool _isLoading = false;
  DirectoryNode? _directoryTreeRoot;
  String? _activeFilterPath;
  bool _isSidenavExpanded = true;

  ViewLayoutMode _layoutMode = ViewLayoutMode.category;
  MediaCategory _selectedCategory = MediaCategory.all;
  SortOption _selectedSort = SortOption.dateModifiedDesc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectDirectory(widget.initialPath!);
        }
      });
    }
  }

  Future<void> _setupMethodChannel() async {
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == "setInitialDirectory") {
          final String path = call.arguments;
          _selectDirectory(path);
        }
      });
    } catch (e) {
      _showError("Error setting up method channel: $e");
    }
  }

  void _toggleSidenav() {
    setState(() {
      _isSidenavExpanded = !_isSidenavExpanded;
    });
  }

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

  void _showError(String message) {
    _logger.warning(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _directoryWatcherSubscription?.cancel();
    _mediaService.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Get filtered and sorted list of all active media files
  List<MediaFile> _getFilteredFiles() {
    final List<MediaFile> all = [];
    _mediaFiles.forEach((_, files) {
      for (final f in files) {
        if (_activeFilterPath != null && !f.file.path.startsWith(_activeFilterPath!)) {
          continue;
        }
        if (_selectedCategory != MediaCategory.all && f.category != _selectedCategory) {
          continue;
        }
        if (_searchQuery.isNotEmpty &&
            !f.name.toLowerCase().contains(_searchQuery) &&
            !f.extension.toLowerCase().contains(_searchQuery)) {
          continue;
        }
        all.add(f);
      }
    });

    return sortMediaFiles(all, _selectedSort);
  }

  /// Get filtered map grouped by category/mime-type
  Map<String, List<MediaFile>> _getFilteredGroupedFiles() {
    final Map<String, List<MediaFile>> result = {};
    _mediaFiles.forEach((categoryKey, files) {
      final List<MediaFile> matched = [];
      for (final f in files) {
        if (_activeFilterPath != null && !f.file.path.startsWith(_activeFilterPath!)) {
          continue;
        }
        if (_selectedCategory != MediaCategory.all && f.category != _selectedCategory) {
          continue;
        }
        if (_searchQuery.isNotEmpty &&
            !f.name.toLowerCase().contains(_searchQuery) &&
            !f.extension.toLowerCase().contains(_searchQuery)) {
          continue;
        }
        matched.add(f);
      }
      if (matched.isNotEmpty) {
        result[categoryKey] = sortMediaFiles(matched, _selectedSort);
      }
    });
    return result;
  }

  void _openDetailDialog(MediaFile mediaFile, List<MediaFile> list) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MediaDetailDialog(
          fileEntity: mediaFile.file,
          fileList: list,
          initialIndex: list.indexOf(mediaFile),
          currentThemeMode: widget.currentThemeMode,
        );
      },
    );
  }

  Widget _buildMediaThumbnail(MediaFile mediaFile, {double width = 120, double height = 80}) {
    final file = mediaFile.file as File;
    final mimeType = mediaFile.mimeType;
    final ext = mediaFile.extension;

    if (mimeType.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: (width * 2).toInt(),
          cacheHeight: (height * 2).toInt(),
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
        ),
      );
    } else if (mimeType.startsWith('video/')) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FutureBuilder<Uint8List?>(
              future: VideoThumbnailCache.getThumbnail(file.path),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.movie_creation_outlined, size: 36)),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
          ),
        ],
      );
    } else if (mimeType.startsWith('audio/')) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack, size: 36, color: Theme.of(context).colorScheme.primary),
            if (ext.isNotEmpty)
              Text(
                ext.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      );
    } else if (mimeType == 'application/pdf' || ext == 'pdf') {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 36, color: Theme.of(context).colorScheme.error),
            const Text(
              'PDF',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mediaFile.category == MediaCategory.code
                  ? Icons.code
                  : Icons.insert_drive_file_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.secondary,
            ),
            if (ext.isNotEmpty)
              Text(
                ext.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildMediaCard(MediaFile mediaFile, List<MediaFile> activeList) {
    final fileName = mediaFile.name;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDetailDialog(mediaFile, activeList),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.all(6.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 84,
                width: 132,
                child: Center(
                  child: _buildMediaThumbnail(mediaFile, width: 132, height: 84),
                ),
              ),
              const SizedBox(height: 6),
              Tooltip(
                message: '$fileName\n${_formatFileSize(mediaFile.size)}',
                child: Text(
                  fileName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              Text(
                _formatFileSize(mediaFile.size),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderTile(DirectoryNode node, {int depth = 0}) {
    bool isCurrentlySelected = _activeFilterPath == node.directory.path;

    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        leading: Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: Icon(
            Icons.folder_outlined,
            size: 18,
            color: isCurrentlySelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        title: Text(
          node.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isCurrentlySelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
      dense: true,
      leading: Padding(
        padding: EdgeInsets.only(left: depth * 12.0),
        child: Icon(
          Icons.folder_outlined,
          size: 18,
          color: isCurrentlySelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      title: Text(
        node.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isCurrentlySelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      initiallyExpanded: node.isExpanded,
      onExpansionChanged: (expanded) {
        node.isExpanded = expanded;
      },
      trailing: IconButton(
        icon: const Icon(Icons.filter_list, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        tooltip: 'Filter by this folder',
        color: isCurrentlySelected ? Theme.of(context).colorScheme.primary : null,
        onPressed: () {
          setState(() {
            _activeFilterPath = node.directory.path;
          });
        },
      ),
      children: node.children.map((child) => _buildFolderTile(child, depth: depth + 1)).toList(),
    );
  }

  Widget _buildFolderHierarchySidenav() {
    if (_directoryTreeRoot == null) {
      return const Center(child: Text("No directory loaded"));
    }
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerLeft,
            child: Text(
              'DIRECTORIES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.all_inbox_outlined,
              size: 20,
              color: _activeFilterPath == null ? Theme.of(context).colorScheme.primary : null,
            ),
            title: const Text('All Files', style: TextStyle(fontSize: 13)),
            selected: _activeFilterPath == null,
            onTap: () {
              setState(() {
                _activeFilterPath = null;
              });
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                _buildFolderTile(_directoryTreeRoot!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: MediaCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Text(cat.displayName),
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainView() {
    final filteredFiles = _getFilteredFiles();

    if (filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching media files for "$_searchQuery"'
                  : 'No media files found in selected location.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    switch (_layoutMode) {
      case ViewLayoutMode.category:
        final grouped = _getFilteredGroupedFiles();
        return ListView.builder(
          itemCount: grouped.keys.length,
          itemBuilder: (context, index) {
            final groupKey = grouped.keys.elementAt(index);
            final files = grouped[groupKey]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        groupKey,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${files.length} items',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: files.length,
                    itemBuilder: (context, fileIndex) {
                      return _buildMediaCard(files[fileIndex], files);
                    },
                  ),
                ),
                const Divider(height: 24),
              ],
            );
          },
        );

      case ViewLayoutMode.grid:
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = max(2, (constraints.maxWidth / 170).floor());
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filteredFiles.length,
              itemBuilder: (context, index) {
                return _buildMediaCard(filteredFiles[index], filteredFiles);
              },
            );
          },
        );

      case ViewLayoutMode.list:
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredFiles.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final file = filteredFiles[index];
            return ListTile(
              leading: SizedBox(
                width: 50,
                height: 40,
                child: _buildMediaThumbnail(file, width: 50, height: 40),
              ),
              title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${_formatFileSize(file.size)} • ${DateFormat.yMMMd().format(file.modified)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Chip(
                label: Text(
                  file.extension.toUpperCase().isNotEmpty ? file.extension.toUpperCase() : 'FILE',
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              onTap: () => _openDetailDialog(file, filteredFiles),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainBody;

    if (_selectedDirectory == null) {
      mainBody = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.perm_media_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Media Browser',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse images, videos, audio, and code across directories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Media Directory (Cmd+O)'),
              onPressed: _pickDirectory,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    } else if (_isLoading) {
      mainBody = Shimmer.fromColors(
        baseColor: Colors.grey.withValues(alpha: 0.3),
        highlightColor: Colors.grey.withValues(alpha: 0.1),
        child: ListView.builder(
          itemCount: 4,
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(width: 160, height: 24, color: Colors.white),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (context, i) => Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      mainBody = Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildMainView()),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _pickDirectory,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _pickDirectory,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          if (_selectedDirectory != null) _loadAllData(_selectedDirectory!);
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (_selectedDirectory != null) _loadAllData(_selectedDirectory!);
        },
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            setState(() => _layoutMode = ViewLayoutMode.category),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
            setState(() => _layoutMode = ViewLayoutMode.grid),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
            setState(() => _layoutMode = ViewLayoutMode.list),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: (_selectedDirectory != null)
                ? IconButton(
                    icon: Icon(_isSidenavExpanded ? Icons.menu_open : Icons.menu),
                    tooltip: 'Toggle Directory Sidebar',
                    onPressed: _toggleSidenav,
                  )
                : null,
            title: _selectedDirectory != null
                ? SizedBox(
                    height: 40,
                    width: 340,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search files (Cmd+F)...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : const Text('Media Browser'),
            actions: [
              if (_selectedDirectory != null) ...[
                // View Mode Toggle
                SegmentedButton<ViewLayoutMode>(
                  segments: ViewLayoutMode.values.map((mode) {
                    return ButtonSegment(
                      value: mode,
                      icon: Icon(mode.icon, size: 16),
                      tooltip: mode.label,
                    );
                  }).toList(),
                  selected: {_layoutMode},
                  onSelectionChanged: (Set<ViewLayoutMode> newSelection) {
                    setState(() {
                      _layoutMode = newSelection.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),

                // Sort Menu
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort by',
                  onSelected: (SortOption option) {
                    setState(() {
                      _selectedSort = option;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return SortOption.values.map((SortOption option) {
                      return PopupMenuItem<SortOption>(
                        value: option,
                        child: Row(
                          children: [
                            Icon(
                              _selectedSort == option ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: _selectedSort == option
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                            const SizedBox(width: 8),
                            Text(option.label),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh (Cmd+R)',
                  onPressed: () {
                    if (_selectedDirectory != null) {
                      _loadAllData(_selectedDirectory!);
                    }
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: 'Open Directory (Cmd+O)',
                onPressed: _pickDirectory,
              ),
              IconButton(
                icon: Icon(
                  widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: 'Toggle Theme',
                onPressed: widget.toggleThemeMode,
              ),
            ],
          ),
          body: Row(
            children: <Widget>[
              if (_selectedDirectory != null && _directoryTreeRoot != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isSidenavExpanded ? 260.0 : 0.0,
                  child: _isSidenavExpanded
                      ? ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: 0.0,
                            maxWidth: 260.0,
                            child: _buildFolderHierarchySidenav(),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              Expanded(child: mainBody),
            ],
          ),
        ),
      ),
    );
  }
}