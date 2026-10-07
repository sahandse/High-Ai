package com.highai.ai_engine

import android.content.Context
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.retrieval.universalembedder.UniversalEmbedder
import com.google.mediapipe.tasks.retrieval.universalembedder.UniversalEmbedderOptions
import kotlin.math.sqrt

/**
 * Android EmbeddingGemma 2 bridge using the same MediaPipe UniversalEmbedder
 * path as Google's AI Edge Gallery reference app.
 *
 * Chat and embedding engines intentionally have independent lifecycles so
 * semantic retrieval can run without unloading the conversational model.
 */
class EmbeddingGemmaBridge(
    private val context: Context,
) {
    private var embedder: UniversalEmbedder? = null

    val isLoaded: Boolean
        get() = embedder != null

    fun loadModel(modelPath: String, backend: String) {
        unload()

        val requestedDelegate = when (backend) {
            "gpu" -> Delegate.GPU
            "npu" -> Delegate.NPU
            else -> Delegate.CPU
        }

        embedder = try {
            createEmbedder(modelPath, requestedDelegate)
        } catch (error: Throwable) {
            if (requestedDelegate == Delegate.CPU) throw error
            // Retrieval is an enhancement. If an accelerator is unavailable on
            // a device, recover on CPU instead of making smart memory unusable.
            createEmbedder(modelPath, Delegate.CPU)
        }
    }

    private fun createEmbedder(
        modelPath: String,
        delegate: Delegate,
    ): UniversalEmbedder {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(modelPath)
            .setDelegate(delegate)
            .build()

        val options = UniversalEmbedderOptions.builder()
            .setBaseOptions(baseOptions)
            .setL2Normalize(false)
            .setMaxInputLength(2048)
            .build()

        return UniversalEmbedder.createFromOptions(context, options)
    }

    fun embedText(
        text: String,
        outputSize: Int,
        normalize: Boolean,
    ): FloatArray {
        require(text.isNotBlank()) { "Text must not be blank." }
        require(outputSize in setOf(128, 256, 512, 768)) {
            "Embedding outputSize must be one of 128, 256, 512, or 768."
        }

        val activeEmbedder = checkNotNull(embedder) {
            "Embedding model is not loaded."
        }

        val fullVector = activeEmbedder
            .embedText(text)
            .embeddings()
            .firstOrNull()
            ?.floatEmbedding()
            ?: error("EmbeddingGemma 2 returned no embedding.")

        require(fullVector.size >= outputSize) {
            "Embedding model returned ${fullVector.size} dimensions; requested $outputSize."
        }

        val vector = fullVector.copyOf(outputSize)
        if (!normalize) return vector

        var squaredNorm = 0.0
        for (value in vector) {
            squaredNorm += value * value
        }
        val norm = sqrt(squaredNorm)
        if (norm == 0.0) return vector

        for (index in vector.indices) {
            vector[index] = (vector[index] / norm).toFloat()
        }
        return vector
    }

    fun unload() {
        embedder?.close()
        embedder = null
    }
}
