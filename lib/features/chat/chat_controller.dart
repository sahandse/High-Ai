import 'package:ai_engine/ai_engine.dart' as engine;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/strings.dart';
import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../domain/message_role.dart';
import '../../services/ai_engine_provider.dart';
import '../../services/settings_service.dart';

const _uuid = Uuid();

final messagesProvider = StreamProvider.family<List<Message>, String>(
  (ref, conversationId) => ref.watch(databaseProvider).watchMessages(conversationId),
);

class ChatUiState {
  const ChatUiState({this.isGenerating = false, this.errorMessage});

  final bool isGenerating;
  final String? errorMessage;

  ChatUiState copyWith({bool? isGenerating, String? errorMessage}) {
    return ChatUiState(
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
    );
  }
}

class ChatController extends FamilyNotifier<ChatUiState, String> {
  late String _conversationId;

  @override
  ChatUiState build(String arg) {
    _conversationId = arg;
    ref.onDispose(() {
      // Best-effort: stop native generation if this screen goes away
      // mid-stream, so the engine doesn't keep burning cycles unseen.
      if (state.isGenerating) {
        ref.read(aiEngineProvider).stopGeneration();
      }
    });
    return const ChatUiState();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) return;

    await _db.insertMessage(
      id: _uuid.v4(),
      conversationId: _conversationId,
      role: MessageRole.user.toDb(),
      content: trimmed,
    );
    await _maybeSetDefaultTitle(trimmed);
    await _generateResponse();
  }

  Future<void> _maybeSetDefaultTitle(String firstMessage) async {
    final conversation = await (_db.select(
      _db.conversations,
    )..where((t) => t.id.equals(_conversationId))).getSingleOrNull();
    if (conversation != null && conversation.title == 'گفتگوی جدید') {
      final title = firstMessage.length > 40
          ? '${firstMessage.substring(0, 40)}…'
          : firstMessage;
      await _db.renameConversation(_conversationId, title);
    }
  }

  Future<void> _generateResponse() async {
    final history = await _db.watchMessages(_conversationId).first;
    final chatMessages = history
        .map(
          (m) => engine.ChatMessage(
            role: MessageRole.fromDb(m.role).toChatRole(),
            content: m.content,
          ),
        )
        .toList();

    final assistantId = _uuid.v4();
    await _db.insertMessage(
      id: assistantId,
      conversationId: _conversationId,
      role: MessageRole.assistant.toDb(),
      content: '',
      isComplete: false,
    );
    state = state.copyWith(isGenerating: true, errorMessage: null);

    final settings = ref.read(generationSettingsProvider);
    final buffer = StringBuffer();
    final aiEngine = ref.read(aiEngineProvider);

    try {
      await for (final chunk in aiEngine.generate(
        messages: chatMessages,
        settings: settings,
      )) {
        if (chunk.textDelta != null) {
          buffer.write(chunk.textDelta);
          await _db.updateMessageContent(
            assistantId,
            buffer.toString(),
            isComplete: false,
          );
        }
        if (chunk.isDone) {
          await _db.updateMessageContent(
            assistantId,
            chunk.isError
                ? (buffer.isEmpty
                      ? Strings.errorGenerationFailed
                      : buffer.toString())
                : buffer.toString(),
            isComplete: true,
          );
          state = state.copyWith(
            isGenerating: false,
            errorMessage: chunk.isError ? Strings.errorGenerationFailed : null,
          );
        }
      }
    } on engine.AiEngineException catch (e) {
      await _db.updateMessageContent(
        assistantId,
        buffer.isEmpty ? e.message : buffer.toString(),
        isComplete: true,
      );
      state = state.copyWith(isGenerating: false, errorMessage: e.message);
    }
  }

  Future<void> stopGeneration() async {
    await ref.read(aiEngineProvider).stopGeneration();
  }

  Future<void> regenerate() async {
    if (state.isGenerating) return;
    final history = await _db.watchMessages(_conversationId).first;
    if (history.isEmpty) return;
    // Drop the trailing assistant message (and any stray messages after the
    // last user turn), then regenerate from the same user prompt.
    final lastUserIndex = history.lastIndexWhere(
      (m) => MessageRole.fromDb(m.role) == MessageRole.user,
    );
    if (lastUserIndex == -1) return;
    for (final message in history.skip(lastUserIndex + 1)) {
      await _db.deleteMessage(message.id);
    }
    await _generateResponse();
  }

  Future<void> editMessage(String messageId, String newContent) async {
    if (state.isGenerating) return;
    final history = await _db.watchMessages(_conversationId).first;
    final index = history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    await _db.updateMessageContent(messageId, newContent.trim());
    for (final message in history.skip(index + 1)) {
      await _db.deleteMessage(message.id);
    }
    await _generateResponse();
  }

  Future<void> deleteMessage(String messageId) => _db.deleteMessage(messageId);
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatUiState, String>(
      ChatController.new,
    );
