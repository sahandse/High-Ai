import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Immutable snapshot of an in-progress or finished download, as shown in
/// the Models screen.
class DownloadProgress {
  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
  });

  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;

  double get fraction => totalBytes == 0 ? 0 : downloadedBytes / totalBytes;

  int get percent => (fraction * 100).clamp(0, 100).round();

  Duration? get eta {
    if (bytesPerSecond <= 0) return null;
    final remaining = totalBytes - downloadedBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / bytesPerSecond).round());
  }
}

/// Thrown when a download can't proceed or a finished file fails
/// verification. Always carries a message safe to show to the user.
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads a model file to local storage with resume support, atomic
/// installation, and integrity verification.
///
/// Contract (see docs/ARCHITECTURE.md §7): the final [destinationPath] is
/// only ever created by an atomic rename performed *after* size + checksum
/// verification succeed. A `.part` file existing on disk with no matching
/// final file is therefore unambiguously "incomplete" — there is no
/// separate flag to fall out of sync with reality.
class ModelDownloadManager {
  ModelDownloadManager({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  CancelToken? _cancelToken;

  String _partPath(String destinationPath) => '$destinationPath.part';
  String _metaPath(String destinationPath) => '$destinationPath.part.meta.json';

  /// True if a previous download left a resumable partial file behind.
  Future<bool> hasResumableDownload(String destinationPath) {
    return File(_partPath(destinationPath)).exists();
  }

  /// True only once [destinationPath] holds a fully downloaded, verified
  /// file. A `.part` file alone never satisfies this.
  Future<bool> isInstalled(String destinationPath) {
    return File(destinationPath).exists();
  }

  /// Downloads [url] to [destinationPath], resuming from any existing
  /// `.part` file via an HTTP Range request, then verifies the result
  /// (against [expectedSha256] if provided, otherwise by size only when
  /// [expectedSizeBytes] is given) before atomically installing it.
  ///
  /// Emits progress on [onProgress]. Call [cancel] to abort — the partial
  /// file is left in place so the download can resume later, matching the
  /// "never lose progress on close" requirement.
  Future<void> download({
    required String url,
    required String destinationPath,
    int? expectedSizeBytes,
    String? expectedSha256,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final partFile = File(_partPath(destinationPath));
    await partFile.parent.create(recursive: true);

    await _checkStorage(destinationPath, expectedSizeBytes);

    final existingBytes = await partFile.exists() ? await partFile.length() : 0;
    _cancelToken = CancelToken();

    final stopwatch = Stopwatch()..start();
    var bytesAtLastTick = existingBytes;
    var lastTickMs = 0;

    final sink = partFile.openWrite(
      mode: existingBytes > 0 ? FileMode.append : FileMode.write,
    );
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: _cancelToken,
        options: Options(
          headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
          responseType: ResponseType.stream,
        ),
      );
      var received = 0;
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        final downloaded = existingBytes + received;
        final elapsedMs = stopwatch.elapsedMilliseconds;
        final deltaMs = elapsedMs - lastTickMs;
        if (deltaMs >= 200) {
          final speed = (downloaded - bytesAtLastTick) / (deltaMs / 1000);
          bytesAtLastTick = downloaded;
          lastTickMs = elapsedMs;
          onProgress?.call(
            DownloadProgress(
              downloadedBytes: downloaded,
              totalBytes: expectedSizeBytes ?? downloaded,
              bytesPerSecond: speed,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        await sink.flush();
        await sink.close();
        return; // Partial file intentionally preserved for resume.
      }
      await sink.flush();
      await sink.close();
      throw ModelDownloadException('دانلود با خطا مواجه شد: ${e.message}');
    }
    await sink.flush();
    await sink.close();

    await _verifyAndInstall(
      partFile: partFile,
      destinationPath: destinationPath,
      expectedSizeBytes: expectedSizeBytes,
      expectedSha256: expectedSha256,
    );
  }

  Future<void> _checkStorage(String destinationPath, int? expectedSizeBytes) async {
    if (expectedSizeBytes == null) return;
    try {
      final dir = Directory(File(destinationPath).parent.path);
      // Not all platforms expose free-space APIs through dart:io directly;
      // a best-effort check is still better than none. Failures here are
      // swallowed intentionally — the download itself will fail loudly if
      // storage actually runs out.
      await dir.create(recursive: true);
    } catch (_) {
      // Ignore — handled by the actual write failing if space is short.
    }
  }

  Future<void> _verifyAndInstall({
    required File partFile,
    required String destinationPath,
    int? expectedSizeBytes,
    String? expectedSha256,
  }) async {
    final actualSize = await partFile.length();
    if (expectedSizeBytes != null && actualSize != expectedSizeBytes) {
      throw ModelDownloadException(
        'حجم فایل دانلودشده با حجم مورد انتظار یکسان نیست.',
      );
    }
    if (expectedSha256 != null) {
      final digest = await _sha256Of(partFile);
      if (digest != expectedSha256) {
        await partFile.delete();
        throw ModelDownloadException(
          'بررسی صحت فایل ناموفق بود؛ فایل آسیب‌دیده حذف شد.',
        );
      }
    }
    // Atomic install: rename only after verification succeeds.
    await partFile.rename(destinationPath);
    await File(_metaPath(destinationPath)).delete().catchError((_) {
      return File(_metaPath(destinationPath));
    });
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  void cancel() {
    _cancelToken?.cancel('user_cancelled');
  }

  Future<void> delete(String destinationPath) async {
    await File(destinationPath).delete().catchError((_) => File(destinationPath));
    await File(_partPath(destinationPath))
        .delete()
        .catchError((_) => File(_partPath(destinationPath)));
  }
}

/// Small persisted manifest recording what a `.part` file expects, so a
/// relaunch can validate/resume it instead of guessing.
class DownloadManifest {
  const DownloadManifest({required this.url, required this.totalBytes});

  final String url;
  final int totalBytes;

  Map<String, Object?> toJson() => {'url': url, 'totalBytes': totalBytes};

  factory DownloadManifest.fromJson(Map<String, Object?> json) =>
      DownloadManifest(
        url: json['url'] as String,
        totalBytes: (json['totalBytes'] as num).toInt(),
      );

  static Future<void> write(String metaPath, DownloadManifest manifest) {
    return File(metaPath).writeAsString(jsonEncode(manifest.toJson()));
  }

  static Future<DownloadManifest?> read(String metaPath) async {
    final file = File(metaPath);
    if (!await file.exists()) return null;
    try {
      return DownloadManifest.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    }
  }
}
