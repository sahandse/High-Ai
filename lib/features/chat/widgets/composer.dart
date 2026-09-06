import 'package:flutter/material.dart';

import '../../../core/strings.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty || widget.isGenerating) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: Strings.messageHint),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          widget.isGenerating
              ? IconButton.filledTonal(
                  tooltip: Strings.stop,
                  icon: const Icon(Icons.stop_rounded),
                  onPressed: widget.onStop,
                )
              : IconButton.filled(
                  tooltip: Strings.send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: _submit,
                ),
        ],
      ),
    );
  }
}
