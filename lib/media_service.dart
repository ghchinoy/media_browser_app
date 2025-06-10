import 'dart:async';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:watcher/watcher.dart';

import 'dart:typed_data';

// A class to hold a file and its associated metadata.
class MediaFile {
  final FileSystemEntity file;
  final FileStat stat;
  final Uint8List? bytes;

  MediaFile(this.file, this.stat, this.bytes);
}

// A class to represent a node in the directory tree.
class DirectoryNode {
  final Directory directory;
  final List<DirectoryNode> children;
  bool isExpanded;

  DirectoryNode(this.directory, this.children, {this.isExpanded = false});
}

// A class to hold all the media data for a given directory.
class MediaData {
  final Map<String, List<MediaFile>> mediaFiles;
  final DirectoryNode? directoryTree;

  MediaData(this.mediaFiles, this.directoryTree);
}

// Loads all media files from the given path and returns them as a map of MIME type to a list of files.
Future<Map<String, List<MediaFile>>> _loadMediaFiles(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw FileSystemException("Directory does not exist", path);
  }

  final Map<String, List<MediaFile>> categorizedFiles = {};
  try {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        if (entity.path.split(Platform.pathSeparator).last == '.DS_Store') {
          continue;
        }
        final mimeType = lookupMimeType(entity.path) ?? 'unknown';
        if (mimeType.startsWith('application/') || mimeType == 'unknown') {
          continue;
        }
        final stat = await entity.stat();
        Uint8List? bytes;
        if (mimeType.startsWith('image/')) {
          bytes = await entity.readAsBytes();
        }
        categorizedFiles
            .putIfAbsent(mimeType, () => [])
            .add(MediaFile(entity, stat, bytes));
      }
    }

    categorizedFiles.forEach((key, value) {
      value.sort((a, b) {
        int comparisonResult = b.stat.modified.compareTo(a.stat.modified);
        if (comparisonResult == 0) {
          return a.file.path.toLowerCase().compareTo(b.file.path.toLowerCase());
        }
        return comparisonResult;
      });
    });

    final sortedCategorizedFiles = Map.fromEntries(
      categorizedFiles.entries.toList()
        ..sort((e1, e2) => e1.key.compareTo(e2.key)),
    );
    return sortedCategorizedFiles;
  } catch (e) {
    print("Error loading media files: $e");
    throw FileSystemException("Error loading media files", path, e as OSError?);
  }
}

// Recursively builds a directory tree from the given directory.
Future<DirectoryNode> _buildNode(Directory dir) async {
  final List<DirectoryNode> children = [];
  try {
    final List<FileSystemEntity> entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is Directory) {
        if (!entity.path.split(Platform.pathSeparator).last.startsWith('.')) {
          children.add(await _buildNode(entity));
        }
      }
    }
    children.sort(
      (a, b) =>
          a.directory.path.toLowerCase().compareTo(b.directory.path.toLowerCase()),
    );
  } catch (e) {
    print("Error building directory node for ${dir.path}: $e");
  }
  return DirectoryNode(dir, children);
}

// Builds a directory hierarchy from the given root path.
Future<DirectoryNode?> _buildDirectoryHierarchy(String rootPath) async {
  final rootDir = Directory(rootPath);
  if (await rootDir.exists()) {
    return _buildNode(rootDir);
  }
  return null;
}

// Loads all media data from the given path.
Future<MediaData> loadAllMediaData(String path) async {
  final mediaFiles = await _loadMediaFiles(path);
  final directoryTree = await _buildDirectoryHierarchy(path);
  return MediaData(mediaFiles, directoryTree);
}

// A service class for handling media-related operations.
class MediaService {
  StreamSubscription<WatchEvent>? _directoryWatcherSubscription;

  // Watches the given directory for changes and returns a stream of events.
  Stream<void> watchDirectory(String path) {
    _directoryWatcherSubscription?.cancel();
    final controller = StreamController<void>();
    final watcher = DirectoryWatcher(path);

    _directoryWatcherSubscription = watcher.events.listen(
      (event) {
        controller.add(null);
      },
      onError: (error) {
        print("Error in directory watcher stream: $error");
        controller.addError(error);
      },
      onDone: () {
        controller.close();
      }
    );

    return controller.stream;
  }

  // Disposes of the resources used by the service.
  void dispose() {
    _directoryWatcherSubscription?.cancel();
  }
}
