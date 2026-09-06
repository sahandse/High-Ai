import '../ai_engine.dart';
import '../exceptions.dart';
import '../models/backend.dart';
import '../models/chat_message.dart';
import '../models/generation_chunk.dart';
import '../models/generation_settings.dart';
import '../models/model_info.dart';

/// Placeholder for a platform whose native bridge isn't implemented yet
/// (macOS in v1 — see docs/ARCHITECTURE.md §6). Every member throws
/// [UnsupportedPlatformException] rather than faking success, so the UI
/// shows an honest "not available on this platform yet" state instead of a
/// silent no-op.
class UnsupportedAiEngine implements AiEngine {
  const UnsupportedAiEngine(this.platformName);

  final String platformName;

  @override
  bool get isSupported => false;

  Never _unsupported() => throw UnsupportedPlatformException(
    'Local inference on $platformName is not implemented yet. '
    'See docs/ARCHITECTURE.md for status.',
  );

  @override
  Future<void> initialize() async => _unsupported();

  @override
  Future<void> loadModel(String modelPath, {Backend backend = Backend.cpu}) =>
      _unsupported();

  @override
  Future<void> unloadModel() async => _unsupported();

  @override
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  }) => throw UnsupportedPlatformException(
    'Local inference on $platformName is not implemented yet. '
    'See docs/ARCHITECTURE.md for status.',
  );

  @override
  Future<void> stopGeneration() async => _unsupported();

  @override
  Future<bool> isModelLoaded() async => false;

  @override
  Future<ModelInfo> getModelInfo() => _unsupported();
}
