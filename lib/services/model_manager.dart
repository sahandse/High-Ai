import 'dart:async';
import 'dart:io';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_engine_provider.dart';
import 'device_capability_checker.dart';
import 'model_catalog.dart';
import 'model_download_manager.dart';
import 'settings_service.dart' show settingsServiceProvider, onboardingCompleteProvider;

/// Per-model download/load status, as shown in the model picker.
class ModelEntryState {
  const ModelEntryState({
    this.status = ModelStatus.notInstalled,
    this.progress,
    this.errorMessage,
    this.info,
    this.capability,
  });

  final ModelStatus status;
  final DownloadProgress? progress;
  final String? errorMessage;
  final ModelInfo? info;

  /// Populated by [ModelManager.checkCapability] before a download starts,
  /// so the picker can show "این مدل روی دستگاه شما قابل نصب است" (or not)
  /// ahead of a multi-GB commitment.
  final DeviceCapabilityResult? capability;

  ModelEntryState copyWith({
    ModelStatus? status,
    DownloadProgress? progress,
    String? errorMessage,
    ModelInfo? info,
    DeviceCapabilityResult? capability,
  }) {
    return ModelEntryState(
      status: status ?? this.status,
      progress: progress,
      errorMessage: errorMessage,
      info: info ?? this.info,
      capability: capability ?? this.capability,
    );
  }
}

/// All known models' states, keyed by [ModelDefinition.id]. Only one model
/// can be loaded into the native engine at a time — see [activeModelId].
class ModelManagerState {
  const ModelManagerState({this.entries = const {}});

  final Map<String, ModelEntryState> entries;

  ModelEntryState entryFor(String modelId) =>
      entries[modelId] ?? const ModelEntryState();

  /// The model currently loading/loaded in the native engine, if any.
  String? get activeModelId {
    for (final entry in entries.entries) {
      if (entry.value.status == ModelStatus.loading ||
          entry.value.status == ModelStatus.loaded) {
        return entry.key;
      }
    }
    return null;
  }

  ModelManagerState _withEntry(String modelId, ModelEntryState entry) {
    return ModelManagerState(entries: {...entries, modelId: entry});
  }
}

class ModelManager extends Notifier<ModelManagerState> {
  late final ModelDownloadManager _downloader;
  late final DeviceCapabilityChecker _capabilityChecker;

  @override
  ModelManagerState build() {
    _downloader = ModelDownloadManager();
    _capabilityChecker = DeviceCapabilityChecker();
    unawaited(_reconcileOnStartup());
    return const ModelManagerState();
  }

