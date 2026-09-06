import 'dart:io';

import 'ai_engine.dart';
import 'platform/method_channel_ai_engine.dart';
import 'platform/unsupported_ai_engine.dart';

/// Returns the [AiEngine] implementation appropriate for the current
/// platform. The app calls this exactly once at startup and never inspects
/// [Platform] itself — see docs/ARCHITECTURE.md §2.
///
/// Windows support is implemented via a native FFI bridge that is built and
/// registered separately (see `windows/` and docs/ARCHITECTURE.md §5); this
/// factory still returns [MethodChannelAiEngine]'s sibling FFI engine once
/// that lands. Until then, and on any other desktop platform, an engine
/// that reports itself honestly as unsupported is returned instead of a
/// fake/mocked one — mocks belong only in app-level dev tooling, never in
/// this package.
AiEngine createAiEngine() {
  if (Platform.isAndroid) {
    return MethodChannelAiEngine();
  }
  return UnsupportedAiEngine(Platform.operatingSystem);
}
