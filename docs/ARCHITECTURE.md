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

---

## Addendum: real-device findings and v1.1 additions

The Android debug APK was actually installed and run on a physical device (see the GitHub
Actions build in `.github/workflows/android-debug-apk.yml`, added because this environment has
no Android SDK). That surfaced one real bug and confirmed a gap noted above:

- **HTTP 416 during download.** `ModelDownloadManager` sent a `Range` header computed from a
  local `.part` file without ever learning the server's authoritative file size — it trusted
  the catalog's hardcoded `approximateSizeBytes` for verification, and had no recovery path for
  a Range request landing at or past the real end of the file (a normal outcome after a resumed
  download, not just a fluke). Fixed: the manager now reads `Content-Length`/`Content-Range`
  from the *actual* response for both progress and final-size verification, and a 416 is
  reconciled against that (install as already-complete if the partial file already covers it,
  otherwise delete the stale partial and ask the user to retry) instead of surfacing a raw
  exception. See `test/services/model_download_manager_network_test.dart` for the regression
  coverage (a scripted `HttpClientAdapter`, no real network).
- **Missing `INTERNET` permission in the main manifest.** It was only declared in the
  debug/profile manifests (Flutter's default template), which would have made the downloader
  silently unusable in a release build. Added to `android/app/src/main/AndroidManifest.xml`.

Also added in this pass, per direct product feedback:

- **Theme presets** (`lib/app/theme.dart`): a "ChatGPT-like" warm-white light theme and a
  "Claude-like" warm near-black dark theme, alongside the app's own classic palette — original
  palettes inspired by, not cloned from, either product, per §5's branding constraint.
- **Multi-model picker**: `ModelCatalog` now lists more than one real, verified
  `litert-community` model (Gemma 4 E2B and E4B) with Persian descriptions and badges; the user
  picks and installs one from the same first-run gate and Settings ▸ Models screen
  (`ModelManager`'s state became a per-model-id map so more than one model's install/load state
  can be tracked at once, though only one is ever loaded into the engine at a time).
- **Pause/resume as first-class states**: `ModelStatus.paused` was added (distinct from
  `notInstalled`) so the UI can offer an explicit resume affordance rather than conflating
  "paused" with "never started."
- **Device capability pre-check** (`lib/services/device_capability_checker.dart`): free storage
  via the `disk_space_plus` plugin, total RAM via a small dedicated method channel added to
  `MainActivity.kt` (`ActivityManager.MemoryInfo`, not a third-party lib — an alternative
  cross-platform package that queried `/proc/meminfo` by shelling out to `cat` was tried and
  rejected as unreliable on Android's app sandboxing). Insufficient storage disables the download
  button outright (it would fail anyway); low RAM only warns, since the threshold is a heuristic,
  not a number LiteRT-LM publishes.

## Addendum 2: confirmed on a real device — per-SoC files need real detection

A real device download of Gemma 4 E2B (the `qualcomm_sm8750` variant — `defaultVariant`, i.e.
`variants.first`, since no per-device selection exists) completed successfully (confirming the
416 fix above) but then failed to *load*, with LiteRT-LM's own engine raising:

```
Failed to create engine: NOT_FOUND: ERROR: [.../llm_litert_compiled_model_executor_factory.cc:121]
Input tensor not found
```

This is exactly risk #2 from Phase 1 materializing: `gemma-4-E2B-it-litert-lm` is published only
as three separate per-SoC ahead-of-time-compiled files (Qualcomm SM8750 / Google Tensor G5 /
Intel PTL) with **no generic/CPU fallback file in that repo**, and this app has no real SoC
detection — it always fetches `variants.first` regardless of the device's actual chip. A file
compiled for one accelerator's tensor layout simply does not load on different hardware; that is
what "Input tensor not found" means here, not a corrupt download.

`gemma-4-E4B-it-litert-lm`, by contrast, does publish a generic `gemma-4-E4B-it.litertlm` meant
for "Android, iOS, Desktop, IoT and Web" broadly — not tied to one accelerator. Fix applied:

- `ModelCatalog.all` now lists **E4B first** and badges it "توصیه‌شده" (recommended/default) since
  it is the only model here guaranteed to load on arbitrary hardware; E2B is re-badged "پردازنده
  خاص" (specific processor) with a `ModelDefinition.compatibilityWarning` shown as a visible
  warning box on its card, explaining plainly that it needs a matching chip and pointing at E4B
  as the safe alternative.
- Real per-device SoC detection (so E2B could pick the *right* variant instead of just warning
  about the wrong one) is not implemented — Android's `Build.SOC_MODEL`/`Build.HARDWARE` values
  don't reliably map to Qualcomm's marketing model numbers (e.g. "SM8750") across OEMs, so a
  heuristic string-matcher would be guessing, not detecting. Flagged as follow-up work rather than
  shipped as a false sense of reliability.
- Separately, `ModelManager.loadModel`'s failure path was exposing the raw native error string
  directly to the user (a real violation of the brief's "never expose raw exceptions" rule, caught
  by this same test). It now maps known failure shapes (this tensor-mismatch case, out-of-memory)
  to a plain-language Persian message via `_friendlyLoadError`, keeps the raw text in
  `ModelEntryState.technicalDetails`, and the Models screen shows it only behind an explicit
  "جزئیات فنی" (technical details) toggle.

## Addendum 3: the fix above was still wrong — Gallery ships a generic file per model

The device that hit the E2B failure above was identified from its `Build.MODEL`
(`M2012K11AG`) as a **Snapdragon 888 (SM8350)** phone — not a match for *any* of the three
per-SoC E2B files (`qualcomm_sm8750`, `Google_Tensor_G5`, `intel_PTL`), confirming Addendum 2's
diagnosis. But recommending E4B as "the safe default" in that same fix was itself wrong, for a
reason only found by going to the actual source instead of re-guessing: Google's own
`google-ai-edge/gallery` app ships a versioned **model allowlist**
(`model_allowlists/1_0_12.json` on the gallery repo) that is the real, load-bearing config its
production app uses. Fetched directly, it shows:

| Model | file | exact size | min RAM |
|---|---|---|---|
| Gemma-4-E2B-it | `gemma-4-E2B-it.litertlm` | 2,583,085,056 bytes (~2.4 GB) | **8 GB** |
| Gemma-4-E4B-it | `gemma-4-E4B-it.litertlm` | 3,654,467,584 bytes (~3.4 GB) | **12 GB** |

Two corrections followed directly from this:

1. **Both models have a plain, generic file** (`gemma-4-E2B-it.litertlm`,
   `gemma-4-E4B-it.litertlm`) distinct from the per-SoC AOT-compiled ones — Gallery runs it via
   LiteRT-LM's `"gpu,cpu"` delegate configuration, not one accelerator's compiled graph. This is
   the file this app should have been downloading for E2B all along; the per-SoC filenames are a
   separate, newer publishing path for devices whose exact chip is confirmed, which this app does
   not attempt to detect (see Addendum 2). `ModelCatalog.gemma4E2b` now points at the generic file
   with Gallery's exact byte count.
2. **E4B needs 12 GB of RAM, not ~8 GB as this app's old heuristic guessed** (`size × 1.3`). A
   device with 8 GB total RAM — like the one that surfaced this whole thread — meets E2B's
   requirement exactly but sits well under E4B's. `ModelDefinition` now carries Google's real
   `minRamGb` instead of a guessed multiplier, `DeviceCapabilityChecker` compares total RAM
   against it directly (with 10% slack, since `ActivityManager.MemoryInfo.totalMem` typically
   reports somewhat less than a device's marketed RAM figure), and — since this number is now an
   authoritative fact rather than a heuristic — insufficient RAM disables the download button
   outright, same as insufficient storage, rather than only warning.

Net effect: E2B is recommended again (smaller, generic, matches this device's 8 GB exactly);
E4B is labeled "نیازمند رم بالا" (needs high RAM) and its own card explains why. A model already
downloaded under the old per-SoC filename scheme is simply orphaned on disk under its old
filename (no code deletes it automatically) — acceptable for now, but worth a cleanup pass if
model file naming changes again.
