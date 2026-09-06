import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/services/model_download_manager.dart';

/// A scripted [HttpClientAdapter] so these tests exercise
/// [ModelDownloadManager]'s real request/response handling (headers,
/// status codes, streaming) without touching the network.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _bodyOf(
  List<int> bytes,
  int statusCode, {
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromBytes(bytes, statusCode, headers: headers ?? {});
}

void main() {
  late Directory tempDir;
  late String destinationPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model_download_network_test');
    destinationPath = '${tempDir.path}/model.litertlm';
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('fresh download streams bytes and installs using the server total', () async {
    final content = List<int>.generate(1000, (i) => i % 256);
    final dio = Dio()
      ..httpClientAdapter = _ScriptedAdapter(
        (options) => _bodyOf(
          content,
          200,
          headers: {
            'content-length': ['1000'],
          },
        ),
      );
    final manager = ModelDownloadManager(dio: dio);

    DownloadProgress? lastProgress;
    await manager.download(
      url: 'https://example.test/model.litertlm',
      destinationPath: destinationPath,
      onProgress: (p) => lastProgress = p,
    );

    expect(await File(destinationPath).exists(), isTrue);
    expect(await File(destinationPath).readAsBytes(), content);
    expect(lastProgress?.totalBytes, 1000);
  });

  test(
    'resumes from an existing .part file using a Range request',
    () async {
      final firstHalf = List<int>.generate(500, (i) => i % 256);
      final secondHalf = List<int>.generate(500, (i) => (500 + i) % 256);
      await File('$destinationPath.part').writeAsBytes(firstHalf);

      String? sentRange;
      final dio = Dio()
        ..httpClientAdapter = _ScriptedAdapter((options) {
          sentRange = options.headers['range'] as String?;
          return _bodyOf(
            secondHalf,
            206,
            headers: {
              'content-range': ['bytes 500-999/1000'],
            },
          );
        });
      final manager = ModelDownloadManager(dio: dio);

      await manager.download(
        url: 'https://example.test/model.litertlm',
        destinationPath: destinationPath,
      );

      expect(sentRange, 'bytes=500-');
      expect(
        await File(destinationPath).readAsBytes(),
        [...firstHalf, ...secondHalf],
      );
    },
  );

  test(
    '416 with a matching total treats the partial file as already complete',
    () async {
      final fullContent = List<int>.generate(1000, (i) => i % 256);
      await File('$destinationPath.part').writeAsBytes(fullContent);

      final dio = Dio()
        ..httpClientAdapter = _ScriptedAdapter(
          (options) => _bodyOf(
            const [],
            416,
            headers: {
              'content-range': ['bytes */1000'],
            },
          ),
        );
      final manager = ModelDownloadManager(dio: dio);

      await manager.download(
        url: 'https://example.test/model.litertlm',
        destinationPath: destinationPath,
      );

      expect(await File(destinationPath).exists(), isTrue);
      expect(await File('$destinationPath.part').exists(), isFalse);
      expect(await File(destinationPath).readAsBytes(), fullContent);
    },
  );

  test(
    '416 that cannot be reconciled deletes the stale partial file',
    () async {
      await File('$destinationPath.part').writeAsBytes(List.filled(200, 1));

      final dio = Dio()
        ..httpClientAdapter = _ScriptedAdapter(
          (options) => _bodyOf(
            const [],
            416,
            headers: {
              'content-range': ['bytes */1000'],
            },
          ),
        );
      final manager = ModelDownloadManager(dio: dio);

      await expectLater(
        manager.download(
          url: 'https://example.test/model.litertlm',
          destinationPath: destinationPath,
        ),
        throwsA(isA<ModelDownloadException>()),
      );

      expect(await File('$destinationPath.part').exists(), isFalse);
      expect(await File(destinationPath).exists(), isFalse);
    },
  );

  test('throws a friendly exception when the downloaded size mismatches', () async {
    final dio = Dio()
      ..httpClientAdapter = _ScriptedAdapter(
        (options) => _bodyOf(
          List.filled(10, 0),
          200,
          headers: {
            'content-length': ['10'],
          },
        ),
      );
    final manager = ModelDownloadManager(dio: dio);

    await expectLater(
      manager.download(
        url: 'https://example.test/model.litertlm',
        destinationPath: destinationPath,
        expectedSha256: 'deadbeef', // wrong on purpose
      ),
      throwsA(isA<ModelDownloadException>()),
    );
  });

  test('a 401 from a gated repo throws ModelDownloadAuthException', () async {
    final dio = Dio()..httpClientAdapter = _ScriptedAdapter((options) => _bodyOf(const [], 401));
    final manager = ModelDownloadManager(dio: dio);

    await expectLater(
      manager.download(url: 'https://example.test/model.litertlm', destinationPath: destinationPath),
      throwsA(isA<ModelDownloadAuthException>()),
    );
    // The final file is never installed after an auth failure.
    expect(await File(destinationPath).exists(), isFalse);
  });

  test('sends an Authorization header when an access token is provided', () async {
    String? sentAuth;
    final content = List<int>.generate(10, (i) => i);
    final dio = Dio()
      ..httpClientAdapter = _ScriptedAdapter((options) {
        sentAuth = options.headers['authorization'] as String?;
        return _bodyOf(
          content,
          200,
          headers: {
            'content-length': ['10'],
          },
        );
      });
    final manager = ModelDownloadManager(dio: dio);

    await manager.download(
      url: 'https://example.test/model.litertlm',
      destinationPath: destinationPath,
      accessToken: 'hf_secret_token',
    );

    expect(sentAuth, 'Bearer hf_secret_token');
  });
}
