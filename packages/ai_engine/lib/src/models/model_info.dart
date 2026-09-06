import 'backend.dart';
import 'model_status.dart';

/// Snapshot of the on-device model's identity, status, and footprint.
class ModelInfo {
  const ModelInfo({
    required this.modelId,
    required this.displayName,
    required this.status,
    this.backend,
    this.sizeOnDiskBytes,
    this.contextLength,
    this.localPath,
    this.errorMessage,
  });

  /// Stable id, e.g. `litert-community/gemma-4-E2B-it-litert-lm`.
  final String modelId;

  final String displayName;
  final ModelStatus status;

  /// The backend actually in use once loaded (may differ from the requested
  /// backend if the engine fell back to CPU).
  final Backend? backend;

  final int? sizeOnDiskBytes;

  /// Maximum context window (tokens) the loaded model supports.
  final int? contextLength;

  final String? localPath;

  /// Present only when [status] is [ModelStatus.error].
  final String? errorMessage;

  ModelInfo copyWith({
    ModelStatus? status,
    Backend? backend,
    int? sizeOnDiskBytes,
    int? contextLength,
    String? localPath,
    String? errorMessage,
  }) {
    return ModelInfo(
      modelId: modelId,
      displayName: displayName,
      status: status ?? this.status,
      backend: backend ?? this.backend,
      sizeOnDiskBytes: sizeOnDiskBytes ?? this.sizeOnDiskBytes,
      contextLength: contextLength ?? this.contextLength,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage,
    );
  }
}
