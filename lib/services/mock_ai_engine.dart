import 'dart:async';
import 'dart:math';

import 'package:ai_engine/ai_engine.dart';

/// **Development-only** stand-in for a real [AiEngine], used so the UI can
/// be built and tested without a downloaded model or native platform code.
///
/// Never wired up in a release build — see `lib/services/ai_engine_provider.dart`,
/// which only selects this when `kDebugMode` (or an explicit override) is
/// true, matching the "clearly marked mock engine, removed from production"
/// requirement in docs/ARCHITECTURE.md.
class MockAiEngine implements AiEngine {
  bool _loaded = false;
  bool _stopRequested = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadModel(String modelPath, {Backend backend = Backend.cpu}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<bool> isModelLoaded() async => _loaded;

  @override
  Future<ModelInfo> getModelInfo() async {
    return ModelInfo(
      modelId: 'mock-gemma-4-e2b',
      displayName: 'Gemma 4 E2B (Mock)',
      status: _loaded ? ModelStatus.loaded : ModelStatus.notInstalled,
      backend: Backend.cpu,
      contextLength: 8192,
    );
  }

  @override
  Future<void> stopGeneration() async {
    _stopRequested = true;
  }

  @override
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  }) {
    final controller = StreamController<GenerationChunk>();
    unawaited(_run(controller, messages));
    return controller.stream;
  }

  Future<void> _run(
    StreamController<GenerationChunk> controller,
    List<ChatMessage> messages,
  ) async {
    _stopRequested = false;
    final reply = _mockReplyFor(
      messages.isEmpty ? '' : messages.last.content,
    );
    final words = reply.split(' ');
    final random = Random();
    for (final word in words) {
      if (_stopRequested) break;
      await Future<void>.delayed(Duration(milliseconds: 20 + random.nextInt(40)));
      if (controller.isClosed) return;
      controller.add(GenerationChunk.token('$word '));
    }
    if (!controller.isClosed) {
      controller.add(const GenerationChunk.done());
      await controller.close();
    }
  }

  String _mockReplyFor(String prompt) {
    return '''این یک پاسخ نمایشی از **موتور آزمایشی** است (مدل واقعی هنوز بارگذاری نشده).

شما نوشتید: "$prompt"

نمونه‌ای از قابلیت‌های نمایش متن:

- فهرست‌های نقطه‌ای
- **متن پررنگ** و *مورب*
- کد درون‌خطی مثل `print("سلام")`

```python
def greet(name):
    return f"سلام {name}"
```

> این بخش برای نمایش نقل‌قول است.

برای دریافت پاسخ واقعی از جما، ابتدا مدل را از بخش تنظیمات ← مدل‌ها دانلود و بارگذاری کنید.''';
  }
}
