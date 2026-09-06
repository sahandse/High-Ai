package com.highai.ai_engine

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Android host of the `ai_engine` control channel + token event stream —
 * see docs/ARCHITECTURE.md §2/§4. Bridges to the real LiteRT-LM Kotlin API
 * through [GemmaEngineBridge]; this file owns only channel plumbing,
 * threading, and error mapping to the friendly codes the Dart side expects
 * (`MODEL_NOT_AVAILABLE`, `MODEL_LOAD_FAILED`).
 */
class AiEnginePlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private val bridge = GemmaEngineBridge()
    private val scope = CoroutineScope(Dispatchers.Main + Job())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "ai_engine/control")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "ai_engine/tokens")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.launch { bridge.unload() }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> result.success(null)

            "loadModel" -> {
                val modelPath = call.argument<String>("modelPath")
                val backend = call.argument<String>("backend") ?: "cpu"
                if (modelPath == null) {
                    result.error("MODEL_NOT_AVAILABLE", "modelPath was not provided.", null)
                    return
                }
                scope.launch {
                    try {
                        withContext(Dispatchers.IO) { bridge.loadModel(modelPath, backend) }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("MODEL_LOAD_FAILED", e.message, null)
                    }
                }
            }

            "unloadModel" -> scope.launch {
                withContext(Dispatchers.IO) { bridge.unload() }
                result.success(null)
            }

            "isModelLoaded" -> result.success(bridge.isLoaded)

            "getModelInfo" -> result.success(
                mapOf(
                    "modelId" to "litert-community/gemma-4-E2B-it-litert-lm",
                    "displayName" to "Gemma 4 E2B",
                    "status" to if (bridge.isLoaded) "loaded" else "notInstalled",
                    "backend" to if (bridge.isLoaded) "cpu" else null,
                    "contextLength" to 8192,
                ),
            )

            "stopGeneration" -> {
                bridge.stop()
                result.success(null)
            }

            "generate" -> {
                val requestId = call.argument<Int>("requestId")
                @Suppress("UNCHECKED_CAST")
                val messages = call.argument<List<Map<String, Any?>>>("messages") ?: emptyList()
                if (requestId == null) {
                    result.error("MODEL_NOT_AVAILABLE", "requestId was not provided.", null)
                    return
                }
                val prompt = messages.joinToString("\n") { "${it["role"]}: ${it["content"]}" }
                scope.launch {
                    bridge.generate(
                        prompt = prompt,
                        onToken = { text ->
                            eventSink?.success(
                                mapOf("requestId" to requestId, "type" to "token", "textDelta" to text),
                            )
                        },
                        onDone = {
                            eventSink?.success(mapOf("requestId" to requestId, "type" to "done"))
                        },
                        onError = { message ->
                            eventSink?.success(
                                mapOf("requestId" to requestId, "type" to "error", "error" to message),
                            )
                        },
                    )
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
