/// Hardware backend LiteRT-LM should run the model on.
///
/// Mirrors the backend choices exposed by LiteRT-LM's Kotlin/C++ APIs
/// (see docs/ARCHITECTURE.md §4). Not every backend is available on every
/// device; [AiEngine.loadModel] falls back to [cpu] on failure and reports
/// the effective backend via [ModelInfo.backend].
enum Backend { cpu, gpu, npu }
