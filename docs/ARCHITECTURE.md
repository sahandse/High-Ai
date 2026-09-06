# High-Ai — Offline Gemma Chat App: Architecture (Phase 1)

Status: **research complete, proposal for approval**. No production inference code has been
written yet. This document is the output of inspecting the official repositories on
2026-09-06:

- `google-ai-edge/LiteRT-LM` (GitHub, README + `docs/api/{cpp,kotlin}` + issues #2154 / #2529)
- `google-ai-edge/gallery` (GitHub README — implementation details are not published there)
- `litert-community/gemma-4-E2B-it-litert-lm` (Hugging Face, via search-engine cache — direct
  fetch of huggingface.co is blocked from this environment's egress proxy)

`developers.google.com` and `deepwiki.com` were also blocked by egress policy; everything below
is sourced from what GitHub actually serves (README, docs, issues) plus search-engine snippets
of the blocked pages. Anything not directly confirmed is called out explicitly as **unverified —
confirm at implementation time**.

---

## 0. What the official sources actually say (facts, not assumptions)

1. **LiteRT-LM** is Google's production on-device LLM runtime (already shipping in Chrome,
   Chromebook Plus, Pixel Watch). Targets Android, iOS, Web, Desktop, IoT.
2. **Per-language API maturity** (from the repo README and `docs/api/`):
   - **C++** — stable, the "real" API. `docs/api/cpp/` exists.
   - **Kotlin/Java** — stable, official, for **Android and plain JVM**, distributed as Maven
     artifacts: `com.google.ai.edge.litertlm:litertlm-android` and `...:litertlm-jvm`.
     `docs/api/kotlin/getting_started.md` exists and documents a real, usable API:
     - `Engine(EngineConfig(modelPath = ..., backend = Backend.CPU()))`, then
       `engine.initialize()` (documented as slow — must run off the UI thread).
     - `engine.createConversation(ConversationConfig?)` → `Conversation` (`AutoCloseable`).
     - Streaming via `conversation.sendMessageAsync(text)` returning a Kotlin `Flow<...>`
       (`.collect { }`), or a callback (`MessageCallback.onMessage/onDone/onError`).
     - Everything is `close()`-based lifecycle management (`Engine`, `Conversation`).
   - **Python** — stable, prototyping-oriented.
   - **Swift** — early preview, iOS/macOS only.
   - **JavaScript/Web** — early preview.
   - **Dart/Flutter** — **no official binding exists.** We are building this ourselves.
   - **C API** — exists **internally** in the repo (`runtime/c`, a Bazel `cc_library` /
     `cc_binary(linkshared=True)` target) but is **explicitly not published as a prebuilt,
     versioned shared library**, and upstream maintainers describe the **C ABI as unstable**.
     Two open feature requests confirm this directly:
     - Issue **#2154** ("public shared-library build target for the C API") was closed as a
       duplicate of #2529.
     - Issue **#2529** (opened by a Tauri desktop-app author, i.e. exactly our situation) states
       plainly: *"the C-API shared library exists only as an internal `cc_binary(linkshared=1)`
       build target… there is no published prebuilt shared library for desktop platforms… the C
       ABI remains unstable due to ongoing API development."*
   - **Build systems**: Bazel is the primary, fully-supported build system for all platforms.
     CMake exists (`CMakeLists.txt`, `CMakePresets.json`) but is described as experimental with
     limited (primarily Linux) platform coverage. **There is no confirmed, maintained Windows
     CMake path today** — this is the single biggest technical risk in this project (see §10).
3. **Model artifacts**: the Hugging Face repo for `gemma-4-E2B-it` does **not** host one universal
   `.litertlm` file. It hosts **hardware-specific compiled variants**, e.g.:
   - `gemma-4-E2B-it_Google_Tensor_G5.litertlm` (~3.11 GB)
   - `gemma-4-E2B-it_intel_PTL.litertlm` (~2.95 GB)
   - `gemma-4-E2B-it_qualcomm_sm8750.litertlm` (~3.02 GB)

   This is a **deviation from the spec's assumption of a single ~2.6 GB file** — the actual sizes
   are closer to 3 GB and are per-SoC. The model uses mixed 2/4/8-bit quantized weights (as low as
   ~0.8 GB resident for text-only, plus ~1.12 GB of memory-mapped embedding weights). **Action
   item for Phase 4**: enumerate the real file list from the HF repo tree at implementation time
   (this environment cannot reach huggingface.co directly; do it from a dev machine or via the
   `huggingface_hub` API from a non-restricted network) and pick the right artifact for the
   running device/backend, with a CPU-generic fallback if one exists in the repo.
4. **Gallery app**: its README does not disclose whether it's Flutter or native Kotlin/Compose —
   direct inspection of `Android/` source wasn't reachable from this pass. Since the Kotlin
   `litertlm-android` API is confirmed stable and documented on its own, we do not need Gallery's
   source to design the Android integration; it is a UX reference only, not an API source.

**Conclusion**: the officially-supported, low-risk path is **Android via the Kotlin API**.
Windows/macOS require us to build LiteRT-LM's C++ engine from source ourselves and put a stable
ABI around it, because upstream has explicitly declined to publish one. This is exactly the
situation described in the task brief ("create a small native wrapper with a stable C ABI"), so
the brief's architecture is directionally correct — we're confirming it's *necessary*, not
optional.

---

## 1. Flutter architecture

Standard layered app, single codebase for Android/Windows/macOS:

```
lib/
  app/            # MaterialApp.router, theme (Material 3, light/dark/system), go_router config
  core/           # result/error types, constants, extensions, logging
  domain/         # entities (Conversation, Message, GenerationSettings) + repository interfaces
  data/           # Drift database, DAOs, repositories (implements domain interfaces)
  services/       # ModelDownloadManager, ModelManager (lifecycle), AiEngine selection/DI
  features/
    chat/         # chat screen, message list, composer, streaming state (Riverpod)
    conversations/# sidebar/list, search, rename, delete
    models/       # Settings → Models screen, download/verify/load UI
    settings/     # generation settings (temperature/topK/topP/maxTokens), theme
  main.dart
```

- **State management**: Riverpod (`flutter_riverpod` + code-gen `riverpod_generator`). Chosen
  over Bloc/Provider because streaming token generation maps naturally onto a `StreamProvider`/
  `AsyncNotifier`, and Riverpod has no `BuildContext` coupling, which matters for a service
  (`ModelManager`) that outlives any single screen.
- **Routing**: `go_router`. Desktop-class layout (sidebar + detail pane on wide windows,
  drawer-based navigation on narrow/mobile) is a *view-level* responsive decision, not a routing
  decision — one `ChatScreen` route adapts via `LayoutBuilder`/breakpoints.
- **Database**: Drift (SQLite) over raw `sqlite3` — reactive queries (`.watch()`) integrate
  directly with Riverpod streams for live-updating conversation/message lists, works identically
  on Android/Windows/macOS/Linux via `drift_flutter` (bundles `sqlite3` natively per platform, no
  extra native setup required from us).
- **Markdown**: `package:markdown` (block/inline parser) driving a custom Flutter widget renderer
  (not `flutter_markdown` blindly, though it may be used as the base) + `package:flutter_highlight`
  or `highlight` for fenced-code-block syntax highlighting + a "Copy" button per code block. No
  WebView anywhere in the render path.

## 2. Native integration architecture (the `ai_engine` package)

`packages/ai_engine` is a **Flutter plugin package** (one pub package, multiple platform folders —
the same structure Flutter's own federated plugins use, just not split into separate pub packages
since we control both ends and don't need independent versioning yet). The app only ever imports
`package:ai_engine/ai_engine.dart` and never branches on platform.

```dart
abstract class AiEngine {
  Future<void> initialize();
  Future<void> loadModel(String modelPath, {required Backend backend});
  Future<void> unloadModel();
  Stream<GenerationChunk> generate({
    required List<ChatMessage> messages,
    GenerationSettings? settings,
  });
  Future<void> stopGeneration();
  Future<bool> isModelLoaded();
  Future<ModelInfo> getModelInfo();
}
```

This matches the brief's interface, with `generate` returning a small `GenerationChunk` (token
text + a `done`/`error` union) instead of a bare `String` stream, so end-of-stream and native
errors surface through the same channel instead of throwing out-of-band.

Bridge choice, decided **per platform** based on what LiteRT-LM actually exposes there — not one
mechanism for everything:

| Platform | LiteRT-LM surface we call            | Flutter⇄native mechanism                              |
|----------|---------------------------------------|--------------------------------------------------------|
| Android  | Official Kotlin `litertlm-android` AAR| **Pigeon-generated Platform Channels** (`MethodChannel` for control calls, `EventChannel` for the token stream) |
| Windows  | C++ `Engine`/`Session` (built from source; no stable C API published upstream) | **Dart FFI** against a small first-party C ABI wrapper we build and ship ourselves |
| macOS    | Same C++ core as Windows (Swift API is preview-only and iOS/macOS-focused, not what we want for a shared desktop bridge) | Same FFI wrapper, architecture staged, not shipped in v1 |

### Why platform channels for Android, FFI for Windows

- Android already has a first-party, stable, documented Kotlin API. Re-wrapping it behind FFI
  would mean linking the C++ engine a second time and throwing away the maintained AAR — pure
  downside. A `MethodChannel` (control: init/load/unload/generate/stop — low frequency, latency
  irrelevant) plus an `EventChannel` (token stream: Gemma 4 E2B generates at roughly single-digit
  to low-double-digit tokens/sec on mobile NPUs/GPUs — an `EventChannel` message per token is
  several orders of magnitude below the channel's throughput ceiling). No measurable UI jank risk;
  benchmarking this further isn't warranted given the token rate involved.
- Windows/macOS have **no** equivalent maintained JVM-style binding, only the C++ core. Since we
  must write and ship our own bridge library there regardless, FFI is strictly better than
  standing up a `flutter/plugins`-style Windows platform-channel C++ plugin *and* a separate
  native wrapper — FFI removes a serialization hop entirely: the native side can push tokens by
  invoking a Dart `NativeCallable` directly (registered once at engine init), so token delivery on
  desktop is a raw function call, not a codec-serialized channel message. This is the "more
  efficient streaming mechanism" called for in the brief for the high-frequency path, applied
  where there's actually a high-frequency path to optimize (desktop has no OS-level channel
  abstraction as convenient as Android's, so we're not giving anything up by choosing FFI there).

### The Windows/macOS C ABI we own

Because upstream's C API is explicitly unstable and unpublished, our plugin vendors a pinned
LiteRT-LM commit (git submodule under `native/third_party/litert-lm`, pinned to a tagged release)
and builds a **thin wrapper library we control**, e.g. `native/windows/litert_lm_bridge/`:

```c
// litert_lm_bridge.h — the ONLY contract Dart code depends on.
typedef struct LlmEngine LlmEngine;                 // opaque handle
typedef void (*TokenCallback)(const char* utf8_chunk, void* user_data);
typedef void (*DoneCallback)(int error_code, const char* error_message, void* user_data);

LlmEngine* llm_engine_create(const char* model_path, int backend /* enum */);
void       llm_engine_destroy(LlmEngine* engine);
int        llm_engine_generate(LlmEngine* engine, const char* json_messages,
                                const char* json_settings,
                                TokenCallback on_token, DoneCallback on_done, void* user_data);
void       llm_engine_stop(LlmEngine* engine);
```

This header — not LiteRT-LM's internal `runtime/c` headers — is what `dart:ffi` binds against
(via `package:ffigen` for the binding boilerplate). Because *we* own this header, we get ABI
stability even though upstream's does not exist yet; the wrapper's `.cc` file is the only place
that has to change if upstream's internal C++/C surface moves.

## 3. LiteRT-LM integration strategy

1. Vendor a pinned LiteRT-LM release as a git submodule (never `HEAD` — the C++ surface moves).
2. Android: consume `litertlm-android` from Google's Maven as a normal Gradle dependency inside
   `packages/ai_engine/android/build.gradle` — **no source build required**, this is the fast,
   low-risk path and should be built first.
3. Windows: build LiteRT-LM's C++ engine + our bridge wrapper via **Bazel** (matching upstream's
   primary, fully-supported build system, rather than fighting the experimental/Linux-leaning
   CMake path) targeting `x86_64-pc-windows-msvc`, producing `litert_lm_bridge.dll` +
   `.lib` + our header, checked into (or built by CI into) `packages/ai_engine/windows/`. The
   app's `windows/CMakeLists.txt` (Flutter's own desktop build system) just copies/links the
   prebuilt artifact — Flutter's Windows runner does not need to know Bazel exists.
