/// Static metadata for the one model this v1 supports — Gemma 4 E2B via
/// LiteRT-LM. See docs/ARCHITECTURE.md §0/§7: the Hugging Face repo hosts
/// several SoC-specific `.litertlm` files rather than one universal
/// artifact, so [defaultVariant] picks a broadly-compatible Android variant
/// as a starting point. Automatic per-device SoC detection (choosing among
/// [variants]) is tracked as follow-up work, not implemented in v1.
class ModelVariant {
  const ModelVariant({
    required this.id,
    required this.downloadUrl,
    required this.approximateSizeBytes,
  });

  final String id;
  final String downloadUrl;
  final int approximateSizeBytes;
}

abstract final class ModelCatalog {
  static const modelId = 'litert-community/gemma-4-E2B-it-litert-lm';
  static const displayName = 'Gemma 4 E2B';
  static const contextLength = 8192;

  static const _repoBase =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main';

  static const variants = [
    ModelVariant(
      id: 'qualcomm_sm8750',
      downloadUrl: '$_repoBase/gemma-4-E2B-it_qualcomm_sm8750.litertlm',
      approximateSizeBytes: 3243000000,
    ),
    ModelVariant(
      id: 'google_tensor_g5',
      downloadUrl: '$_repoBase/gemma-4-E2B-it_Google_Tensor_G5.litertlm',
      approximateSizeBytes: 3340000000,
    ),
    ModelVariant(
      id: 'intel_ptl',
      downloadUrl: '$_repoBase/gemma-4-E2B-it_intel_PTL.litertlm',
      approximateSizeBytes: 3168000000,
    ),
  ];

  static ModelVariant get defaultVariant => variants.first;

  static String fileNameFor(ModelVariant variant) =>
      '${variant.id}.litertlm';
}
