import 'dart:async';
import 'dart:io';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_engine_provider.dart';
import 'model_catalog.dart';
import 'model_download_manager.dart';

/// UI-facing state for the Models screen — combines on-disk/download state
/// with the native engine's load state into the single status enum defined
/// by `package:ai_engine` (docs/ARCHITECTURE.md §9).
class ModelState {
  const ModelState({
    required this.status,
    this.progress,
    this.errorMessage,
    this.info,
  });

  const ModelState.initial() : this(status: ModelStatus.notInstalled);

  final ModelStatus status;
  final DownloadProgress? progress;
  final String? errorMessage;
  final ModelInfo? info;

  ModelState copyWith({
    ModelStatus? status,
    DownloadProgress? progress,
    String? errorMessage,
    ModelInfo? info,
  }) {
    return ModelState(
      status: status ?? this.status,
      progress: progress,
      errorMessage: errorMessage,
      info: info ?? this.info,
    );
  }
}

class ModelManager extends Notifier<ModelState> {
  late final ModelDownloadManager _downloader;
  late final ModelVariant _variant;
  String? _modelPath;

  @override
  ModelState build() {
    _downloader = ModelDownloadManager();
    _variant = ModelCatalog.defaultVariant;
    unawaited(_reconcileOnStartup());
    return const ModelState.initial();
  }

  Future<String> _resolveModelPath() async {
    if (_modelPath != null) return _modelPath!;
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/models');
    await modelsDir.create(recursive: true);
    _modelPath = '${modelsDir.path}/${ModelCatalog.fileNameFor(_variant)}';
    return _modelPath!;
  }

  /// Reconciles on-disk state with [ModelStatus] at app launch, per
  /// docs/ARCHITECTURE.md §7: a `.part` file alone is never "ready".
  Future<void> _reconcileOnStartup() async {
    final path = await _resolveModelPath();
    if (await _downloader.isInstalled(path)) {
      state = state.copyWith(status: ModelStatus.ready);
      // Already downloaded from a previous run — load it automatically so
      // the user can start chatting right away, without an extra tap.
      await loadModel();
    } else if (await _downloader.hasResumableDownload(path)) {
      // Leave as notInstalled but the Models screen offers "resume" once
      // the user asks to download again — see resumeOrStartDownload().
      state = state.copyWith(status: ModelStatus.notInstalled);
    }
  }

  Future<void> download() async {
    final path = await _resolveModelPath();
    state = state.copyWith(status: ModelStatus.downloading, errorMessage: null);
    try {
      await _downloader.download(
        url: _variant.downloadUrl,
        destinationPath: path,
        expectedSizeBytes: _variant.approximateSizeBytes,
        onProgress: (progress) {
          state = state.copyWith(
            status: ModelStatus.downloading,
            progress: progress,
          );
        },
      );
      state = state.copyWith(status: ModelStatus.verifying);
      if (await _downloader.isInstalled(path)) {
        state = state.copyWith(status: ModelStatus.ready);
        // Load immediately, like Google AI Edge Gallery does — the user
        // shouldn't have to tap a second button after a multi-GB download
        // just to start chatting.
        await loadModel();
      } else {
        state = state.copyWith(
          status: ModelStatus.error,
          errorMessage: 'دانلود ناتمام ماند.',
        );
      }
    } on ModelDownloadException catch (e) {
      state = state.copyWith(status: ModelStatus.error, errorMessage: e.message);
    }
  }

  void cancelDownload() {
    _downloader.cancel();
    state = state.copyWith(status: ModelStatus.notInstalled);
  }

  Future<void> deleteModel() async {
    final path = await _resolveModelPath();
    await _downloader.delete(path);
    final engine = ref.read(aiEngineProvider);
    try {
      await engine.unloadModel();
    } catch (_) {
      // Nothing was loaded — fine to ignore.
    }
    state = const ModelState.initial();
  }

  Future<void> loadModel({Backend backend = Backend.cpu}) async {
    final path = await _resolveModelPath();
    state = state.copyWith(status: ModelStatus.loading, errorMessage: null);
    final engine = ref.read(aiEngineProvider);
    try {
      await engine.initialize();
      await engine.loadModel(path, backend: backend);
      final info = await engine.getModelInfo();
      state = state.copyWith(status: ModelStatus.loaded, info: info);
    } on AiEngineException catch (e) {
      state = state.copyWith(status: ModelStatus.error, errorMessage: e.message);
    }
  }

  Future<void> unloadModel() async {
    final engine = ref.read(aiEngineProvider);
    await engine.unloadModel();
    state = state.copyWith(status: ModelStatus.ready);
  }
}

final modelManagerProvider = NotifierProvider<ModelManager, ModelState>(
  ModelManager.new,
);
