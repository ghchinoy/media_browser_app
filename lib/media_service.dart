import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:watcher/watcher.dart';
import 'package:logging/logging.dart';

final _logger = Logger('MediaService');

/// High-level categories for grouping and filtering media files.
enum MediaCategory {
  all,
  image,
  video,
  audio,
  document,
  code,
  other;

  String get displayName {
    switch (this) {
      case MediaCategory.all:
        return 'All';
      case MediaCategory.image:
        return 'Images';
      case MediaCategory.video:
        return 'Videos';
      case MediaCategory.audio:
        return 'Audio';
      case MediaCategory.document:
        return 'Documents';
      case MediaCategory.code:
        return 'Code & Text';
      case MediaCategory.other:
        return 'Other';
    }
  }
}

/// Sort options for media files.
enum SortOption {
  dateModifiedDesc('Date Modified (Newest)'),
  dateModifiedAsc('Date Modified (Oldest)'),
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  sizeDesc('Size (Largest)'),
  sizeAsc('Size (Smallest)'),
  type('File Type');

  final String label;
  const SortOption(this.label);
}

/// Helper function to determine the [MediaCategory] from file path and optional MIME type.
MediaCategory determineCategory(String filePath, [String? explicitMimeType]) {
  final mime = explicitMimeType ?? lookupMimeType(filePath) ?? '';
  final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();

  if (mime.startsWith('image/')) return MediaCategory.image;
  if (mime.startsWith('video/')) return MediaCategory.video;
  if (mime.startsWith('audio/')) return MediaCategory.audio;

  // Documents
  const docExts = {
    'pdf',
    'doc',
    'docx',
    'odt',
    'rtf',
    'pages',
    'xls',
    'xlsx',
    'numbers',
    'csv',
    'ppt',
    'pptx',
    'key',
    'epub',
  };
  if (mime == 'application/pdf' || docExts.contains(ext)) {
    return MediaCategory.document;
  }

  // Code & text
  const codeExts = {
    'txt',
    'md',
    'markdown',
    'json',
    'yaml',
    'yml',
    'xml',
    'log',
    'dart',
    'js',
    'jsx',
    'ts',
    'tsx',
    'py',
    'html',
    'htm',
    'css',
    'scss',
    'sh',
    'bash',
    'zsh',
    'swift',
    'kt',
    'kts',
    'java',
    'rs',
    'go',
    'c',
    'cpp',
    'h',
    'hpp',
    'sql',
    'toml',
    'ini',
    'cfg',
    'conf',
    'gradle',
  };
  if (mime.startsWith('text/') || mime == 'application/json' || codeExts.contains(ext)) {
    return MediaCategory.code;
  }

  return MediaCategory.other;
}

/// Holds a file entity and its cached metadata.
class MediaFile {
  final FileSystemEntity file;
  final FileStat stat;
  final Uint8List? bytes;
  final String mimeType;
  final MediaCategory category;

  MediaFile(
    this.file,
    this.stat, [
    this.bytes,
    String? explicitMimeType,
    MediaCategory? explicitCategory,
  ])  : mimeType = explicitMimeType ?? lookupMimeType(file.path) ?? 'application/octet-stream',
        category = explicitCategory ?? determineCategory(file.path, explicitMimeType);

  String get name => p.basename(file.path);
  String get extension => p.extension(file.path).replaceFirst('.', '').toLowerCase();
  int get size => stat.size;
  DateTime get modified => stat.modified;
}

/// Represents a node in the directory tree hierarchy.
class DirectoryNode {
  final Directory directory;
  final List<DirectoryNode> children;
  bool isExpanded;

  DirectoryNode(this.directory, this.children, {this.isExpanded = false});

  String get name => p.basename(directory.path);
}

/// Holds all scanned media data for a directory.
class MediaData {
  final Map<String, List<MediaFile>> mediaFiles;
  final DirectoryNode? directoryTree;

  MediaData(this.mediaFiles, this.directoryTree);

  /// Flat list of all media files found.
  List<MediaFile> get allFiles {
    final list = <MediaFile>[];
    for (final files in mediaFiles.values) {
      list.addAll(files);
    }
    return list;
  }
}

