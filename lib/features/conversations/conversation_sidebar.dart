import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../data/database.dart';
import 'conversations_controller.dart';

class ConversationSidebar extends ConsumerWidget {
  const ConversationSidebar({super.key, this.activeConversationId});

  final String? activeConversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsListProvider);
    final controller = ref.read(conversationsControllerProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final id = await controller.createConversation();
              if (context.mounted) context.go('/chat/$id');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text(Strings.newChat),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: Strings.searchConversations,
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: (value) =>
                ref.read(conversationSearchQueryProvider.notifier).state = value,
          ),
        ),
        Expanded(
          child: conversationsAsync.when(
            data: (conversations) => conversations.isEmpty
                ? const Center(child: Text(Strings.noConversations))
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationTile(
                        conversation: conversation,
                        isActive: conversation.id == activeConversationId,
                        onTap: () => context.go('/chat/${conversation.id}'),
                        onRename: () =>
                            _promptRename(context, controller, conversation),
                        onDelete: () =>
                            _confirmDelete(context, controller, conversation),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('$error')),
          ),
        ),
      ],
    );
  }

  Future<void> _promptRename(
    BuildContext context,
    ConversationsController controller,
    Conversation conversation,
  ) async {
    final textController = TextEditingController(text: conversation.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.renameConversation),
        content: TextField(controller: textController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text(Strings.rename),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await controller.rename(conversation.id, newTitle.trim());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ConversationsController controller,
    Conversation conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.deleteConversation),
        content: const Text(Strings.deleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.delete(conversation.id);
      if (context.mounted) context.go('/');
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: isActive,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          if (value == 'rename') onRename();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text(Strings.renameConversation)),
          PopupMenuItem(value: 'delete', child: Text(Strings.deleteConversation)),
        ],
      ),
    );
  }
}
