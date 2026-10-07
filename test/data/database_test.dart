import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('createConversation then watchConversations reflects it', () async {
    await db.createConversation(id: 'c1', title: 'اول', modelId: 'gemma');

    final conversations = await db.watchConversations().first;
    expect(conversations, hasLength(1));
    expect(conversations.single.title, 'اول');
  });

  test('search filters conversations by title', () async {
    await db.createConversation(id: 'c1', title: 'درباره فلاتر', modelId: 'gemma');
    await db.createConversation(id: 'c2', title: 'درباره پایتون', modelId: 'gemma');

    final results = await db.watchConversations(searchQuery: 'فلاتر').first;
    expect(results, hasLength(1));
    expect(results.single.id, 'c1');
  });

  test('deleting a conversation cascades to its messages', () async {
    await db.createConversation(id: 'c1', title: 'اول', modelId: 'gemma');
    await db.insertMessage(
      id: 'm1',
      conversationId: 'c1',
      role: 'user',
      content: 'سلام',
    );

    await db.deleteConversation('c1');

    final messages = await db.watchMessages('c1').first;
    expect(messages, isEmpty);
  });

  test('updateMessageContent overwrites content and completion flag', () async {
    await db.createConversation(id: 'c1', title: 'اول', modelId: 'gemma');
    await db.insertMessage(
      id: 'm1',
      conversationId: 'c1',
      role: 'assistant',
      content: 'در حال نوشتن',
      isComplete: false,
    );

    await db.updateMessageContent('m1', 'پاسخ کامل شد', isComplete: true);

    final messages = await db.watchMessages('c1').first;
    expect(messages.single.content, 'پاسخ کامل شد');
    expect(messages.single.isComplete, isTrue);
  });

  test('deleteMessagesFrom removes messages at or after a timestamp', () async {
    await db.createConversation(id: 'c1', title: 'اول', modelId: 'gemma');

    // Use explicit timestamps more than one second apart. Drift's default
    // SQLite DateTime representation is second-granular, so relying on a
    // few milliseconds of wall-clock delay makes this test flaky.
    final before = DateTime.utc(2026, 1, 1, 12);
    final cutoff = before.add(const Duration(seconds: 2));
    final after = before.add(const Duration(seconds: 4));

    await db.into(db.messages).insert(
      MessagesCompanion.insert(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'یک',
        createdAt: before,
      ),
    );
    await db.into(db.messages).insert(
      MessagesCompanion.insert(
        id: 'm2',
        conversationId: 'c1',
        role: 'user',
        content: 'دو',
        createdAt: after,
      ),
    );

    await db.deleteMessagesFrom('c1', cutoff);

    final messages = await db.watchMessages('c1').first;
    expect(messages.map((m) => m.id), ['m1']);
  });
}
