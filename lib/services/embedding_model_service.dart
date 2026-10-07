import 'dart:async';
import 'dart:io';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_engine_provider.dart';
import 'model_download_manager.dart';

enum EmbeddingModelStatus {
  notInstalled,
  downloading,
  ready,
  loading,
  loaded,
  paused,
  error,
}

class EmbeddingModelState {
  const EmbeddingModelState({
    this.status = EmbeddingModelStatus.notInstalled,
    this.progress,
    this.errorMessage,
  });

  final EmbeddingModelStatus status;
  final DownloadProgress? progress;
  final String? errorMessage;

  bool get isUsable => status == EmbeddingModelStatus.loaded;

  EmbeddingModelState copyWith({
    EmbeddingModelStatus? status,
    DownloadProgress? progress,
    String? errorMessage,
  }) =>
      EmbeddingModelState(
        status: status ?? this.status,
        progress: progress,
        errorMessage: errorMessage,
      );
}

class EmbeddingModelController extends Notifier<EmbeddingModelState> {
  static const modelUrl =
      'https://huggingface.co/litert-community/'
      'embeddinggemma-2-text-270m-litert-lm/resolve/main/'
      'embeddinggemma-2-text-270m.litertlm';
  static const approximateSizeBytes = 165 * 1024 * 1024;

  final ModelDownloadManager _downloader = ModelDownloadManager();

  @override
  EmbeddingModelState build() {
    unawaited(_reconcile());
    return const EmbeddingModelState();
  }

  Future<String> _modelPath() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/models');
    await dir.create(recursive: true);
    return '${dir.path}/embeddinggemma-2-text-270m.litertlm';
  }

  Future<void> _reconcile() async {
    final path = await _modelPath();
    if (await _downloader.isInstalled(path)) {
      state = state.copyWith(status: EmbeddingModelStatus.ready);
      await load();
    } else if (await _downloader.hasResumableDownload(path)) {
      state = state.copyWith(status: EmbeddingModelStatus.paused);
    }
  }

  Future<void> download() async {
    final engine = ref.read(aiEngineProvider);
    if (!engine.isSupported) {
      state = state.copyWith(
        status: EmbeddingModelStatus.error,
        errorMessage: 'EmbeddingGemma 2 روی این پلتفرم هنوز پشتیبانی نمی‌شود.',
      );
      return;
    }

    final path = await _modelPath();
    state = state.copyWith(
      status: EmbeddingModelStatus.downloading,
      errorMessage: null,
    );
    try {
      await _downloader.download(
        url: modelUrl,
        destinationPath: path,
        expectedSizeBytes: approximateSizeBytes,
        onProgress: (progress) {
          state = state.copyWith(
            status: EmbeddingModelStatus.downloading,
            progress: progress,
          );
        },
      );
      if (state.status != EmbeddingModelStatus.downloading) return;
      state = state.copyWith(status: EmbeddingModelStatus.ready);
      await load();
    } on ModelDownloadException catch (e) {
      state = state.copyWith(
        status: EmbeddingModelStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: EmbeddingModelStatus.error,
        errorMessage: 'دانلود EmbeddingGemma 2 ناموفق بود.',
      );
    }
  }

  void pause() {
    _downloader.cancel();
    state = state.copyWith(status: EmbeddingModelStatus.paused);
  }

  Future<void> load() async {
    final path = await _modelPath();
    if (!await File(path).exists()) {
      state = state.copyWith(status: EmbeddingModelStatus.notInstalled);
      return;
    }
    state = state.copyWith(
      status: EmbeddingModelStatus.loading,
      errorMessage: null,
    );
    try {
      await ref.read(aiEngineProvider).loadEmbeddingModel(
            path,
            backend: Backend.cpu,
          );
      state = state.copyWith(status: EmbeddingModelStatus.loaded);
    } on AiEngineException catch (e) {
      state = state.copyWith(
        status: EmbeddingModelStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: EmbeddingModelStatus.error,
        errorMessage: 'بارگذاری EmbeddingGemma 2 ناموفق بود.',
      );
    }
  }

  Future<void> unload() async {
    await ref.read(aiEngineProvider).unloadEmbeddingModel();
    final path = await _modelPath();
    state = state.copyWith(
      status: await File(path).exists()
          ? EmbeddingModelStatus.ready
          : EmbeddingModelStatus.notInstalled,
    );
  }

  Future<void> delete() async {
    await unload();
    final path = await _modelPath();
    await _downloader.delete(path);
    state = const EmbeddingModelState();
  }
}

final embeddingModelProvider =
    NotifierProvider<EmbeddingModelController, EmbeddingModelState>(
  EmbeddingModelController.new,
);
