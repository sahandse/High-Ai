import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/services/model_download_manager.dart';

void main() {
  group('DownloadProgress', () {
    test('computes fraction and percent', () {
      const progress = DownloadProgress(
        downloadedBytes: 250,
        totalBytes: 1000,
        bytesPerSecond: 100,
      );
      expect(progress.fraction, 0.25);
      expect(progress.percent, 25);
    });

    test('eta is null when speed is zero', () {
      const progress = DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 1000,
        bytesPerSecond: 0,
      );
      expect(progress.eta, isNull);
    });

    test('eta reflects remaining bytes over speed', () {
      const progress = DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 1000,
        bytesPerSecond: 100,
      );
      expect(progress.eta, const Duration(seconds: 10));
    });
  });

  group('ModelDownloadManager', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('model_download_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('a plain destination file is reported installed', () async {
      final manager = ModelDownloadManager();
      final path = '${tempDir.path}/model.litertlm';
      await File(path).writeAsString('fake model bytes');

      expect(await manager.isInstalled(path), isTrue);
      expect(await manager.hasResumableDownload(path), isFalse);
    });

    test('a .part file alone is never treated as installed', () async {
      final manager = ModelDownloadManager();
      final path = '${tempDir.path}/model.litertlm';
      await File('$path.part').writeAsString('only half here');

      expect(await manager.isInstalled(path), isFalse);
      expect(await manager.hasResumableDownload(path), isTrue);
    });

    test('delete removes both the final file and any partial file', () async {
      final manager = ModelDownloadManager();
      final path = '${tempDir.path}/model.litertlm';
      await File(path).writeAsString('bytes');
      await File('$path.part').writeAsString('leftover');

      await manager.delete(path);

      expect(await File(path).exists(), isFalse);
      expect(await File('$path.part').exists(), isFalse);
    });
  });
}
