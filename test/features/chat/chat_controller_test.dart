import 'package:ai_engine/ai_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/data/database.dart';
import 'package:high_ai/data/database_provider.dart';
import 'package:high_ai/features/chat/chat_controller.dart';
import 'package:high_ai/services/ai_engine_provider.dart';
import 'package:high_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic [AiEngine] double: echoes a fixed reply, splitting it into
/// two token chunks so streaming/append logic is actually exercised.
class FakeAiEngine implements AiEngine {
  bool stopped = false;
  bool shouldError = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadModel(String modelPath, {Backend backend = Backend.cpu}) async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<bool> isModelLoaded() async => true;

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
    modelId: 'fake',
    displayName: 'Fake',
    status: ModelStatus.loaded,
  );

  @override
  Future<void> stopGeneration() async {
    stopped = true;
  }

  @override
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  }) async* {
    if (shouldError) {
      yield const GenerationChunk.error('boom');
      return;
    }
    yield const GenerationChunk.token('سلام ');
    yield const GenerationChunk.token('دنیا');
    yield const GenerationChunk.done();
  }
}

void main() {
  // Each test below opens its own isolated in-memory database, so the
  // "multiple databases" warning drift emits (aimed at accidental shared
  // executors) is a false positive here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ProviderContainer container;
  late FakeAiEngine fakeEngine;
  const conversationId = 'conv-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeEngine = FakeAiEngine();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => AppDatabase(NativeDatabase.memory()),
        ),
        aiEngineProvider.overrideWithValue(fakeEngine),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(databaseProvider)
        .createConversation(id: conversationId, title: 'گفتگوی جدید', modelId: 'm');
  });

  test('sendMessage persists the user turn and the streamed reply', () async {
    final controller = container.read(chatControllerProvider(conversationId).notifier);

    await controller.sendMessage('سلام');

    final messages = await container
        .read(databaseProvider)
        .watchMessages(conversationId)
        .first;

    expect(messages, hasLength(2));
    expect(messages[0].role, 'user');
    expect(messages[0].content, 'سلام');
    expect(messages[1].role, 'assistant');
    expect(messages[1].content, 'سلام دنیا');
    expect(messages[1].isComplete, isTrue);

    final state = container.read(chatControllerProvider(conversationId));
    expect(state.isGenerating, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('sets a default title from the first message', () async {
    final controller = container.read(chatControllerProvider(conversationId).notifier);
    await controller.sendMessage('اولین پیام من');

    final conversation = await (container.read(databaseProvider).select(
      container.read(databaseProvider).conversations,
    )..where((t) => t.id.equals(conversationId))).getSingle();

    expect(conversation.title, 'اولین پیام من');
  });

  test('a generation error is surfaced without losing the user message', () async {
    fakeEngine.shouldError = true;
    final controller = container.read(chatControllerProvider(conversationId).notifier);

    await controller.sendMessage('سلام');

    final state = container.read(chatControllerProvider(conversationId));
    expect(state.errorMessage, isNotNull);

    final messages = await container
        .read(databaseProvider)
        .watchMessages(conversationId)
        .first;
    expect(messages[0].content, 'سلام');
  });

  test('regenerate drops the previous assistant reply and asks again', () async {
    final controller = container.read(chatControllerProvider(conversationId).notifier);
    await controller.sendMessage('سلام');

    await controller.regenerate();

    final messages = await container
        .read(databaseProvider)
        .watchMessages(conversationId)
        .first;
    expect(messages, hasLength(2));
    expect(messages[1].role, 'assistant');
    expect(messages[1].content, 'سلام دنیا');
  });

  test('editMessage updates content and regenerates from that point', () async {
    final controller = container.read(chatControllerProvider(conversationId).notifier);
    await controller.sendMessage('نسخه اول');

    final firstPass = await container
        .read(databaseProvider)
        .watchMessages(conversationId)
        .first;
    final userMessageId = firstPass.first.id;

    await controller.editMessage(userMessageId, 'نسخه ویرایش‌شده');

    final messages = await container
        .read(databaseProvider)
        .watchMessages(conversationId)
        .first;
    expect(messages, hasLength(2));
    expect(messages[0].content, 'نسخه ویرایش‌شده');
  });
}
