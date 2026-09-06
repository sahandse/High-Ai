import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/services/mock_ai_engine.dart';

void main() {
  group('MockAiEngine', () {
    test('reports not loaded until loadModel is called', () async {
      final engine = MockAiEngine();
      expect(await engine.isModelLoaded(), isFalse);
      await engine.loadModel('/fake/path');
      expect(await engine.isModelLoaded(), isTrue);
    });

    test('generate streams tokens then a terminal done chunk', () async {
      final engine = MockAiEngine();
      await engine.loadModel('/fake/path');

      final chunks = await engine
          .generate(
            messages: const [ChatMessage(role: ChatRole.user, content: 'سلام')],
          )
          .toList();

      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.isError, isFalse);
      expect(chunks.where((c) => c.textDelta != null), isNotEmpty);
    });

    test('stopGeneration ends the stream early without an error', () async {
      final engine = MockAiEngine();
      await engine.loadModel('/fake/path');

      final stream = engine.generate(
        messages: const [ChatMessage(role: ChatRole.user, content: 'سلام')],
      );
      final chunks = <GenerationChunk>[];
      final subscription = stream.listen(chunks.add);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await engine.stopGeneration();
      await subscription.asFuture<void>();
      await subscription.cancel();

      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.isError, isFalse);
    });
  });
}
