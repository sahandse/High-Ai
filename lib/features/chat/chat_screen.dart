import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../conversations/conversation_sidebar.dart';
import '../conversations/conversations_controller.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

const _wideLayoutBreakpoint = 800.0;

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        final body = conversationId == null
            ? const _NewChatBody()
            : _ConversationBody(conversationId: conversationId!);

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: ConversationSidebar(activeConversationId: conversationId),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: Drawer(
            child: SafeArea(
              child: ConversationSidebar(activeConversationId: conversationId),
            ),
          ),
          body: body,
        );
      },
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    return AppBar(
      leading: isWide
          ? null
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            Strings.offlineIndicator,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: Strings.settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}

class _NewChatBody extends ConsumerWidget {
  const _NewChatBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const _ChatAppBar(title: Strings.newChat),
        Expanded(
          child: Center(
            child: Text(
              Strings.emptyConversation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        Composer(
          isGenerating: false,
          onStop: () {},
          onSend: (text) async {
            final id = await ref
                .read(conversationsControllerProvider)
                .createConversation();
            if (context.mounted) {
              context.go('/chat/$id');
              // The new route rebuilds with a fresh ChatController for
              // `id`; read (not watch) it here since this widget is about
              // to be disposed by the navigation above.
              await ProviderScope.containerOf(
                context,
              ).read(chatControllerProvider(id).notifier).sendMessage(text);
            }
          },
        ),
      ],
    );
  }
}

class _ConversationBody extends ConsumerStatefulWidget {
  const _ConversationBody({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_ConversationBody> createState() => _ConversationBodyState();
}

class _ConversationBodyState extends ConsumerState<_ConversationBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final chatState = ref.watch(chatControllerProvider(widget.conversationId));
    final controller = ref.read(
      chatControllerProvider(widget.conversationId).notifier,
    );

    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Column(
      children: [
        const _ChatAppBar(title: Strings.assistantName),
        if (chatState.errorMessage != null)
          MaterialBanner(
            content: Text(chatState.errorMessage!),
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).clearMaterialBanners(),
                child: const Text(Strings.cancel),
              ),
            ],
          ),
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    Strings.emptyConversation,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              final lastAssistant = messages.lastWhere(
                (m) => m.role == 'assistant',
                orElse: () => messages.last,
              );
              final lastAssistantId = lastAssistant.id;
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return MessageBubble(
                    message: message,
                    isLastAssistantMessage: message.id == lastAssistantId,
                    onEdit: (newContent) =>
                        controller.editMessage(message.id, newContent),
                    onDelete: () => controller.deleteMessage(message.id),
                    onRegenerate: controller.regenerate,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('$error')),
          ),
        ),
        Composer(
          isGenerating: chatState.isGenerating,
          onSend: controller.sendMessage,
          onStop: controller.stopGeneration,
        ),
      ],
    );
  }
}
