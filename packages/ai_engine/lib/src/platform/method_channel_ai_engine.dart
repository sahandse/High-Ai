import 'dart:async';

import 'package:flutter/services.dart';

import '../ai_engine.dart';
import '../exceptions.dart';
import '../models/backend.dart';
import '../models/chat_message.dart';
import '../models/generation_chunk.dart';
import '../models/generation_settings.dart';
import '../models/model_info.dart';
import '../models/model_status.dart';

/// Android implementation, bridging to the Kotlin `litertlm-android` API
/// via platform channels — see docs/ARCHITECTURE.md §2/§4.
///
/// Control calls (init/load/unload/stop) go over a [MethodChannel]; the
/// token stream comes over a single shared [EventChannel] multiplexed by a
/// per-call [_requestId], since Flutter does not support opening a fresh
/// EventChannel per call cheaply. This keeps exactly one platform-channel
/// message per generated token, which is negligible next to Gemma 4 E2B's
/// on-device token rate (see docs/ARCHITECTURE.md §2 for the throughput
/// reasoning behind not using FFI here).
class MethodChannelAiEngine implements AiEngine {
  MethodChannelAiEngine({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel('ai_engine/control'),
       _eventChannel = eventChannel ?? const EventChannel('ai_engine/tokens');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<Object?, Object?>>? _events;
  int _nextRequestId = 0;

  Stream<Map<Object?, Object?>> get _eventStream =>
      _events ??= _eventChannel.receiveBroadcastStream().cast();

  @override
  Future<void> initialize() async {
    await _invoke('initialize');
  }

  @override
  Future<void> loadModel(
    String modelPath, {
    Backend backend = Backend.cpu,
  }) async {
    await _invoke('loadModel', {
      'modelPath': modelPath,
      'backend': backend.name,
    });
  }

  @override
  Future<void> unloadModel() async {
    await _invoke('unloadModel');
  }

  @override
  Future<bool> isModelLoaded() async {
    final result = await _invoke('isModelLoaded');
    return result as bool? ?? false;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    final result = await _invoke('getModelInfo');
    final map = Map<Object?, Object?>.from(result as Map);
    return ModelInfo(
      modelId: map['modelId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      status: ModelStatus.values.byName(
        map['status'] as String? ?? 'notInstalled',
      ),
      backend: (map['backend'] as String?) == null
          ? null
          : Backend.values.byName(map['backend'] as String),
      sizeOnDiskBytes: (map['sizeOnDiskBytes'] as num?)?.toInt(),
      contextLength: (map['contextLength'] as num?)?.toInt(),
      localPath: map['localPath'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  @override
  Future<void> stopGeneration() async {
    await _invoke('stopGeneration');
  }

  @override
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  }) {
    final requestId = _nextRequestId++;
    final controller = StreamController<GenerationChunk>();
    late final StreamSubscription<Map<Object?, Object?>> subscription;

    controller.onListen = () {
      subscription = _eventStream.listen(
        (event) {
          if (event['requestId'] != requestId) return;
          final type = event['type'] as String?;
          switch (type) {
            case 'token':
              controller.add(
                GenerationChunk.token(event['textDelta'] as String? ?? ''),
              );
            case 'done':
              controller.add(const GenerationChunk.done());
              controller.close();
            case 'error':
              controller.add(
                GenerationChunk.error(
                  event['error'] as String? ?? 'Unknown generation error.',
                ),
              );
              controller.close();
          }
        },
        onError: (Object error) {
          controller.add(GenerationChunk.error(error.toString()));
          controller.close();
        },
      );

      _invoke('generate', {
        'requestId': requestId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'settings': (settings ?? const GenerationSettings()).toJson(),
      }).catchError((Object error) {
        controller.add(GenerationChunk.error(error.toString()));
        controller.close();
        return null;
      });
    };

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methodChannel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'MODEL_NOT_AVAILABLE' => ModelNotAvailableException(
          e.message ?? 'Model is not available.',
        ),
        'MODEL_LOAD_FAILED' => ModelLoadException(
          e.message ?? 'Failed to load the model.',
        ),
        _ => GenerationException(e.message ?? 'Native engine error.'),
      };
    }
  }
}
