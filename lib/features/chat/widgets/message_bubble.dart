import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/strings.dart';
import '../../../data/database.dart';
import '../../../domain/message_role.dart';
import 'markdown_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onRegenerate,
    this.isLastAssistantMessage = false,
  });

  final Message message;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final bool isLastAssistantMessage;

  bool get _isUser => MessageRole.fromDb(message.role) == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final align = _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            _isUser ? Strings.you : Strings.assistantName,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isUser
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: message.content.isEmpty && !message.isComplete
                  ? _ThinkingIndicator(colorScheme: colorScheme)
                  : MarkdownMessage(content: message.content),
            ),
          ),
          if (message.isComplete) _MessageActions(
            isUser: _isUser,
            isLastAssistantMessage: isLastAssistantMessage,
            onCopy: () => _copy(context),
            onEdit: () => _promptEdit(context),
            onDelete: onDelete,
            onRegenerate: onRegenerate,
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.copied)));
    }
  }

  Future<void> _promptEdit(BuildContext context) async {
    final controller = TextEditingController(text: message.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.edit),
        content: TextField(controller: controller, maxLines: 6, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) onEdit(result);
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(Strings.thinking),
      ],
    );
  }
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.isUser,
    required this.isLastAssistantMessage,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onRegenerate,
  });

  final bool isUser;
  final bool isLastAssistantMessage;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          tooltip: Strings.copy,
          icon: const Icon(Icons.copy_rounded),
          onPressed: onCopy,
        ),
        if (isUser)
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: Strings.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        if (!isUser && isLastAssistantMessage)
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: Strings.regenerate,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRegenerate,
          ),
        IconButton(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          tooltip: Strings.delete,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