/// Sort a list of [MediaFile]s according to a [SortOption].
List<MediaFile> sortMediaFiles(List<MediaFile> files, SortOption option) {
  final list = List<MediaFile>.from(files);
  switch (option) {
    case SortOption.nameAsc:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      break;
    case SortOption.nameDesc:
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      break;
    case SortOption.dateModifiedDesc:
      list.sort((a, b) {
        final cmp = b.modified.compareTo(a.modified);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case SortOption.dateModifiedAsc:
      list.sort((a, b) {
        final cmp = a.modified.compareTo(b.modified);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case SortOption.sizeDesc:
      list.sort((a, b) {
        final cmp = b.size.compareTo(a.size);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case SortOption.sizeAsc:
      list.sort((a, b) {
        final cmp = a.size.compareTo(b.size);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case SortOption.type:
      list.sort((a, b) {
        final cmp = a.extension.compareTo(b.extension);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
  }
  return list;
}

/// Loads all media files from the given path without loading full image bytes into memory.
Future<Map<String, List<MediaFile>>> _loadMediaFiles(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw FileSystemException("Directory does not exist", path);
  }

  final Map<String, List<MediaFile>> categorizedFiles = {};
  try {
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      try {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.')) {
            // Ignore hidden files like .DS_Store, .git, etc.
            continue;
          }
          final mimeType = lookupMimeType(entity.path) ?? 'application/octet-stream';
          final category = determineCategory(entity.path, mimeType);

          final stat = await entity.stat();
          // We intentionally avoid eager readAsBytes() to ensure ultra-low memory usage
          // and fast directory loading. Images decode lazily on-demand in the UI.
          final mediaFile = MediaFile(entity, stat, null, mimeType, category);

          final groupKey = mimeType.startsWith('image/')
              ? 'Images (${mimeType.split('/').last.toUpperCase()})'
              : mimeType.startsWith('video/')
                  ? 'Videos (${mimeType.split('/').last.toUpperCase()})'
                  : mimeType.startsWith('audio/')
                      ? 'Audio (${mimeType.split('/').last.toUpperCase()})'
                      : category == MediaCategory.document
                          ? 'Documents'
                          : category == MediaCategory.code
                              ? 'Code & Text'
                              : 'Other';

          categorizedFiles.putIfAbsent(groupKey, () => []).add(mediaFile);
        }
      } catch (e) {
        _logger.warning("Error processing file ${entity.path}: $e");
      }
    }

    categorizedFiles.forEach((key, value) {
      value.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
    });

    final sortedCategorizedFiles = Map.fromEntries(
      categorizedFiles.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key)),
    );
    return sortedCategorizedFiles;
  } catch (e) {
    _logger.severe("Error loading media files: $e");
    throw FileSystemException("Error loading media files", path, e as OSError?);
  }
}

/// Recursively builds a directory tree from the given directory.
Future<DirectoryNode> _buildNode(Directory dir) async {
  final List<DirectoryNode> children = [];
  try {
    final List<FileSystemEntity> entities = await dir.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is Directory) {
        final dirName = p.basename(entity.path);
        if (!dirName.startsWith('.')) {
          children.add(await _buildNode(entity));
        }
      }
    }
    children.sort(
      (a, b) => a.directory.path.toLowerCase().compareTo(b.directory.path.toLowerCase()),
    );
  } catch (e) {
    _logger.warning("Error building directory node for ${dir.path}: $e");
  }
  return DirectoryNode(dir, children);
}

/// Builds a directory hierarchy from the given root path.
Future<DirectoryNode?> _buildDirectoryHierarchy(String rootPath) async {
  final rootDir = Directory(rootPath);
  if (await rootDir.exists()) {
    return _buildNode(rootDir);
  }
  return null;
}

/// Loads all media data from the given path in a background isolate.
Future<MediaData> loadAllMediaData(String path) async {
  final mediaFiles = await _loadMediaFiles(path);
  final directoryTree = await _buildDirectoryHierarchy(path);
  return MediaData(mediaFiles, directoryTree);
}

/// In-memory LRU-style cache for generated video thumbnails.
class VideoThumbnailCache {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> getThumbnail(String videoPath) async {
    if (_cache.containsKey(videoPath)) {
      return _cache[videoPath];
    }
    try {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 240,
        quality: 40,
      );
      if (thumbnailBytes != null) {
        if (_cache.length > 200) {
          _cache.remove(_cache.keys.first);
        }
        _cache[videoPath] = thumbnailBytes;
      }
      return thumbnailBytes;
    } catch (e) {
      _logger.severe("Error generating video thumbnail for $videoPath: $e");
      return null;
    }
  }

  static void clear() {
    _cache.clear();
  }
}

/// A service class for handling media-related operations and filesystem watching.
class MediaService {
  StreamSubscription<WatchEvent>? _directoryWatcherSubscription;

  /// Watches the given directory for changes and returns a stream of events.
  Stream<void> watchDirectory(String path) {
    _directoryWatcherSubscription?.cancel();
    final controller = StreamController<void>();
    final watcher = DirectoryWatcher(path);

    _directoryWatcherSubscription = watcher.events.listen(
      (event) {
        controller.add(null);
      },
      onError: (error) {
        _logger.severe("Error in directory watcher stream: $error");
        controller.addError(error);
      },
      onDone: () {
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Disposes of the resources used by the service.
  void dispose() {
    _directoryWatcherSubscription?.cancel();
  }
}