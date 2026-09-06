import 'chat_role.dart';

/// A single turn passed to [AiEngine.generate] as conversation context.
///
/// This is a plain, engine-agnostic value type — it intentionally does not
/// carry any database/UI concerns (ids, timestamps, edit history). Callers
/// map their own persisted message model into this shape before calling the
/// engine.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'content': content,
  };
}
