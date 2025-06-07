import 'dart:async';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:watcher/watcher.dart';

import 'dart:typed_data';

// Helper class to hold a file and its stats
class MediaFile {
  final FileSystemEntity file;
  final FileStat stat;
  final Uint8List? bytes;

  MediaFile(this.file, this.stat, this.bytes);
}

// Helper class for the directory tree structure
class DirectoryNode {
  final Directory directory;
  final List<DirectoryNode> children;
  bool isExpanded; // To manage expansion state in the UI

  DirectoryNode(this.directory, this.children, {this.isExpanded = false});
}

class MediaData {
  final Map<String, List<MediaFile>> mediaFiles;
  final DirectoryNode? directoryTree;

  MediaData(this.mediaFiles, this.directoryTree);
}

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

Future<DirectoryNode?> _buildDirectoryHierarchy(String rootPath) async {
  final rootDir = Directory(rootPath);
  if (await rootDir.exists()) {
    return _buildNode(rootDir);
  }
  return null;
}

Future<MediaData> loadAllMediaData(String path) async {
  final mediaFiles = await _loadMediaFiles(path);
  final directoryTree = await _buildDirectoryHierarchy(path);
  return MediaData(mediaFiles, directoryTree);
}

class MediaService {
  StreamSubscription<WatchEvent>? _directoryWatcherSubscription;

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

  void dispose() {
    _directoryWatcherSubscription?.cancel();
  }
}