4. macOS: same wrapper source, same Bazel build, targeting `.dylib`; deferred to a later phase
   only because we cannot validate it here (no macOS build host in this environment) — the plugin
   folder and the Dart FFI loader already branch on `Platform.isMacOS` and will call the same
   bridge header once the `.dylib` exists.
5. Model format is `.litertlm`; both the Kotlin and C++ engines load it directly (no on-device
   conversion step).

## 4. Android strategy

- `packages/ai_engine/android` is a normal Flutter Android plugin (`FlutterPlugin` +
  `MethodChannel.MethodCallHandler` + a `StreamHandler` for the `EventChannel`).
- Depends on `com.google.ai.edge.litertlm:litertlm-android` via Gradle.
- Kotlin implementation owns the `Engine`/`Conversation` lifecycle, translates
  `MessageCallback`/`Flow` token events into `EventChannel.EventSink.success(chunkMap)` calls, and
  runs `engine.initialize()` / `engine.createConversation()` on a background dispatcher (per
  upstream's own guidance that init is slow) — never on the platform/UI thread.
- Backend selection (`Backend.CPU()` and whatever GPU/NPU backends the Kotlin API exposes) is
  read from `ModelInfo`/settings and surfaced in the Model Manager UI as "backend in use", with
  automatic CPU fallback on load failure (per the brief's error-handling requirements).

## 5. Windows strategy

- `packages/ai_engine/windows` is a normal Flutter Windows plugin (C++ `FlutterPlugin`
  registration) whose only job is exposing the prebuilt bridge to Dart FFI — it does **not**
  reimplement channel plumbing, since FFI talks to the `.dll` directly once loaded via
  `DynamicLibrary.open`.
- Build pipeline: CI job runs Bazel with the MSVC toolchain against the pinned submodule to
  produce `litert_lm_bridge.dll`; this is checked into the plugin (or pulled as a build-time
  artifact) so app developers don't need Bazel installed just to run `flutter build windows`.
- This is the highest-effort, highest-risk part of the whole project (§10) — budget accordingly
  and prototype it first, in isolation, before wiring up the rest of the app.

## 6. macOS strategy

- Same design as Windows (shared C ABI header, same wrapper source compiled to `.dylib` instead of
  `.dll`), staged but **not implemented in v1**:
  - `packages/ai_engine/macos/` exists with the plugin scaffold and a `dart:ffi` loader path that
    already branches on `Platform.isMacOS`.
  - Calling any `AiEngine` method on macOS in v1 throws a typed `UnsupportedPlatformException`
    with a clear message ("Local inference on macOS is not implemented yet — see
    docs/ARCHITECTURE.md §6"), surfaced by the UI as a friendly "not available on this platform
    yet" state, never a silent no-op or a fake response.
  - No macOS code is faked to *look* functional.

## 7. Model storage strategy

- Store under the platform's app-support directory (`path_provider`'s
  `getApplicationSupportDirectory()`), never a public/shared/Downloads folder — matches §18
  (no elevated privileges, data not executable, private to the app).
- Layout: `<support_dir>/models/<model_id>/<variant>.litertlm` plus a sidecar
  `<variant>.litertlm.meta.json` (expected size, sha256 if known, download URL, verified flag,
  timestamp). The final filename is only ever written by an atomic rename from
  `<variant>.litertlm.part` **after** full-size + checksum verification succeeds — a `.part` file
  is never treated as installed, satisfying the resume/never-treat-partial-as-installed
  requirement directly at the filesystem level (existence of the final filename *is* the "verified
  and installed" signal; nothing else needs to check a separate DB flag that could drift out of
  sync).
- On launch, `ModelManager` reconciles disk state → `ModelStatus` (`notInstalled`, `downloading`,
  `verifying`, `ready`, `loading`, `loaded`, `error`) by checking for `.part` (resumable download)
  vs. final file vs. neither.

## 8. Project structure

```
project/
├── android/ windows/ macos/           # Flutter host app shells (generated + platform config)
├── lib/
│   ├── app/  core/  domain/  data/  services/
│   └── features/{chat,conversations,models,settings}/
├── packages/
│   └── ai_engine/                     # the plugin described in §2
│       ├── lib/                       # Dart interface + shared models, platform dispatch
│       ├── android/                   # Kotlin, litertlm-android
│       ├── windows/                   # C++ plugin shim + prebuilt bridge .dll
│       ├── macos/                     # staged, unimplemented in v1
│       └── native/bridge/             # shared C++ wrapper source (litert_lm_bridge.{h,cc})
├── native/third_party/litert-lm/      # git submodule, pinned commit
├── test/                              # unit + widget tests
└── docs/
```

## 9. Dependencies (initial)

`flutter_riverpod`, `riverpod_annotation` + `riverpod_generator`/`build_runner`, `go_router`,
`drift` + `drift_flutter` + `sqlite3_flutter_libs`, `path_provider`, `dio` (resumable/ranged
downloads), `crypto` (sha256), `markdown`, `flutter_highlight` (or `highlight`), `ffi` +
`ffigen` (dev), `pigeon` (dev, Android channel codegen), `uuid`, `intl`.

## 10. Technical risks (ranked)

1. **Windows/macOS native build pipeline** — upstream explicitly does not publish a stable C ABI
   or prebuilt shared library for desktop (confirmed via issues #2154/#2529); we must build and
   maintain that ourselves via Bazel+MSVC, and the repo's own CMake path is not a reliable
   substitute today. This is the project's critical path and its biggest unknown — recommend a
   throwaway spike (build the submodule + a "hello world" bridge on Windows) before committing to
   a delivery date for Phase 3/Windows.
2. **Model artifact mismatch** — the spec assumes one ~2.6 GB universal file; the real repo hosts
   several ~3 GB SoC-specific `.litertlm` files. The downloader needs device/backend detection and
   a fallback strategy, and this environment couldn't browse huggingface.co directly to enumerate
   the exact file list/CPU-generic fallback — needs a follow-up pass from an unrestricted network
   before Phase 4 locks in filenames.
3. **Checksum source** — no confirmed published per-file sha256 manifest for the HF repo was
   found in this pass; integrity verification may have to rely on expected byte size +
   HF's `ETag`/HTTP `Content-Range` semantics for resume, with sha256 computed and pinned by us
   once we've verified a known-good download, rather than sourced from HF at request time.
4. **Upstream API churn** — Kotlin/C++ APIs are described as "stable" but the project is young and
   under active development (multiple version bumps referenced in search results, e.g. v0.13→v0.16
   in the timeframe surfaced above); pin exact LiteRT-LM/Maven versions and re-verify before each
   upgrade rather than tracking `latest.release`.
5. **Device capability variance on Android** — GPU/NPU backend availability differs per SoC; needs
   the CPU-fallback path from day one, not as a later hardening pass.
6. **This dev environment cannot validate `flutter build windows`/`apk` end-to-end** (no Android
   SDK/NDK, no Windows host here) — `flutter analyze` and `flutter test` are used as the
   continuous-validation gate in this environment; real device/platform builds must be verified on
   machines with the actual toolchains before release.

---

## Plan going forward

Given the research above, Phase 2 (Flutter shell, mock engine, full UI/UX/DB) has no dependency
on the unresolved native risk and is being implemented now. Phase 3 (real LiteRT-LM) will start
with Android (low risk, official API) and treat Windows as its own spike per risk #1 above before
committing scaffolding to production code paths.
