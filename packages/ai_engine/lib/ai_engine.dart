/// Platform-agnostic local LLM inference interface for High-Ai.
///
/// The app depends only on this library — never on a specific platform
/// implementation. See docs/ARCHITECTURE.md for the design rationale.
library;

export 'src/ai_engine.dart';
export 'src/create_ai_engine.dart';
export 'src/exceptions.dart';
export 'src/models/backend.dart';
export 'src/models/chat_message.dart';
export 'src/models/chat_role.dart';
export 'src/models/generation_chunk.dart';
export 'src/models/generation_settings.dart';
export 'src/models/model_info.dart';
export 'src/models/model_status.dart';