  Future<Directory> _modelsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/models');
    await modelsDir.create(recursive: true);
    return modelsDir;
  }

  Future<String> _resolveModelPath(ModelDefinition model) async {
    final modelsDir = await _modelsDirectory();
    return '${modelsDir.path}/${model.fileNameFor(model.defaultVariant)}';
  }

  void _updateEntry(String modelId, ModelEntryState Function(ModelEntryState) update) {
    final current = state.entryFor(modelId);
    state = state._withEntry(modelId, update(current));
  }

  /// Reconciles on-disk state for every catalog model at app launch, then
  /// auto-loads whichever model the user had active last time — see
  /// docs/ARCHITECTURE.md §7: a `.part` file alone is never "ready".
  Future<void> _reconcileOnStartup() async {
    for (final model in ModelCatalog.all) {
      final path = await _resolveModelPath(model);
      if (await _downloader.isInstalled(path)) {
        _updateEntry(model.id, (e) => e.copyWith(status: ModelStatus.ready));
      } else if (await _downloader.hasResumableDownload(path)) {
        _updateEntry(model.id, (e) => e.copyWith(status: ModelStatus.paused));
      }
    }
    final lastActiveId = ref.read(settingsServiceProvider).loadActiveModelId();
    if (lastActiveId != null &&
        state.entryFor(lastActiveId).status == ModelStatus.ready) {
      await loadModel(lastActiveId);
    }
  }

  /// Checks free storage and RAM against [modelId]'s requirements — call
  /// this before showing the download button as enabled, so the user learns
  /// up front whether their device can take this model.
  Future<DeviceCapabilityResult> checkCapability(String modelId) async {
    final model = ModelCatalog.byId(modelId);
    final modelsDir = await _modelsDirectory();
    final result = await _capabilityChecker.check(model, modelsDir.path);
    _updateEntry(modelId, (e) => e.copyWith(capability: result));
    return result;
  }

  Future<void> download(String modelId) async {
    final model = ModelCatalog.byId(modelId);
    final variant = model.defaultVariant;
    final path = await _resolveModelPath(model);
    _updateEntry(
      modelId,
      (e) => e.copyWith(status: ModelStatus.downloading, errorMessage: null),
    );
    try {
      await _downloader.download(
        url: variant.downloadUrl,
        destinationPath: path,
        expectedSizeBytes: variant.approximateSizeBytes,
        onProgress: (progress) {
          _updateEntry(
            modelId,
            (e) => e.copyWith(status: ModelStatus.downloading, progress: progress),
          );
        },
      );
      // A pause (see pauseDownload) also returns normally from `download`,
      // so only move to verifying/ready if we're still actually downloading
      // — otherwise this would stomp a `paused` status right back to ready.
      if (state.entryFor(modelId).status != ModelStatus.downloading) return;
      _updateEntry(modelId, (e) => e.copyWith(status: ModelStatus.verifying));
      if (await _downloader.isInstalled(path)) {
        _updateEntry(modelId, (e) => e.copyWith(status: ModelStatus.ready));
        // Load immediately, like Google AI Edge Gallery does — the user
        // shouldn't have to tap a second button after a multi-GB download.
        await loadModel(modelId);
      } else {
        _updateEntry(
          modelId,
          (e) => e.copyWith(
            status: ModelStatus.error,
            errorMessage: 'دانلود ناتمام ماند.',
          ),
        );
      }
    } on ModelDownloadException catch (e) {
      _updateEntry(
        modelId,
        (entry) => entry.copyWith(status: ModelStatus.error, errorMessage: e.message),
      );
    }
  }

  /// Pauses an in-progress download — the partial file is kept so
  /// [download] resumes from the same byte offset when called again.
  void pauseDownload(String modelId) {
    _updateEntry(modelId, (e) => e.copyWith(status: ModelStatus.paused));
    _downloader.cancel();
  }

  /// Cancels a download (or discards a paused one) and deletes whatever
  /// partial data was written, unlike [pauseDownload].
  Future<void> cancelAndDeleteDownload(String modelId) async {
    _downloader.cancel();
    final model = ModelCatalog.byId(modelId);
    final path = await _resolveModelPath(model);
    await _downloader.delete(path);
    _updateEntry(modelId, (_) => const ModelEntryState());
  }

  Future<void> deleteModel(String modelId) async {
    final model = ModelCatalog.byId(modelId);
    final path = await _resolveModelPath(model);
    await _downloader.delete(path);
    if (state.activeModelId == modelId) {
      await ref.read(aiEngineProvider).unloadModel().catchError((_) {});
    }
    _updateEntry(modelId, (_) => const ModelEntryState());
  }

  Future<void> loadModel(String modelId, {Backend backend = Backend.cpu}) async {
    final model = ModelCatalog.byId(modelId);
    final path = await _resolveModelPath(model);
    final currentActive = state.activeModelId;
    if (currentActive != null && currentActive != modelId) {
      await unloadModel();
    }
    _updateEntry(
      modelId,
      (e) => e.copyWith(status: ModelStatus.loading, errorMessage: null),
    );
    // Marks the first-run download gate as done the moment a load is
    // attempted, not only on success — so the app transitions to the main
    // UI immediately (a load failure surfaces as an error state there,
    // reachable from Settings ▸ Models, rather than bouncing back to the
    // gate). See docs on `onboardingCompleteProvider`.
    ref.read(onboardingCompleteProvider.notifier).complete();
    final engine = ref.read(aiEngineProvider);
    try {
      await engine.initialize();
      await engine.loadModel(path, backend: backend);
      final info = await engine.getModelInfo();
      _updateEntry(modelId, (e) => e.copyWith(status: ModelStatus.loaded, info: info));
      await ref.read(settingsServiceProvider).saveActiveModelId(modelId);
    } on AiEngineException catch (e) {
      _updateEntry(
        modelId,
        (entry) => entry.copyWith(status: ModelStatus.error, errorMessage: e.message),
      );
    }
  }

  Future<void> unloadModel() async {
    final activeId = state.activeModelId;
    if (activeId == null) return;
    await ref.read(aiEngineProvider).unloadModel();
    _updateEntry(activeId, (e) => e.copyWith(status: ModelStatus.ready));
    await ref.read(settingsServiceProvider).saveActiveModelId(null);
  }
}

final modelManagerProvider = NotifierProvider<ModelManager, ModelManagerState>(
  ModelManager.new,
);
