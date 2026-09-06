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
  final List<ModelVariant> variants;

  /// Set only for models distributed as separate per-chipset compiled
  /// files with no generic/CPU-only fallback (see docs/ARCHITECTURE.md §0)
  /// — shown as an explicit warning in the picker, since without real
  /// per-device SoC detection (not implemented — see the architecture doc)
  /// the app always fetches [variants].first, and that file simply will
  /// not load on hardware it wasn't compiled for.
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
    description: 'نسخه سبک جما ۴، ویژه پردازنده‌های خاص؛ در صورت سازگاری بسیار سریع است.',
    idealFor: 'فقط برای گوشی‌های دارای پردازنده Snapdragon 8 Elite‏، Google Tensor G5 یا Intel PTL',
    advantages: [
      'در صورت سازگاری: نصب و بارگذاری سریع‌تر؛ حجم دانلود کمتر',
      'مصرف حافظه و باتری پایین‌تر نسبت به نسخه بزرگ‌تر',
      'سرعت پاسخ‌دهی بسیار بالا روی پردازنده‌های سازگار',
    ],
    badge: 'پردازنده خاص',
    contextLength: 8192,
    compatibilityWarning:
        'این نسخه برای چند پردازنده خاص کامپایل شده و روی بیشتر گوشی‌ها اجرا نمی‌شود. '
        'در حال حاضر برنامه نمی‌تواند پردازنده دستگاه شما را به‌طور خودکار تشخیص دهد؛ '
        'اگر مطمئن نیستید، Gemma 4 E4B که روی همه دستگاه‌ها کار می‌کند را انتخاب کنید.',
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
    description: 'نسخه عمومی جما ۴؛ روی هر گوشی اجرا می‌شود، با درک و پاسخ‌دهی قوی‌تر.',
    idealFor: 'بهترین گزینه پیش‌فرض برای همه دستگاه‌ها',
    advantages: [
      'یک فایل عمومی؛ روی هر گوشی اندرویدی قابل اجراست (نیازی به پردازنده خاص نیست)',
      'درک بهتر متن‌های طولانی و پیچیده',
      'استدلال و پاسخ‌دهی دقیق‌تر در موضوعات فنی و تخصصی',
      'همان حریم خصوصی کامل و اجرای کاملاً آفلاین',
    ],
    badge: 'توصیه‌شده',
    contextLength: 8192,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: '$_gemma4E4bBase/gemma-4-E4B-it.litertlm',
        approximateSizeBytes: 3660000000,
      ),
    ],
  );

  /// [gemma4E4b] listed first — it is the only model here with a generic,
  /// non-chipset-specific file, so it is the safe default; see
  /// [ModelDefinition.compatibilityWarning] on [gemma4E2b].
  static const all = [gemma4E4b, gemma4E2b];

  static ModelDefinition byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => gemma4E4b);
}
