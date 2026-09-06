import 'dart:async';
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

/// Thrown specifically when Hugging Face rejects the request with 401/403 —
/// confirmed in practice for gated model repos (the Gemma family requires
/// signing in to huggingface.co and accepting its license before any
/// request, even to a `litert-community` mirror, succeeds). Distinct from
/// [ModelDownloadException] so the UI can point the user at adding an
/// access token instead of just "try again".
class ModelDownloadAuthException extends ModelDownloadException {
  const ModelDownloadAuthException(super.message);
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
  /// before atomically installing it.
  ///
  /// [expectedSizeBytes] is only a fallback estimate (the catalog's
  /// best-effort figure) — the server's own `Content-Length`/`Content-Range`
  /// for *this* response is always preferred for both progress reporting
  /// and final size verification, since a hardcoded estimate can be off by
  /// a few bytes from the real file and would otherwise fail a perfectly
  /// good download.
  ///
  /// Call [cancel] to pause — the partial file is left in place so the
  /// download can resume later from the same byte offset.
  Future<void> download({
    required String url,
    required String destinationPath,
    int? expectedSizeBytes,
    String? expectedSha256,
    String? accessToken,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final partFile = File(_partPath(destinationPath));
    await partFile.parent.create(recursive: true);

    final existingBytes = await partFile.exists() ? await partFile.length() : 0;
    _cancelToken = CancelToken();

    final sink = partFile.openWrite(
      mode: existingBytes > 0 ? FileMode.append : FileMode.write,
    );

    final headers = <String, String>{
      if (existingBytes > 0) 'range': 'bytes=$existingBytes-',
      if (accessToken != null && accessToken.isNotEmpty)
        'authorization': 'Bearer $accessToken',
    };

    int? serverTotalBytes;
    try {
      final Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          url,
          cancelToken: _cancelToken,
          options: Options(
            headers: headers.isEmpty ? null : headers,
            responseType: ResponseType.stream,
            // Handle 416/401/403 ourselves instead of letting Dio throw —
            // each is a meaningful, recoverable signal here, not a
            // generic hard failure to dump as raw exception text.
            validateStatus: (status) =>
                status != null &&
                (status == 200 || status == 206 || status == 416 || status == 401 || status == 403),
          ),
        );
      } on DioException catch (e) {
        await sink.flush();
        await sink.close();
        if (CancelToken.isCancel(e)) return; // paused, not an error.
        throw ModelDownloadException('اتصال به سرور دانلود برقرار نشد: ${e.message}');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await sink.flush();
        await sink.close();
        throw const ModelDownloadAuthException(
          'دانلود این مدل نیاز به ورود به حساب Hugging Face و پذیرش مجوز استفاده دارد. '
          'از تنظیمات، توکن دسترسی Hugging Face خود را وارد کنید.',
        );
      }

      if (response.statusCode == 416) {
        await sink.flush();
        await sink.close();
        await _handleRangeNotSatisfiable(
          response: response,
          partFile: partFile,
          destinationPath: destinationPath,
          existingBytes: existingBytes,
          expectedSizeBytes: expectedSizeBytes,
          expectedSha256: expectedSha256,
        );
        return;
      }

      serverTotalBytes = _totalFromHeaders(response.headers, existingBytes) ??
          expectedSizeBytes;

      final stopwatch = Stopwatch()..start();
      var bytesAtLastTick = existingBytes;
      var lastTickMs = 0;
      var received = 0;
      var isFirstTick = true;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        final downloaded = existingBytes + received;
        final elapsedMs = stopwatch.elapsedMilliseconds;
        final deltaMs = elapsedMs - lastTickMs;
        // Always report the very first chunk immediately (so the UI shows
        // progress right away instead of waiting out the throttle window),
        // then throttle further updates to roughly 5/second.
        if (isFirstTick || deltaMs >= 200) {
          final speed = deltaMs > 0 ? (downloaded - bytesAtLastTick) / (deltaMs / 1000) : 0.0;
          bytesAtLastTick = downloaded;
          lastTickMs = elapsedMs;
          isFirstTick = false;
          onProgress?.call(
            DownloadProgress(
              downloadedBytes: downloaded,
              totalBytes: serverTotalBytes ?? downloaded,
              bytesPerSecond: speed,
            ),
          );
        }
      }
      // Final tick so the UI can reach exactly 100% before verification.
      onProgress?.call(
        DownloadProgress(
          downloadedBytes: existingBytes + received,
          totalBytes: serverTotalBytes ?? (existingBytes + received),
          bytesPerSecond: 0,
        ),
      );
    } on DioException catch (e) {
      await sink.flush();
      await sink.close();
      if (CancelToken.isCancel(e)) return; // paused, not an error.
      throw ModelDownloadException('دانلود با خطا مواجه شد: ${e.message}');
    }
    await sink.flush();
    await sink.close();

    await _verifyAndInstall(
      partFile: partFile,
      destinationPath: destinationPath,
      expectedSizeBytes: serverTotalBytes,
      expectedSha256: expectedSha256,
    );
  }

  /// A 416 means our on-disk `.part` file's length is already at or beyond
  /// what the server thinks the file is. Reconcile using whatever total the
  /// server reports (from the `Content-Range: bytes */total` the spec
  /// requires on a 416): if our bytes already cover it, the download was
  /// actually already complete — verify and install instead of failing.
  /// If the sizes can't be reconciled, the partial file is stale/corrupt;
  /// delete it so a subsequent retry starts clean instead of 416-looping.
  Future<void> _handleRangeNotSatisfiable({
    required Response<ResponseBody> response,
    required File partFile,
    required String destinationPath,
    required int existingBytes,
    required int? expectedSizeBytes,
    required String? expectedSha256,
  }) async {
    final serverTotal = _totalFromHeaders(response.headers, existingBytes);
    final candidateTotal = serverTotal ?? expectedSizeBytes;
    if (candidateTotal != null && existingBytes >= candidateTotal) {
      await _verifyAndInstall(
        partFile: partFile,
        destinationPath: destinationPath,
        expectedSizeBytes: candidateTotal,
        expectedSha256: expectedSha256,
      );
      return;
    }
    await partFile.delete().catchError((_) => partFile);
    throw ModelDownloadException(
      'فایل ناتمام قبلی با فایل روی سرور هم‌خوانی نداشت و حذف شد. لطفاً دوباره تلاش کنید.',
    );
  }

  /// Reads the authoritative total file size from `Content-Range` (present
  /// on both 206 Partial Content and 416 responses per HTTP spec) or falls
  /// back to `Content-Length` for a fresh, non-ranged 200 response.
  int? _totalFromHeaders(Headers headers, int existingBytes) {
    final contentRange = headers.value('content-range');
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    final contentLength = headers.value('content-length');
    if (contentLength != null) {
      final length = int.tryParse(contentLength);
      if (length != null) return existingBytes + length;
    }
    return null;
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
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Aborts the current network transfer but keeps the partial file, so a
  /// later call to [download] with the same arguments resumes from here —
  /// used for both an explicit "pause" and tearing down on app close.
  void cancel() {
    _cancelToken?.cancel('user_paused');
  }

  Future<void> delete(String destinationPath) async {
    await File(destinationPath).delete().catchError((_) => File(destinationPath));
    await File(_partPath(destinationPath))
        .delete()
        .catchError((_) => File(_partPath(destinationPath)));
  }
}
