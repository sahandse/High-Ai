import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get modelId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors [ChatRole] from `package:ai_engine` as a plain string so this
/// table has no compile-time dependency on the engine package.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// True while a message is still streaming in — lets the UI distinguish
  /// "still generating" rows from finished ones after an app restart.
  BoolColumn get isComplete => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // SQLite ignores foreign key constraints (our cascade-delete on
      // Messages.conversationId) unless explicitly turned on per connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'high_ai');
  }

  Stream<List<Conversation>> watchConversations({String? searchQuery}) {
    final query = select(conversations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query.where((t) => t.title.contains(searchQuery.trim()));
    }
    return query.watch();
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(
      messages,
    )..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<Conversation> createConversation({
    required String id,
    required String title,
    required String modelId,
  }) async {
    final now = DateTime.now();
    final row = ConversationsCompanion.insert(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      modelId: modelId,
    );
    await into(conversations).insert(row);
    return Conversation(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      modelId: modelId,
    );
  }

  Future<void> renameConversation(String id, String title) {
    return (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> touchConversation(String id) {
    return (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteConversation(String id) {
    return (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  Future<void> insertMessage({
    required String id,
    required String conversationId,
    required String role,
    required String content,
    bool isComplete = true,
  }) async {
    await into(messages).insert(
      MessagesCompanion.insert(
        id: id,
        conversationId: conversationId,
        role: role,
        content: content,
        createdAt: DateTime.now(),
        isComplete: Value(isComplete),
      ),
    );
    await touchConversation(conversationId);
  }

  Future<void> updateMessageContent(
    String id,
    String content, {
    bool isComplete = true,
  }) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        content: Value(content),
        isComplete: Value(isComplete),
      ),
    );
  }

  Future<void> deleteMessage(String id) {
    return (delete(messages)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteMessagesFrom(String conversationId, DateTime from) {
    return (delete(messages)..where(
      (t) =>
          t.conversationId.equals(conversationId) &
          t.createdAt.isBiggerOrEqualValue(from),
    )).go();
  }
}
