import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mime/mime.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_syntax_view/flutter_syntax_view.dart';
import 'package:logging/logging.dart';

import 'fullscreen_video_player.dart';
import 'media_service.dart';

final _logger = Logger('MediaDetailDialog');

/// A modern Lightbox dialog that displays media content, metadata, and supports next/previous navigation.
class MediaDetailDialog extends StatefulWidget {
  final FileSystemEntity fileEntity;
  final List<MediaFile>? fileList;
  final int? initialIndex;
  final ThemeMode currentThemeMode;

  const MediaDetailDialog({
    super.key,
    required this.fileEntity,
    this.fileList,
    this.initialIndex,
    required this.currentThemeMode,
  });

  @override
  State<MediaDetailDialog> createState() => _MediaDetailDialogState();
}

class _MediaDetailDialogState extends State<MediaDetailDialog> {
  late int _currentIndex;
  late List<FileSystemEntity> _files;

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  PlayerState? _audioPlayerState;
  bool _isAudioPlaying = false;
  Duration? _audioDuration;
  Duration? _audioPosition;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  FileStat? _fileStat;
  bool _isLoadingMetadata = true;
  String _errorLoadingMetadata = '';

  String? _textContent;
  bool _isLoadingTextContent = false;
  String _errorLoadingTextContent = '';
  ScrollController? _textScrollController;
  bool _showDetails = false;

  FileSystemEntity get _currentEntity => _files[_currentIndex];
  File get _currentFile => File(_currentEntity.path);
  String get _mimeType => lookupMimeType(_currentEntity.path) ?? 'application/octet-stream';
  String get _fileName => _currentEntity.path.split(Platform.pathSeparator).last;
  String get _extension => _currentEntity.path.contains('.')
      ? _currentEntity.path.split('.').last.toLowerCase()
      : '';

  @override
  void initState() {
    super.initState();
    if (widget.fileList != null && widget.fileList!.isNotEmpty) {
      _files = widget.fileList!.map((m) => m.file).toList();
      _currentIndex = widget.initialIndex ??
          _files.indexWhere((f) => f.path == widget.fileEntity.path);
      if (_currentIndex < 0) _currentIndex = 0;
    } else {
      _files = [widget.fileEntity];
      _currentIndex = 0;
    }

    _initCurrentMedia();
  }

