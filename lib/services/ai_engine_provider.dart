import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_ai_engine.dart';

/// Set at build/run time with `--dart-define=USE_MOCK_AI_ENGINE=true` for UI
/// development without a real device/model. Defaults to `false` — release
/// builds always get the real, platform-selected engine from
/// `createAiEngine()`. This is the single switch that decides whether
/// [MockAiEngine] is reachable at all; nothing else in the app can turn it
/// on by accident.
const bool _useMockAiEngine = bool.fromEnvironment(
  'USE_MOCK_AI_ENGINE',
  defaultValue: false,
);

final aiEngineProvider = Provider<AiEngine>((ref) {
  if (_useMockAiEngine) {
    assert(() {
      debugPrint('ai_engine: using MockAiEngine (USE_MOCK_AI_ENGINE=true)');
      return true;
    }());
    return MockAiEngine();
  }
  return createAiEngine();
});
