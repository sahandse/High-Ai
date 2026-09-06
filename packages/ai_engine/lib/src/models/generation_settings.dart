/// Sampling / decoding parameters forwarded to the native engine.
///
/// Only parameters LiteRT-LM's Gemma 4 E2B pipeline actually supports are
/// exposed here — see docs/ARCHITECTURE.md. Defaults match Gemma's
/// commonly-recommended instruction-tuned chat settings.
class GenerationSettings {
  const GenerationSettings({
    this.temperature = 1.0,
    this.topK = 64,
    this.topP = 0.95,
    this.maxOutputTokens = 1024,
  });

  /// Sampling temperature. Valid range: `0.0`–`2.0`.
  final double temperature;

  /// Top-K sampling cutoff. Valid range: `1`–`256`.
  final int topK;

  /// Nucleus (top-P) sampling cutoff. Valid range: `0.0`–`1.0`.
  final double topP;

  /// Maximum number of tokens to generate for a single response.
  /// Valid range: `1`–`4096` (bounded by Gemma 4 E2B's practical context
  /// budget on-device).
  final int maxOutputTokens;

  /// Human-readable validation errors, or an empty list if [this] is valid.
  List<String> validate() {
    final errors = <String>[];
    if (temperature < 0.0 || temperature > 2.0) {
      errors.add('Temperature must be between 0.0 and 2.0.');
    }
    if (topK < 1 || topK > 256) {
      errors.add('Top K must be between 1 and 256.');
    }
    if (topP <= 0.0 || topP > 1.0) {
      errors.add('Top P must be between 0.0 (exclusive) and 1.0.');
    }
    if (maxOutputTokens < 1 || maxOutputTokens > 4096) {
      errors.add('Maximum output tokens must be between 1 and 4096.');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  GenerationSettings copyWith({
    double? temperature,
    int? topK,
    double? topP,
    int? maxOutputTokens,
  }) {
    return GenerationSettings(
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    );
  }

  Map<String, Object?> toJson() => {
    'temperature': temperature,
    'topK': topK,
    'topP': topP,
    'maxOutputTokens': maxOutputTokens,
  };

  factory GenerationSettings.fromJson(Map<String, Object?> json) {
    return GenerationSettings(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
      topK: (json['topK'] as num?)?.toInt() ?? 64,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.95,
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 1024,
    );
  }
}
