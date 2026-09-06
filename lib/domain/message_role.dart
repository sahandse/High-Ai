import 'package:ai_engine/ai_engine.dart';

/// App-level mirror of [ChatRole] that also knows how to (de)serialize to
/// the plain string stored in the `messages.role` database column.
enum MessageRole {
  user,
  assistant;

  String toDb() => name;

  static MessageRole fromDb(String value) => MessageRole.values.byName(value);

  ChatRole toChatRole() =>
      this == MessageRole.user ? ChatRole.user : ChatRole.assistant;
}
