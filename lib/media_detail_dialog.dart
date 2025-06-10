import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'dart:math'; // For log and pow in _formatFileSize
// For Uint8List, though not directly used here, good for consistency
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mime/mime.dart'; // To determine mimeType again if needed, or pass it
import 'package:flutter_markdown/flutter_markdown.dart'; // Import for Markdown rendering
import 'package:flutter_syntax_view/flutter_syntax_view.dart'; // Import for Syntax Highlighting

import 'fullscreen_video_player.dart';

// A dialog that displays media content and metadata for a given file.
class MediaDetailDialog extends StatefulWidget {
  final FileSystemEntity fileEntity;
  final ThemeMode currentThemeMode;

  const MediaDetailDialog({
    super.key,
    required this.fileEntity,
    required this.currentThemeMode,
  });

  @override
  State<MediaDetailDialog> createState() => _MediaDetailDialogState();
}

// The state for the media detail dialog.
class _MediaDetailDialogState extends State<MediaDetailDialog> {
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

  String get mimeType => lookupMimeType(widget.fileEntity.path) ?? 'unknown';
  File get file => File(widget.fileEntity.path);

  @override
  void initState() {
    super.initState();
    _loadMetadata();

    if (mimeType.startsWith('video/')) {
      _videoController = VideoPlayerController.file(file)
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {}); // When initialized, rebuild to show video
                _videoController?.play();
              }
            })
            .catchError((error) {
              if (mounted) {
                setState(() {
                  _errorLoadingMetadata = "Error loading video: $error";
                });
              }
              print("Error initializing video player: $error");
            });
    } else if (mimeType.startsWith('audio/')) {
      _audioPlayer = AudioPlayer();
      _playerStateSubscription = _audioPlayer?.onPlayerStateChanged.listen((
        PlayerState s,
      ) {
        if (mounted) {
          setState(() {
            _audioPlayerState = s;
            _isAudioPlaying = s == PlayerState.playing;
          });
        }
      });
      _durationSubscription = _audioPlayer?.onDurationChanged.listen((
        Duration d,
      ) {
        if (mounted) {
          setState(() => _audioDuration = d);
        }
      });
      _positionSubscription = _audioPlayer?.onPositionChanged.listen((
        Duration p,
      ) {
        if (mounted) {
          setState(() => _audioPosition = p);
        }
      });
    }

    // Load text content for JSON, text, or markdown files
    if (mimeType == 'application/json' ||
        mimeType.startsWith('text/') ||
        file.path.toLowerCase().endsWith('.md')) {
      _loadTextContent();
    }

    // Initialize scroll controller specifically for the text/markdown path that uses MarkdownBody + SingleChildScrollView
    // JSON will use SyntaxView which handles its own scrolling.
    if ((mimeType.startsWith('text/') ||
            file.path.toLowerCase().endsWith('.md')) &&
        mimeType != 'application/json') {
      _textScrollController = ScrollController();
    }
  }

  // Loads the text content of the file.
  Future<void> _loadTextContent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTextContent = true;
      _errorLoadingTextContent = '';
    });
    try {
      final content = await file.readAsString();
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
      print("Error reading text file ${file.path}: $e");
    }
  }

  // Loads the metadata for the file.
  Future<void> _loadMetadata() async {
    try {
      if (widget.fileEntity is File) {
        _fileStat = await file.stat();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorLoadingMetadata = "Error loading metadata: $e";
        });
      }
      print("Error loading file stats: $e");
    }
    if (mounted) {
      setState(() {
        _isLoadingMetadata = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose(); // dispose() also handles releasing resources
    _textScrollController?.dispose();
    super.dispose();
  }

  // Formats the size of the file into a human-readable string.
  String _formatFileSize(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Formats a duration into a string in the format `mm:ss`.
  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Plays the audio file.
  Future<void> _playAudio() async {
    if (_audioPlayer != null && file.existsSync()) {
      try {
        await _audioPlayer?.play(DeviceFileSource(file.path));
        if (mounted) setState(() => _isAudioPlaying = true);
      } catch (e) {
        print("Error playing audio: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error playing audio: $e")));
        }
      }
    }
  }

  // Pauses the audio file.
  Future<void> _pauseAudio() async {
    await _audioPlayer?.pause();
    if (mounted) setState(() => _isAudioPlaying = false);
  }

  // Stops the audio file.
  Future<void> _stopAudio() async {
    await _audioPlayer?.stop();
    if (mounted) setState(() => _isAudioPlaying = false);
  }

  // Builds the content of the media detail dialog.
  Widget _buildMediaContent() {
    if (mimeType.startsWith('image/')) {
      return InteractiveViewer(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('Error loading image')),
        ),
      );
    } else if (mimeType.startsWith('video/')) {
      if (_videoController?.value.isInitialized ?? false) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            VideoProgressIndicator(_videoController!, allowScrubbing: true),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _videoController!,
              builder: (context, value, child) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(_formatDuration(value.position)),
                          Text(_formatDuration(value.duration)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
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
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    FullscreenVideoPlayer(controller: _videoController!),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            )
          ],
        );
      } else if (_videoController?.value.hasError ?? false) {
        return Center(
          child: Text(
            'Error loading video: ${_videoController?.value.errorDescription}',
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    } else if (mimeType.startsWith('audio/')) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 100),
          const SizedBox(height: 10),
          if (_audioDuration != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              value:
                  (_audioPosition != null &&
                      _audioDuration != null &&
                      _audioDuration!.inMilliseconds > 0)
                  ? (_audioPosition!.inMilliseconds /
                            _audioDuration!.inMilliseconds)
                        .clamp(0.0, 1.0)
                  : 0.0,
              onChanged: (value) {
                if (_audioDuration != null) {
                  final position = Duration(
                    milliseconds: (value * _audioDuration!.inMilliseconds)
                        .round(),
                  );
                  _audioPlayer?.seek(position);
                }
              },
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isAudioPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _isAudioPlaying ? _pauseAudio : _playAudio,
              ),
              IconButton(icon: const Icon(Icons.stop), onPressed: _stopAudio),
            ],
          ),
          if (_audioPlayerState != null)
            Text('Status: ${_audioPlayerState.toString().split('.').last}'),
        ],
      );
    } else if (mimeType == 'application/json') {
      if (_isLoadingTextContent) {
        return const Center(child: CircularProgressIndicator());
      } else if (_errorLoadingTextContent.isNotEmpty) {
        return Center(
          child: Text(
            _errorLoadingTextContent,
            style: const TextStyle(color: Colors.red),
          ),
        );
      } else if (_textContent != null) {
        return SyntaxView(
          code: _textContent!,
          syntax: Syntax.JAVASCRIPT,
          syntaxTheme: widget.currentThemeMode == ThemeMode.dark
              ? SyntaxTheme.vscodeDark()
              : SyntaxTheme.vscodeLight(),
          expanded: true, // Fills available space and handles scrolling
          withLinesCount: true,
          selectable: true,
        );
      }
      return const Center(child: Text('Loading JSON content...'));
    } else if (mimeType.startsWith('text/') ||
        file.path.toLowerCase().endsWith('.md')) {
      if (_isLoadingTextContent) {
        return const Center(child: CircularProgressIndicator());
      } else if (_errorLoadingTextContent.isNotEmpty) {
        return Center(
          child: Text(
            _errorLoadingTextContent,
            style: const TextStyle(color: Colors.red),
          ),
        );
      } else if (_textContent != null) {
        return Scrollbar(
          controller: _textScrollController,
          thumbVisibility: true, // Makes the scrollbar always visible
          child: SingleChildScrollView(
            controller: _textScrollController,
            padding: const EdgeInsets.all(8.0),
            child: MarkdownBody(
              data: _textContent!,
              selectable: true, // Allows text selection
            ),
          ),
        );
      }
      return const Center(
        child: Text('Loading content...'),
      ); // Fallback if text content is expected but not loaded
    }
    return const Center(child: Text('Unsupported file type for preview'));
  }

  @override
  Widget build(BuildContext context) {
    final String fileName = widget.fileEntity.path
        .split(Platform.pathSeparator)
        .last;

    return AlertDialog(
      title: Text(fileName, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Attempt to make dialog wider and taller for media
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                // Allows the media content to take available space
                child: Center(
                  // Center the media content
                  child: _buildMediaContent(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_isLoadingMetadata)
                const CircularProgressIndicator()
              else if (_errorLoadingMetadata.isNotEmpty)
                Text(
                  _errorLoadingMetadata,
                  style: const TextStyle(color: Colors.red),
                )
              else if (_fileStat != null) ...[
                Text('Path: ${widget.fileEntity.path}'),
                Text('Size: ${_formatFileSize(_fileStat!.size)}'),
                Text(
                  'Last Modified: ${DateFormat.yMd().add_jms().format(_fileStat!.modified)}',
                ),
                Text('MIME Type: $mimeType'),
              ] else
                const Text('Could not load file details.'),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}