  void _initCurrentMedia() {
    _disposeActiveControllers();
    _loadMetadata();

    final mime = _mimeType;
    final file = _currentFile;

    if (mime.startsWith('video/')) {
      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _errorLoadingMetadata = "Error loading video: $error";
            });
          }
          _logger.severe("Error initializing video player: $error");
        });
    } else if (mime.startsWith('audio/')) {
      _audioPlayer = AudioPlayer();
      _playerStateSubscription = _audioPlayer?.onPlayerStateChanged.listen((s) {
        if (mounted) {
          setState(() {
            _audioPlayerState = s;
            _isAudioPlaying = s == PlayerState.playing;
          });
        }
      });
      _durationSubscription = _audioPlayer?.onDurationChanged.listen((d) {
        if (mounted) {
          setState(() => _audioDuration = d);
        }
      });
      _positionSubscription = _audioPlayer?.onPositionChanged.listen((p) {
        if (mounted) {
          setState(() => _audioPosition = p);
        }
      });
    }

    final isTextOrCode = mime.startsWith('text/') ||
        mime == 'application/json' ||
        ['md', 'markdown', 'json', 'yaml', 'yml', 'xml', 'log', 'dart', 'js', 'ts', 'py', 'sh', 'html', 'css', 'swift', 'kt', 'java', 'rs', 'go', 'sql', 'toml']
            .contains(_extension);

    if (isTextOrCode) {
      _loadTextContent();
      _textScrollController = ScrollController();
    }
  }

  void _disposeActiveControllers() {
    _videoController?.dispose();
    _videoController = null;
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _textScrollController?.dispose();
    _textScrollController = null;
    _textContent = null;
    _isAudioPlaying = false;
    _audioDuration = null;
    _audioPosition = null;
  }

  Future<void> _loadTextContent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTextContent = true;
      _errorLoadingTextContent = '';
    });
    try {
      final content = await _currentFile.readAsString();
      if (mounted) {
        setState(() {
          _textContent = content;
          _isLoadingTextContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorLoadingTextContent = "Error reading file content: $e";
          _isLoadingTextContent = false;
        });
      }
      _logger.severe("Error reading text file ${_currentFile.path}: $e");
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final stat = await _currentFile.stat();
      if (mounted) {
        setState(() {
          _fileStat = stat;
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorLoadingMetadata = "Error loading metadata: $e";
          _isLoadingMetadata = false;
        });
      }
      _logger.severe("Error loading file stats: $e");
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _initCurrentMedia();
    }
  }

  void _goToNext() {
    if (_currentIndex < _files.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initCurrentMedia();
    }
  }

  @override
  void dispose() {
    _disposeActiveControllers();
    super.dispose();
  }

  String _formatFileSize(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _playAudio() async {
    if (_audioPlayer != null && _currentFile.existsSync()) {
      try {
        await _audioPlayer?.play(DeviceFileSource(_currentFile.path));
        if (mounted) setState(() => _isAudioPlaying = true);
      } catch (e) {
        _logger.severe("Error playing audio: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error playing audio: $e")),
          );
        }
      }
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer?.pause();
    if (mounted) setState(() => _isAudioPlaying = false);
  }

  Future<void> _stopAudio() async {
    await _audioPlayer?.stop();
    if (mounted) setState(() => _isAudioPlaying = false);
  }

  void _revealInFinder() {
    final path = _currentFile.path;
    if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [_currentFile.parent.path]);
    }
  }

  void _openInDefaultApp() {
    final path = _currentFile.path;
    if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  void _copyPathToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentFile.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Syntax _detectSyntax(String ext) {
    switch (ext) {
      case 'dart':
        return Syntax.DART;
      case 'py':
        return Syntax.PYTHON;
      case 'rs':
        return Syntax.RUST;
      case 'swift':
        return Syntax.SWIFT;
      case 'kt':
      case 'kts':
        return Syntax.KOTLIN;
      case 'java':
        return Syntax.JAVA;
      case 'c':
      case 'h':
        return Syntax.C;
      case 'cpp':
      case 'hpp':
      case 'cc':
        return Syntax.CPP;
      case 'yaml':
      case 'yml':
        return Syntax.YAML;
      case 'lua':
        return Syntax.LUA;
      case 'json':
      case 'js':
      case 'ts':
      default:
        return Syntax.JAVASCRIPT;
    }
  }

  Widget _buildMediaContent() {
    final mime = _mimeType;
    final file = _currentFile;
    final ext = _extension;

    if (mime.startsWith('image/')) {
      return InteractiveViewer(
        maxScale: 5.0,
        minScale: 0.5,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey),
              SizedBox(height: 8),
              Text('Error loading image preview'),
            ],
          ),
        ),
      );
    } else if (mime.startsWith('video/')) {
      if (_videoController?.value.isInitialized ?? false) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
            const SizedBox(height: 8),
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _videoController!,
              builder: (context, value, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(value.position),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                            size: 32,
                          ),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                value.isPlaying
                                    ? _videoController!.pause()
                                    : _videoController!.play();
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: 'Full Screen',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FullscreenVideoPlayer(
                                  controller: _videoController!,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      _formatDuration(value.duration),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        );
      } else if (_videoController?.value.hasError ?? false) {
        return Center(
          child: Text('Error loading video: ${_videoController?.value.errorDescription}'),
        );
      }
      return const Center(child: CircularProgressIndicator());
    } else if (mime.startsWith('audio/')) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audiotrack,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          if (_audioDuration != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_audioPosition)),
                  Text(_formatDuration(_audioDuration)),
                ],
              ),
            ),
          if (_audioDuration != null)
            Slider(
              value: (_audioPosition != null &&
                      _audioDuration != null &&
                      _audioDuration!.inMilliseconds > 0)
                  ? (_audioPosition!.inMilliseconds / _audioDuration!.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0,
              onChanged: (value) {
                if (_audioDuration != null) {
                  final position = Duration(
                    milliseconds: (value * _audioDuration!.inMilliseconds).round(),
                  );
                  _audioPlayer?.seek(position);
                }
              },
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: Icon(_isAudioPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: _isAudioPlaying ? _pauseAudio : _playAudio,
              ),
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: _stopAudio,
              ),
            ],
          ),
          if (_audioPlayerState != null)
            Text(
              'Status: ${_audioPlayerState.toString().split('.').last}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      );
    } else if (ext == 'md' || ext == 'markdown') {
      if (_isLoadingTextContent) {
        return const Center(child: CircularProgressIndicator());
      } else if (_errorLoadingTextContent.isNotEmpty) {
        return Center(
          child: Text(_errorLoadingTextContent, style: const TextStyle(color: Colors.red)),
        );
      } else if (_textContent != null) {
        return Scrollbar(
          controller: _textScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _textScrollController,
            padding: const EdgeInsets.all(12.0),
            child: MarkdownBody(
              data: _textContent!,
              selectable: true,
            ),
          ),
        );
      }
      return const Center(child: Text('Loading markdown...'));
    } else if (mime == 'application/json' ||
        mime.startsWith('text/') ||
        ['yaml', 'yml', 'xml', 'log', 'dart', 'js', 'ts', 'py', 'sh', 'html', 'css', 'swift', 'kt', 'java', 'rs', 'go', 'sql', 'toml']
            .contains(ext)) {
      if (_isLoadingTextContent) {
        return const Center(child: CircularProgressIndicator());
      } else if (_errorLoadingTextContent.isNotEmpty) {
        return Center(
          child: Text(_errorLoadingTextContent, style: const TextStyle(color: Colors.red)),
        );
      } else if (_textContent != null) {
        return SyntaxView(
          code: _textContent!,
          syntax: _detectSyntax(ext),
          syntaxTheme: widget.currentThemeMode == ThemeMode.dark
              ? SyntaxTheme.vscodeDark()
              : SyntaxTheme.vscodeLight(),
          expanded: true,
          withLinesCount: true,
          selectable: true,
        );
      }
      return const Center(child: Text('Loading content...'));
    } else if (mime == 'application/pdf' || ext == 'pdf') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _fileName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with Default PDF Viewer'),
            onPressed: _openInDefaultApp,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _fileName,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in External App'),
          onPressed: _openInDefaultApp,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = _files.length > 1;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrevious();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: min(MediaQuery.of(context).size.width * 0.88, 1100),
          height: min(MediaQuery.of(context).size.height * 0.85, 800),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasMultiple)
                            Text(
                              '${_currentIndex + 1} of ${_files.length}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy File Path',
                      onPressed: _copyPathToClipboard,
                    ),
                    if (Platform.isMacOS)
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 20),
                        tooltip: 'Reveal in Finder',
                        onPressed: _revealInFinder,
                      ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      tooltip: 'Open in Default App',
                      onPressed: _openInDefaultApp,
                    ),
                    IconButton(
                      icon: Icon(
                        _showDetails ? Icons.info : Icons.info_outline,
                        size: 20,
                        color: _showDetails ? Theme.of(context).colorScheme.primary : null,
                      ),
                      tooltip: 'Toggle Metadata Details',
                      onPressed: () {
                        setState(() {
                          _showDetails = !_showDetails;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close (Esc)',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Main Viewer with Navigation Buttons
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildMediaContent(),
                      ),
                    ),
                    // Prev Button
                    if (hasMultiple && _currentIndex > 0)
                      Positioned(
                        left: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton.filledTonal(
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 32,
                            tooltip: 'Previous (Left Arrow)',
                            onPressed: _goToPrevious,
                          ),
                        ),
                      ),
                    // Next Button
                    if (hasMultiple && _currentIndex < _files.length - 1)
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton.filledTonal(
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 32,
                            tooltip: 'Next (Right Arrow)',
                            onPressed: _goToNext,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Expandable Metadata Inspector
              if (_showDetails)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: _isLoadingMetadata
                      ? const Center(child: CircularProgressIndicator())
                      : _fileStat != null
                          ? Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              children: [
                                _detailItem('Path', _currentEntity.path),
                                _detailItem('Size', _formatFileSize(_fileStat!.size)),
                                _detailItem(
                                  'Modified',
                                  DateFormat.yMMMd().add_jm().format(_fileStat!.modified),
                                ),
                                _detailItem('MIME Type', _mimeType),
                              ],
                            )
                          : Text(
                              _errorLoadingMetadata.isNotEmpty
                                  ? _errorLoadingMetadata
                                  : 'Could not load metadata',
                              style: const TextStyle(color: Colors.red),
                            ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}