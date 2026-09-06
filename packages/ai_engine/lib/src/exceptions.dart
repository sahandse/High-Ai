/// Base type for all failures surfaced by an [AiEngine] implementation.
///
/// UI code should catch this (never a raw platform/FFI exception) and map
/// it to a friendly message — see docs/ARCHITECTURE.md and the app's
/// `features/models` error-presentation widgets.
sealed class AiEngineException implements Exception {
  const AiEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The requested platform has no working native backend yet (e.g. macOS in
/// v1 — see docs/ARCHITECTURE.md §6). Never thrown to fake success; always
/// thrown instead of silently no-op'ing.
class UnsupportedPlatformException extends AiEngineException {
  const UnsupportedPlatformException(super.message);
}

/// The model file is missing, incomplete, or failed checksum verification.
class ModelNotAvailableException extends AiEngineException {
  const ModelNotAvailableException(super.message);
}

/// The native engine failed to initialize or load the model.
class ModelLoadException extends AiEngineException {
  const ModelLoadException(super.message);
}

/// A generation request failed on the native side.
class GenerationException extends AiEngineException {
  const GenerationException(super.message);
}
