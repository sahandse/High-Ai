package com.highai.ai_engine

import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import kotlinx.coroutines.flow.catch

/**
 * Thin wrapper around the official `litertlm-android` Kotlin API
 * (`com.google.ai.edge.litertlm:litertlm-android`, see
 * docs/ARCHITECTURE.md §0/§4).
 *
 * IMPORTANT — verify before shipping: this file was written from Google's
 * published `docs/api/kotlin/getting_started.md` for LiteRT-LM, inspected
 * through this environment's network restrictions (no direct access to
 * developers.google.com, and no Android SDK/AAR available here to compile
 * or decompile against). The class/method names below (`Engine`,
 * `EngineConfig`, `Backend.CPU()`, `Conversation`, `ConversationConfig`,
 * `sendMessageAsync`) match that documentation as read, but have not been
 * compiled against the real dependency. Before this ships: open this
 * module in Android Studio with the dependency resolved, fix any signature
 * mismatch the compiler reports, and delete this notice.
 */
class GemmaEngineBridge {
    private var engine: Engine? = null
    private var conversation: Conversation? = null

    val isLoaded: Boolean
        get() = conversation != null

    suspend fun loadModel(modelPath: String, backend: String) {
        unload()
        val resolvedBackend = when (backend) {
            "gpu" -> Backend.GPU()
            "npu" -> Backend.NPU()
            else -> Backend.CPU()
        }
        val newEngine = Engine(EngineConfig(modelPath = modelPath, backend = resolvedBackend))
        newEngine.initialize()
        engine = newEngine
        conversation = newEngine.createConversation(ConversationConfig())
    }

    suspend fun unload() {
        conversation?.close()
        engine?.close()
        conversation = null
        engine = null
    }

    /**
     * Streams response text for [messages] (already formatted as a single
     * prompt string by the caller — the plugin layer owns turning the
     * `ChatMessage` list into whatever prompt/history shape the real
     * `Conversation` API expects, once verified).
     */
    suspend fun generate(
        prompt: String,
        onToken: (String) -> Unit,
        onDone: () -> Unit,
        onError: (String) -> Unit,
    ) {
        val activeConversation = conversation
            ?: return onError("Model is not loaded.")
        activeConversation
            .sendMessageAsync(prompt)
            .catch { error -> onError(error.message ?: "Unknown generation error.") }
            .collect { chunk -> onToken(chunk.toString()) }
        onDone()
    }

    fun stop() {
        // TODO(verify): call the real cancellation API once confirmed —
        // e.g. `conversation?.cancel()` — LiteRT-LM's Kotlin docs mention
        // streaming cancellation but this wrapper hasn't been compiled
        // against the dependency to confirm the exact method name.
    }
}
