import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_browser_app/media_service.dart';

void main() {
  group('MediaCategory & determineCategory tests', () {
    test('categorizes images properly', () {
      expect(determineCategory('/photos/vacation.jpg'), MediaCategory.image);
      expect(determineCategory('/photos/logo.png'), MediaCategory.image);
      expect(determineCategory('/photos/graphic.webp'), MediaCategory.image);
      expect(determineCategory('/photos/image.gif'), MediaCategory.image);
    });

    test('categorizes videos properly', () {
      expect(determineCategory('/videos/clip.mp4'), MediaCategory.video);
      expect(determineCategory('/videos/movie.mov'), MediaCategory.video);
      expect(determineCategory('/videos/stream.mkv'), MediaCategory.video);
    });

    test('categorizes audio properly', () {
      expect(determineCategory('/music/song.mp3'), MediaCategory.audio);
      expect(determineCategory('/music/track.wav'), MediaCategory.audio);
      expect(determineCategory('/music/audio.flac'), MediaCategory.audio);
      expect(determineCategory('/music/podcast.m4a'), MediaCategory.audio);
    });

    test('categorizes documents properly', () {
      expect(determineCategory('/docs/report.pdf'), MediaCategory.document);
      expect(determineCategory('/docs/resume.docx'), MediaCategory.document);
      expect(determineCategory('/docs/sheet.xlsx'), MediaCategory.document);
      expect(determineCategory('/docs/data.csv'), MediaCategory.document);
    });

    test('categorizes code and markup properly', () {
      expect(determineCategory('/code/main.dart'), MediaCategory.code);
      expect(determineCategory('/code/index.js'), MediaCategory.code);
      expect(determineCategory('/code/server.py'), MediaCategory.code);
      expect(determineCategory('/code/config.json'), MediaCategory.code);
      expect(determineCategory('/code/readme.md'), MediaCategory.code);
      expect(determineCategory('/code/spec.yaml'), MediaCategory.code);
      expect(determineCategory('/code/app.log'), MediaCategory.code);
    });

    test('categorizes unknown files as other', () {
      expect(determineCategory('/files/unknown.bin'), MediaCategory.other);
      expect(determineCategory('/files/archive.xyz123'), MediaCategory.other);
    });
  });

  group('SortOption and sortMediaFiles tests', () {
    late Directory tempDir;
    late List<MediaFile> testFiles;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('media_browser_test_');

      final fileA = File('${tempDir.path}/alpha.png');
      await fileA.writeAsString('small');
      final statA = await fileA.stat();

      final fileB = File('${tempDir.path}/beta.mp4');
      await fileB.writeAsString('medium medium');
      final statB = await fileB.stat();

      final fileC = File('${tempDir.path}/charlie.dart');
      await fileC.writeAsString('large large large large');
      final statC = await fileC.stat();

      testFiles = [
        MediaFile(fileB, statB),
        MediaFile(fileA, statA),
        MediaFile(fileC, statC),
      ];
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('sorts by name ascending', () {
      final sorted = sortMediaFiles(testFiles, SortOption.nameAsc);
      expect(sorted.map((f) => f.name).toList(), ['alpha.png', 'beta.mp4', 'charlie.dart']);
    });

    test('sorts by name descending', () {
      final sorted = sortMediaFiles(testFiles, SortOption.nameDesc);
      expect(sorted.map((f) => f.name).toList(), ['charlie.dart', 'beta.mp4', 'alpha.png']);
    });

    test('sorts by size ascending', () {
      final sorted = sortMediaFiles(testFiles, SortOption.sizeAsc);
      expect(sorted.first.name, 'alpha.png');
      expect(sorted.last.name, 'charlie.dart');
    });

    test('sorts by size descending', () {
      final sorted = sortMediaFiles(testFiles, SortOption.sizeDesc);
      expect(sorted.first.name, 'charlie.dart');
      expect(sorted.last.name, 'alpha.png');
    });

    test('sorts by type (extension)', () {
      final sorted = sortMediaFiles(testFiles, SortOption.type);
      expect(sorted.map((f) => f.extension).toList(), ['dart', 'mp4', 'png']);
    });
  });
}
