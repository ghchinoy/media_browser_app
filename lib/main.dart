import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:watcher/watcher.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // For date formatting

void main() {
  runApp(const MediaBrowserApp());
}

class MediaBrowserApp extends StatelessWidget {
  const MediaBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Browser',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MediaHomePage(),
    );
  }
}

class MediaHomePage extends StatefulWidget {
  const MediaHomePage({super.key});

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  String? _selectedDirectory;
  Map<String, List<FileSystemEntity>> _mediaFiles = {};
  DirectoryWatcher? _watcher;
  bool _isLoading = false;

  Future<void> _pickDirectory() async {
    try {
      final String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          _selectedDirectory = path;
          _mediaFiles = {}; // Clear previous files
          _isLoading = true;
        });
        _loadMediaFiles(path);
        _watchDirectory(path);
      }
    } catch (e) {
      print("Error picking directory: $e");
      // Handle error, e.g., show a snackbar
    }
  }

  Future<void> _loadMediaFiles(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      print("Directory does not exist: $path");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Map<String, List<FileSystemEntity>> categorizedFiles = {};
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final mimeType = lookupMimeType(entity.path) ?? 'unknown';
          categorizedFiles.putIfAbsent(mimeType, () => []).add(entity);
        }
      }
    } catch (e) {
      print("Error listing files: $e");
      // Handle error
    }


    // Sort files by name within each category
    categorizedFiles.forEach((key, value) {
      value.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    });

    // Sort categories by name
    final sortedCategorizedFiles = Map.fromEntries(
      categorizedFiles.entries.toList()
        ..sort((e1, e2) => e1.key.compareTo(e2.key))
    );

    setState(() {
      _mediaFiles = sortedCategorizedFiles;
      _isLoading = false;
    });
  }

  void _watchDirectory(String path) {
    _watcher?.close(); // Close previous watcher if any
    _watcher = DirectoryWatcher(path);
    _watcher?.events.listen((event) {
      print("File system event: ${event.type} on ${event.path}");
      // Reload all files on any change for simplicity
      // A more optimized approach would be to handle specific events (add, remove, modify)
      if (_selectedDirectory != null) {
         _loadMediaFiles(_selectedDirectory!);
      }
    });
    print("Watching directory: $path");
  }

  @override
  void dispose() {
    _watcher?.close();
    super.dispose();
  }

  Widget _buildMediaCard(FileSystemEntity file) {
    final String fileName = file.path.split(Platform.pathSeparator).last;
    final String mimeType = lookupMimeType(file.path) ?? 'unknown';
    IconData iconData;

    if (mimeType.startsWith('image/')) {
      iconData = Icons.image_outlined;
    } else if (mimeType.startsWith('video/')) {
      iconData = Icons.videocam_outlined;
    } else if (mimeType.startsWith('audio/')) {
      iconData = Icons.audiotrack_outlined;
    } else if (mimeType == 'application/pdf') {
      iconData = Icons.picture_as_pdf_outlined;
    } else {
      iconData = Icons.insert_drive_file_outlined;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(iconData, size: 50),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Browser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Directory',
            onPressed: _pickDirectory,
          ),
        ],
      ),
      body: _selectedDirectory == null
          ? Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Media Directory'),
                onPressed: _pickDirectory,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _mediaFiles.isEmpty
                  ? const Center(child: Text('No media files found in the selected directory.'))
                  : ListView.builder(
                      itemCount: _mediaFiles.keys.length,
                      itemBuilder: (context, index) {
                        final String mimeType = _mediaFiles.keys.elementAt(index);
                        final List<FileSystemEntity> files = _mediaFiles[mimeType]!;
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
                    ),
    );
  }
}
