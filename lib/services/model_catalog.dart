/// Static metadata for the models this app can download.
///
/// This list mirrors the "AI Chat" task's model set in Google's own
/// `google-ai-edge/gallery` reference app, read directly from its current
/// model allowlist (`model_allowlists/1_0_19.json` — modelId, modelFile,
/// exact sizes, and minimum RAM come from there, not from guessing). Two
/// non-chat entries in that same file (`TinyGarden-270M`,
/// `MobileActions-270M` — on-device UI-action models for a different
/// Gallery feature — and `Magic touch`, an image-segmentation tool) are
/// intentionally left out here.
///
/// Earlier revisions of this catalog pointed Gemma 4 E2B at a per-SoC
/// ahead-of-time-compiled `.litertlm` file (e.g. `..._qualcomm_sm8750`)
/// that only loads on the exact chip it was compiled for — confirmed
/// broken on a real device (see docs/ARCHITECTURE.md "Addendum 2"). Every
/// entry below is the plain, generic file Gallery itself ships, which runs
/// via LiteRT-LM's GPU/CPU delegates instead of one accelerator's compiled
/// graph.
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
    this.requiresHfAccount = false,
  });

  /// Stable internal id — used for local storage paths, not a remote path.
  final String id;

  final String displayName;

  /// One-line Persian summary shown right under the model name.
  final String description;

  /// A short "بهترین گزینه برای..." line — who this model suits.
  final String idealFor;

  /// Concrete, honest advantages shown as a bullet list in the picker.
  final List<String> advantages;

  /// Short Persian label, e.g. "توصیه‌شده" or "نیازمند رم بالا".
  final String badge;

  final int contextLength;

  /// Minimum device RAM Google's own Gallery app requires for this model —
  /// not a heuristic. Used directly by [DeviceCapabilityChecker].
  final int minRamGb;

  final List<ModelVariant> variants;

  /// Shown as an explicit warning on the model's card — set for models
  /// whose RAM requirement is high enough that most phones won't meet it.
  final String? compatibilityWarning;

  /// True for repos confirmed (or very likely, by the same "google/"-owned
  /// pattern) to be gated behind Hugging Face's Gemma license — a request
  /// without a valid, license-accepted access token gets 401/403 even
  /// against a `litert-community` mirror. See docs/ARCHITECTURE.md and
  /// `HfTokenSection` in Settings.
  final bool requiresHfAccount;

  ModelVariant get defaultVariant => variants.first;

  String fileNameFor(ModelVariant variant) => '${id}_${variant.id}.litertlm';
}

String _hfUrl(String modelId, String modelFile) =>
    'https://huggingface.co/$modelId/resolve/main/$modelFile';

String _highRamWarning(int gb) =>
    'این مدل به حداقل $gb گیگابایت رم نیاز دارد. روی گوشی‌های با رم کمتر ممکن است '
    'بارگذاری نشود یا بسیار کند اجرا شود.';

