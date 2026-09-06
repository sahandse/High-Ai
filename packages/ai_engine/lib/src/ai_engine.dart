import 'models/chat_message.dart';
import 'models/generation_chunk.dart';
import 'models/generation_settings.dart';
import 'models/model_info.dart';
import 'models/backend.dart';

/// Platform- and backend-agnostic contract for local LLM inference.
///
/// The app depends only on this interface (`package:ai_engine/ai_engine.dart`)
/// and never branches on which platform or backend is actually running —
/// that decision is made inside the engine implementation returned by
/// `createAiEngine()`. See docs/ARCHITECTURE.md §2.
abstract class AiEngine {
  /// Prepares the engine for use (e.g. binds native resources). Cheap and
  /// idempotent — does not load a model.
  Future<void> initialize();

  /// Loads the model at [modelPath] onto [backend], falling back to
  /// [Backend.cpu] internally if the requested backend is unavailable.
  /// Throws [ModelNotAvailableException] or [ModelLoadException] on failure.
  Future<void> loadModel(String modelPath, {Backend backend = Backend.cpu});

  /// Releases the loaded model and any native memory it holds.
  Future<void> unloadModel();

  /// Streams a response for [messages]. Emits [GenerationChunk.token]
  /// events as text becomes available, then exactly one terminal
  /// [GenerationChunk.done] or [GenerationChunk.error] event.
  ///
  /// Cancel a generation in progress with [stopGeneration] rather than
  /// cancelling the stream subscription, so the native engine is told to
  /// stop producing tokens instead of just being ignored.
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  });

  /// Requests that any in-flight [generate] call stop as soon as possible.
  /// A no-op if nothing is generating.
  Future<void> stopGeneration();

  Future<bool> isModelLoaded();

  Future<ModelInfo> getModelInfo();
}
