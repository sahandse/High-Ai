package com.highai.ai_engine

import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.EmbeddingEngine
import com.google.ai.edge.litertlm.EmbeddingEngineConfig
import com.google.ai.edge.litertlm.EmbeddingOptions
import com.google.ai.edge.litertlm.InputData

/**
 * Dedicated LiteRT-LM embedding bridge.
 *
 * It intentionally does not share lifecycle with [GemmaEngineBridge], so
 * semantic retrieval can run while the conversational model remains loaded.
 */
class EmbeddingGemmaBridge {
    private var engine: EmbeddingEngine? = null

    val isLoaded: Boolean
        get() = engine?.isInitialized() == true

    fun loadModel(modelPath: String, backend: String) {
        unload()
        val resolvedBackend = when (backend) {
            "gpu" -> Backend.GPU()
            "npu" -> Backend.NPU()
            else -> Backend.CPU()
        }
        engine = EmbeddingEngine(
            EmbeddingEngineConfig(
                modelPath = modelPath,
                backend = resolvedBackend,
                maxInputLength = 2048,
            ),
        ).also { it.initialize() }
    }

    fun embedText(
        text: String,
        outputSize: Int,
        normalize: Boolean,
    ): FloatArray {
        require(text.isNotBlank()) { "Text must not be blank." }
        val activeEngine = checkNotNull(engine) { "Embedding model is not loaded." }
        val response = activeEngine.computeEmbedding(
            listOf(InputData.Text(text)),
            EmbeddingOptions(
                normalize = normalize,
                insertSpecialTokens = true,
                outputSize = outputSize,
            ),
        )
        return response.embedding
    }

    fun unload() {
        val activeEngine = engine
        if (activeEngine != null && activeEngine.isInitialized()) {
            activeEngine.close()
        }
        engine = null
    }
}