abstract final class ModelCatalog {
  static final gemma4E2b = ModelDefinition(
    id: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    description: 'نسخه سبک و عمومی جما ۴؛ برای گفتگوی روزمره روی اکثر گوشی‌ها.',
    idealFor: 'بهترین گزینه پیش‌فرض؛ گوشی‌های با ۸ گیگابایت رم یا بیشتر',
    advantages: [
      'یک فایل عمومی؛ نیازی به پردازنده خاص ندارد و روی اکثر گوشی‌ها اجرا می‌شود',
      'حجم دانلود کمتر (حدود ۲.۴ گیگابایت)',
      'مصرف حافظه و باتری پایین‌تر نسبت به نسخه‌های بزرگ‌تر',
      'پشتیبانی از ورودی تصویر و صدا، علاوه بر متن',
    ],
    badge: 'توصیه‌شده',
    contextLength: 32000,
    minRamGb: 8,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'litert-community/gemma-4-E2B-it-litert-lm',
          'gemma-4-E2B-it.litertlm',
        ),
        approximateSizeBytes: 2588147712,
      ),
    ],
  );

  static final gemma4E4b = ModelDefinition(
    id: 'gemma-4-e4b',
    displayName: 'Gemma 4 E4B',
    description: 'نسخه بزرگ‌تر جما ۴؛ درک و پاسخ‌دهی قوی‌تر، برای گوشی‌های پرقدرت.',
    idealFor: 'فقط برای گوشی‌های با حداقل ۱۲ گیگابایت رم',
    advantages: [
      'درک بهتر متن‌های طولانی و پیچیده',
      'استدلال و پاسخ‌دهی دقیق‌تر در موضوعات فنی و تخصصی',
      'کیفیت نگارش و انسجام پاسخ در گفتگوهای بلند بالاتر',
      'پشتیبانی از ورودی تصویر و صدا، علاوه بر متن',
    ],
    badge: 'نیازمند رم بالا',
    contextLength: 32000,
    minRamGb: 12,
    compatibilityWarning: _highRamWarning(12),
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'litert-community/gemma-4-E4B-it-litert-lm',
          'gemma-4-E4B-it.litertlm',
        ),
        approximateSizeBytes: 3659530240,
      ),
    ],
  );

  static final gemma3nE2b = ModelDefinition(
    id: 'gemma-3n-e2b',
    displayName: 'Gemma 3n E2B',
    description: 'مدل چندرسانه‌ای گوگل؛ علاوه بر متن، تصویر، صدا و ویدیو را هم می‌فهمد.',
    idealFor: 'گفتگوهایی که شامل تصویر یا صدا هستند، روی گوشی‌های با ۸ گیگابایت رم',
    advantages: [
      'ورودی چندرسانه‌ای واقعی: تصویر، صدا و ویدیو در کنار متن',
      'طراحی‌شده برای اجرای بهینه روی دستگاه‌های با منابع محدود',
      'کیفیت گفتگوی متنی قابل مقایسه با Gemma 4 E2B',
    ],
    badge: 'چندرسانه‌ای',
    contextLength: 32000,
    minRamGb: 8,
    requiresHfAccount: true,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'google/gemma-3n-E2B-it-litert-lm',
          'gemma-3n-E2B-it-int4.litertlm',
        ),
        approximateSizeBytes: 3655827456,
      ),
    ],
  );

  static final gemma3nE4b = ModelDefinition(
    id: 'gemma-3n-e4b',
    displayName: 'Gemma 3n E4B',
    description: 'نسخه بزرگ‌تر Gemma 3n؛ چندرسانه‌ای با کیفیت پاسخ بالاتر.',
    idealFor: 'فقط برای گوشی‌های با حداقل ۱۲ گیگابایت رم',
    advantages: [
      'ورودی چندرسانه‌ای: تصویر، صدا و ویدیو در کنار متن',
      'کیفیت درک و استدلال بالاتر از نسخه E2B',
    ],
    badge: 'نیازمند رم بالا',
    contextLength: 32000,
    minRamGb: 12,
    compatibilityWarning: _highRamWarning(12),
    requiresHfAccount: true,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'google/gemma-3n-E4B-it-litert-lm',
          'gemma-3n-E4B-it-int4.litertlm',
        ),
        approximateSizeBytes: 4919541760,
      ),
    ],
  );

  static final gemma3_1b = ModelDefinition(
    id: 'gemma3-1b',
    displayName: 'Gemma 3 1B',
    description: 'کوچک‌ترین و سبک‌ترین مدل موجود؛ برای پاسخ‌های سریع و ساده.',
    idealFor: 'گوشی‌های ضعیف‌تر یا فضای ذخیره‌سازی کم؛ پاسخ‌های کوتاه و سریع',
    advantages: [
      'حجم دانلود بسیار کم (حدود ۵۸۰ مگابایت)',
      'کمترین نیاز به رم در بین همه گزینه‌ها (۶ گیگابایت)',
      'بارگذاری و پاسخ‌دهی بسیار سریع',
    ],
    badge: 'سبک‌ترین',
    contextLength: 32000,
    minRamGb: 6,
    requiresHfAccount: true,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'litert-community/Gemma3-1B-IT',
          'gemma3-1b-it-int4.litertlm',
        ),
        approximateSizeBytes: 584417280,
      ),
    ],
  );

  static final qwen2_5 = ModelDefinition(
    id: 'qwen2-5-1-5b',
    displayName: 'Qwen 2.5 1.5B',
    description: 'مدل شرکت علی‌بابا؛ قوی در چند زبانگی و کدنویسی، در حجمی کوچک.',
    idealFor: 'سوالات مربوط به برنامه‌نویسی و گفتگوی چندزبانه',
    advantages: [
      'عملکرد خوب در تولید و توضیح کد برنامه‌نویسی',
      'پشتیبانی قوی از چند زبان مختلف',
      'حجم و نیاز به رم کم (۶ گیگابایت)',
    ],
    badge: 'مناسب کدنویسی',
    contextLength: 32000,
    minRamGb: 6,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'litert-community/Qwen2.5-1.5B-Instruct',
          'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
        ),
        approximateSizeBytes: 1597931520,
      ),
    ],
  );

  static final deepSeekR1Distill = ModelDefinition(
    id: 'deepseek-r1-distill-qwen-1-5b',
    displayName: 'DeepSeek R1 Distill 1.5B',
    description: 'نسخه فشرده‌شده از مدل استدلالی DeepSeek R1؛ برای تحلیل گام‌به‌گام.',
    idealFor: 'سوالاتی که نیاز به استدلال و تحلیل مرحله‌به‌مرحله دارند',
    advantages: [
      'استدلال گام‌به‌گام (Chain-of-Thought) قوی‌تر از مدل‌های هم‌اندازه',
      'مناسب برای مسائل ریاضی و منطقی',
      'حجم و نیاز به رم کم (۶ گیگابایت)',
    ],
    badge: 'استدلال قوی',
    contextLength: 32000,
    minRamGb: 6,
    variants: [
      ModelVariant(
        id: 'generic',
        downloadUrl: _hfUrl(
          'litert-community/DeepSeek-R1-Distill-Qwen-1.5B',
          'DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
        ),
        approximateSizeBytes: 1833451520,
      ),
    ],
  );

  /// Ordered roughly smallest/safest-RAM first — [gemma4E2b] stays the
  /// first "توصیه‌شده" pick since it is the best all-round balance of size,
  /// RAM requirement, and quality that Gallery itself defaults to.
  static final all = [
    gemma4E2b,
    gemma3_1b,
    qwen2_5,
    deepSeekR1Distill,
    gemma3nE2b,
    gemma4E4b,
    gemma3nE4b,
  ];

  static ModelDefinition byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => gemma4E2b);
}
