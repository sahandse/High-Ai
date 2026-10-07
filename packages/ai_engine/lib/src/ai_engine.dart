import 'models/chat_message.dart';
import 'models/generation_chunk.dart';
import 'models/generation_settings.dart';
import 'models/model_info.dart';
import 'models/backend.dart';

/// Platform- and backend-agnostic contract for local AI inference.
///
/// The chat model and embedding model have independent lifecycles. This is
/// important for RAG: High-Ai can keep the conversational model loaded while
/// EmbeddingGemma 2 indexes/retrieves local memories.
abstract class AiEngine {
  bool get isSupported;

  Future<void> initialize();

  Future<void> loadModel(String modelPath, {Backend backend = Backend.cpu});

  Future<void> unloadModel();

  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  });

  Future<void> stopGeneration();

  Future<bool> isModelLoaded();

  Future<ModelInfo> getModelInfo();

  /// Loads a LiteRT-LM embedding model without touching the chat engine.
  Future<void> loadEmbeddingModel(
    String modelPath, {
    Backend backend = Backend.cpu,
  });

  /// Releases only the embedding engine.
  Future<void> unloadEmbeddingModel();

  Future<bool> isEmbeddingModelLoaded();

  /// Produces an L2-normalized semantic vector for [text].
  ///
  /// EmbeddingGemma 2 supports Matryoshka output dimensions. High-Ai uses
  /// 256d by default as a practical balance between retrieval quality and
  /// local storage/RAM use.
  Future<List<double>> embedText(
    String text, {
    int outputSize = 256,
    bool normalize = true,
  });
}
