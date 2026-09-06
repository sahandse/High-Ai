/// All user-facing text, in Persian. Centralized here (rather than scattered
/// literals) so the whole app's copy stays consistent and easy to review
/// without pulling in a full ARB/gen-l10n pipeline this single-language v1
/// doesn't need yet.
abstract final class Strings {
  // App
  static const appName = 'های ای‌آی';

  // Chat
  static const newChat = 'گفتگوی جدید';
  static const messageHint = 'پیامی برای جما بنویسید...';
  static const send = 'ارسال';
  static const stop = 'توقف';
  static const regenerate = 'تولید دوباره';
  static const copy = 'کپی';
  static const copied = 'کپی شد';
  static const copyCode = 'کپی کد';
  static const edit = 'ویرایش';
  static const delete = 'حذف';
  static const you = 'شما';
  static const assistantName = 'جما';
  static const emptyConversation = 'گفتگو را با یک پیام شروع کنید';
  static const thinking = 'در حال نوشتن پاسخ...';

  // Offline indicator
  static const offlineIndicator = 'آفلاین • اجرای محلی روی دستگاه';

  // Conversations sidebar
  static const conversations = 'گفتگوها';
  static const searchConversations = 'جستجو در گفتگوها';
  static const renameConversation = 'تغییر نام گفتگو';
  static const deleteConversation = 'حذف گفتگو';
  static const deleteConversationConfirm =
      'این گفتگو برای همیشه حذف می‌شود. ادامه می‌دهید؟';
  static const noConversations = 'هنوز گفتگویی وجود ندارد';
  static const cancel = 'انصراف';
  static const confirm = 'تأیید';
  static const rename = 'تغییر نام';

  // Settings
  static const settings = 'تنظیمات';
  static const models = 'مدل‌ها';
  static const appearance = 'ظاهر برنامه';
  static const theme = 'پوسته';
  static const themeSystem = 'هماهنگ با سیستم';
  static const themeLight = 'روشن';
  static const themeDark = 'تیره';
  static const themePresetLabel = 'تم برنامه';
  static const themePresetClassic = 'پیش‌فرض (مینیمال)';
  static const themePresetChatgptLight = 'روشن، به‌سبک ChatGPT';
  static const themePresetClaudeDark = 'تیره، به‌سبک Claude';
  static const themeBrightnessLabel = 'حالت روشنایی';
  static const generationSettings = 'تنظیمات تولید پاسخ';
  static const temperature = 'دما (تنوع پاسخ)';
  static const topK = 'Top K';
  static const topP = 'Top P';
  static const maxOutputTokens = 'حداکثر طول پاسخ';
  static const resetDefaults = 'بازگشت به پیش‌فرض';
  static const invalidSettings = 'مقدار وارد شده نامعتبر است';

  // Models
  static const chooseModel = 'یک مدل را برای دانلود انتخاب کنید';
  static const modelStatusNotInstalled = 'نصب نشده';
  static const modelStatusDownloading = 'در حال دانلود';
  static const modelStatusPaused = 'متوقف‌شده';
  static const modelStatusVerifying = 'در حال بررسی صحت فایل';
  static const modelStatusReady = 'آماده بارگذاری';
  static const modelStatusLoading = 'در حال بارگذاری';
  static const modelStatusLoaded = 'بارگذاری‌شده و آماده گفتگو';
  static const modelStatusError = 'خطا';
  static const download = 'دانلود مدل';
  static const pause = 'توقف موقت';
  static const resumeDownload = 'ادامه دانلود';
  static const cancelDownload = 'لغو دانلود';
  static const retry = 'تلاش دوباره';
  static const load = 'بارگذاری مدل';
  static const unload = 'خارج کردن از حافظه';
  static const deleteModel = 'حذف مدل';
  static const redownload = 'دانلود مجدد';
  static const modelSize = 'حجم مدل';
  static const backend = 'پردازنده اجرا';
  static const storageUsage = 'فضای اشغال‌شده';
  static const freeStorage = 'فضای آزاد دستگاه';
  static const deviceRam = 'حافظه (RAM) دستگاه';
  static const insufficientStorageWarning =
      'فضای آزاد دستگاه برای این مدل کافی نیست.';
  static const lowRamWarning =
      'حافظه دستگاه کمتر از میزان توصیه‌شده است؛ ممکن است اجرا کند یا ناموفق باشد.';
  static const details = 'جزئیات خطا';
  static const useCpu = 'اجرا با پردازنده (CPU)';
  static const active = 'فعال';

  static String downloadProgress(String downloaded, String total, int percent) =>
      '$downloaded از $total ($percent٪)';

  static String downloadSpeed(String speedPerSecond) => '$speedPerSecond در ثانیه';

  static String etaLabel(String eta) => 'زمان باقی‌مانده: $eta';

  // Errors (friendly, never raw exceptions)
  static const errorModelMissing = 'مدل روی دستگاه شما نصب نشده است.';
  static const errorModelCorrupted =
      'فایل مدل آسیب دیده است. لطفاً دوباره دانلود کنید.';
  static const errorInsufficientStorage = 'فضای ذخیره‌سازی کافی نیست.';
  static const errorLoadFailed = 'بارگذاری جما روی این دستگاه ممکن نشد.';
  static const errorGenerationFailed = 'تولید پاسخ با خطا مواجه شد.';
  static const errorUnsupportedPlatform =
      'اجرای محلی هوش مصنوعی هنوز روی این پلتفرم پشتیبانی نمی‌شود.';
}
