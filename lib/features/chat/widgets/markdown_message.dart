import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/strings.dart';

/// Renders assistant/user message content as Flutter widgets (headings,
/// paragraphs, bold/italic, lists, blockquotes, inline code) via
/// `flutter_markdown_plus`, with fenced code blocks swapped out for a
/// syntax-highlighted view plus a copy button — no WebView anywhere in the
/// render path, per docs/ARCHITECTURE.md.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: content.isEmpty ? ' ' : content,
      selectable: true,
      builders: {'code': _CodeBlockBuilder(context)},
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium,
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            right: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
      ),
    );
  }
}

/// Overrides rendering of `code` elements so a *fenced* code block (one
/// whose element carries a `class="language-x"` from the ```lang fence)
/// gets syntax highlighting + a copy button, while inline code spans fall
/// back to the default styling from [MarkdownStyleSheet].
class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder(this.context);

  final BuildContext context;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final className = element.attributes['class'] as String?;
    if (className == null || !className.startsWith('language-')) {
      return null; // inline code — let the default styleSheet handle it.
    }
    final language = className.substring('language-'.length);
    final code = element.textContent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  language,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const Spacer(),
              IconButton(
                iconSize: 18,
                tooltip: Strings.copyCode,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(Strings.copied)),
                    );
                  }
                },
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: HighlightView(
              code,
              language: language,
              theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
