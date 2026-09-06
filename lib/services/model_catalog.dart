/// Static metadata for the models this app can download — see
/// docs/ARCHITECTURE.md §0/§7: Hugging Face hosts several per-SoC
/// `.litertlm` files for some models rather than one universal artifact,
/// so each [ModelDefinition] lists its own [variants].
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

class ModelDefinition {
  const ModelDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.idealFor,
    required this.advantages,
    required this.badge,
    required this.contextLength,
    required this.variants,
  });

  /// Stable id, matching the Hugging Face repo under `litert-community/`.
  final String id;

  final String displayName;

  /// One-line Persian summary shown right under the model name.
  final String description;

  /// A short "بهترین گزینه برای..." line — who this model suits.
  final String idealFor;

  /// Concrete, honest advantages shown as a bullet list in the picker.
  final List<String> advantages;

  /// Short Persian label, e.g. "توصیه‌شده" or "حرفه‌ای".
  final String badge;

  final int contextLength;
  final List<ModelVariant> variants;

  ModelVariant get defaultVariant => variants.first;

  String fileNameFor(ModelVariant variant) => '${id}_${variant.id}.litertlm';
}

abstract final class ModelCatalog {
  static const _gemma4E2bBase =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main';
  static const _gemma4E4bBase =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main';

  static const gemma4E2b = ModelDefinition(
    id: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    description: 'نسخه سبک جما ۴؛ برای گفتگوی روزمره سریع و بهینه شده است.',
    idealFor: 'بهترین گزینه برای بیشتر گوشی‌ها و استفاده روزمره',
    advantages: [
      'نصب و بارگذاری سریع‌تر؛ حجم دانلود کمتر',
      'مصرف حافظه و باتری پایین‌تر روی گوشی‌های معمولی',
      'سرعت پاسخ‌دهی بالاتر، مناسب گفتگوی روان و بی‌وقفه',
      'روی طیف گسترده‌تری از پردازنده‌های موبایل اجرا می‌شود',
    ],
    badge: 'توصیه‌شده',
    contextLength: 8192,
    variants: [
      ModelVariant(
        id: 'qualcomm_sm8750',
        downloadUrl: '$_gemma4E2bBase/gemma-4-E2B-it_qualcomm_sm8750.litertlm',
        approximateSizeBytes: 3243000000,
      ),
      ModelVariant(
        id: 'google_tensor_g5',
        downloadUrl: '$_gemma4E2bBase/gemma-4-E2B-it_Google_Tensor_G5.litertlm',
        approximateSizeBytes: 3340000000,
      ),
      ModelVariant(
        id: 'intel_ptl',
        downloadUrl: '$_gemma4E2bBase/gemma-4-E2B-it_intel_PTL.litertlm',
        approximateSizeBytes: 3168000000,
      ),
    ],
  );

  static const gemma4E4b = ModelDefinition(
    id: 'gemma-4-e4b',
    displayName: 'Gemma 4 E4B',
    description: 'نسخه بزرگ‌تر جما ۴؛ برای درک عمیق‌تر و پاسخ‌های دقیق‌تر.',
    idealFor: 'بهترین گزینه برای گوشی‌های قدرتمند و سوال‌های پیچیده‌تر',
    advantages: [
      'درک بهتر متن‌های طولانی و پیچیده',
      'استدلال و پاسخ‌دهی دقیق‌تر در موضوعات فنی و تخصصی',
      'کیفیت نگارش و انسجام پاسخ در گفتگوهای بلند بالاتر',
      'همان حریم خصوصی کامل و اجرای آفلاین، با کیفیتی بالاتر',
    ],
    badge: 'کیفیت بالاتر',
    contextLength: 8192,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: '$_gemma4E4bBase/gemma-4-E4B-it.litertlm',
        approximateSizeBytes: 3660000000,
      ),
    ],
  );

  static const all = [gemma4E2b, gemma4E4b];

  static ModelDefinition byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => gemma4E2b);
}
