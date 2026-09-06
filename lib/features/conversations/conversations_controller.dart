import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';

const _uuid = Uuid();

final conversationSearchQueryProvider = StateProvider<String>((ref) => '');

final conversationsListProvider = StreamProvider<List<Conversation>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = ref.watch(conversationSearchQueryProvider);
  return db.watchConversations(searchQuery: query.isEmpty ? null : query);
});

class ConversationsController {
  ConversationsController(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<String> createConversation({String title = 'گفتگوی جدید'}) async {
    final id = _uuid.v4();
    final activeModelId =
        _ref.read(modelManagerProvider).activeModelId ?? ModelCatalog.all.first.id;
    await _db.createConversation(id: id, title: title, modelId: activeModelId);
    return id;
  }

  Future<void> rename(String id, String title) => _db.renameConversation(id, title);

  Future<void> delete(String id) => _db.deleteConversation(id);
}

final conversationsControllerProvider = Provider<ConversationsController>(
  (ref) => ConversationsController(ref),
);
