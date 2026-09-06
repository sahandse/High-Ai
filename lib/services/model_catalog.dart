/// Static metadata for the models this app can download.
///
/// Sizes, minimum RAM, and filenames below are taken from Google's own
/// `google-ai-edge/gallery` reference app's official model allowlist
/// (`model_allowlists/1_0_12.json`, commit hashes recorded per model) —
/// not guessed. Earlier revisions of this catalog pointed at per-SoC
/// ahead-of-time-compiled `.litertlm` files (e.g. `..._qualcomm_sm8750`)
/// that only load on the exact chip they were compiled for; those turned
/// out to be a mistake confirmed on a real device (see
/// docs/ARCHITECTURE.md "Addendum 3") — Gallery itself ships the plain,
/// generic file per model, which runs broadly via LiteRT-LM's GPU/CPU
/// delegates instead of one accelerator's AOT-compiled graph.
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
    required this.minRamGb,
    required this.variants,
    this.compatibilityWarning,
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

  /// Minimum device RAM Google's own Gallery app requires for this model —
  /// not a heuristic. Used directly by [DeviceCapabilityChecker].
  final int minRamGb;

  final List<ModelVariant> variants;

  /// Set for a model whose only available file needs specific hardware
  /// this app cannot verify ahead of time — shown as an explicit warning
  /// in the picker rather than silently letting the load fail later.
  final String? compatibilityWarning;

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
    description: 'نسخه سبک و عمومی جما ۴؛ برای گفتگوی روزمره روی اکثر گوشی‌ها.',
    idealFor: 'بهترین گزینه پیش‌فرض؛ گوشی‌های با ۸ گیگابایت رم یا بیشتر',
    advantages: [
      'یک فایل عمومی؛ نیازی به پردازنده خاص ندارد و روی اکثر گوشی‌ها اجرا می‌شود',
      'حجم دانلود کمتر (حدود ۲.۴ گیگابایت)',
      'مصرف حافظه و باتری پایین‌تر نسبت به نسخه بزرگ‌تر',
      'سرعت پاسخ‌دهی مناسب برای گفتگوی روان و بی‌وقفه',
    ],
    badge: 'توصیه‌شده',
    contextLength: 32000,
    minRamGb: 8,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: '$_gemma4E2bBase/gemma-4-E2B-it.litertlm',
        approximateSizeBytes: 2583085056,
      ),
    ],
  );

  static const gemma4E4b = ModelDefinition(
    id: 'gemma-4-e4b',
    displayName: 'Gemma 4 E4B',
    description: 'نسخه بزرگ‌تر جما ۴؛ درک و پاسخ‌دهی قوی‌تر، برای گوشی‌های پرقدرت.',
    idealFor: 'فقط برای گوشی‌های با حداقل ۱۲ گیگابایت رم',
    advantages: [
      'درک بهتر متن‌های طولانی و پیچیده',
      'استدلال و پاسخ‌دهی دقیق‌تر در موضوعات فنی و تخصصی',
      'کیفیت نگارش و انسجام پاسخ در گفتگوهای بلند بالاتر',
      'همان حریم خصوصی کامل و اجرای کاملاً آفلاین',
    ],
    badge: 'نیازمند رم بالا',
    contextLength: 32000,
    minRamGb: 12,
    compatibilityWarning:
        'این مدل به حداقل ۱۲ گیگابایت رم نیاز دارد. روی گوشی‌های با رم کمتر ممکن است '
        'بارگذاری نشود یا بسیار کند اجرا شود.',
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: '$_gemma4E4bBase/gemma-4-E4B-it.litertlm',
        approximateSizeBytes: 3654467584,
      ),
    ],
  );

  static const all = [gemma4E2b, gemma4E4b];

  static ModelDefinition byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => gemma4E2b);
}
