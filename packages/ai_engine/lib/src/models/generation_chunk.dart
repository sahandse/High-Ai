/// One event from the [Stream] returned by `AiEngine.generate`.
///
/// Modeled as a small closed union (via the two named constructors) so a
/// native-side error surfaces through the same stream as normal tokens
/// instead of an out-of-band exception the UI would need a separate
/// try/catch path for.
class GenerationChunk {
  const GenerationChunk._({this.textDelta, this.isDone = false, this.error});

  const GenerationChunk.token(String textDelta)
    : this._(textDelta: textDelta);

  const GenerationChunk.done() : this._(isDone: true);

  const GenerationChunk.error(String error)
    : this._(isDone: true, error: error);

  /// Incremental text produced since the previous chunk. Null for
  /// done/error chunks.
  final String? textDelta;

  /// True for the final chunk of a generation, whether it ended
  /// successfully or with [error] set.
  final bool isDone;

  /// Non-null if generation failed. [isDone] is always true alongside this.
  final String? error;

  bool get isError => error != null;
}
