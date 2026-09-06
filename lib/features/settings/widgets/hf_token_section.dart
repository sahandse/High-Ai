import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../services/hf_token_storage.dart';

/// Lets the user add/remove a Hugging Face access token, needed for gated
/// model repos (the Gemma family — confirmed 401/403 on a real device, see
/// docs/ARCHITECTURE.md) that reject anonymous requests even to a
/// `litert-community` mirror.
class HfTokenSection extends ConsumerStatefulWidget {
  const HfTokenSection({super.key});

  @override
  ConsumerState<HfTokenSection> createState() => _HfTokenSectionState();
}

class _HfTokenSectionState extends ConsumerState<HfTokenSection> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenAsync = ref.watch(hfTokenProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Strings.hfTokenSectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          Strings.hfTokenDescription,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        SelectableText(
          Strings.hfTokenGetOne,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 12),
        tokenAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text('$error', style: TextStyle(color: colorScheme.error)),
          data: (token) {
            final hasToken = token != null && token.isNotEmpty;
            if (hasToken) {
              return Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('•' * 12 + token.substring(token.length - 4))),
                  TextButton(
                    onPressed: () => ref.read(hfTokenProvider.notifier).setToken(null),
                    child: const Text(Strings.hfTokenRemove),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: Strings.hfTokenFieldLabel,
                    hintText: Strings.hfTokenFieldHint,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: () async {
                      final value = _controller.text.trim();
                      if (value.isEmpty) return;
                      await ref.read(hfTokenProvider.notifier).setToken(value);
                      _controller.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text(Strings.hfTokenSaved)));
                      }
                    },
                    child: const Text(Strings.hfTokenSave),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
