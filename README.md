# های ای‌آی (High-Ai)

اپلیکیشن گفتگوی هوش مصنوعی که کاملاً به‌صورت آفلاین روی دستگاه اجرا می‌شود — بدون
نیاز به API ابری، حساب کاربری یا اتصال اینترنت پس از دانلود مدل. رابط کاربری به
زبان فارسی و راست‌به‌چپ (RTL) است.

مدل‌های پشتیبانی‌شده: خانواده **Gemma** (۴، ۳n، ۳) و همچنین **Qwen 2.5** و **DeepSeek R1
Distill** — همان مجموعه مدل‌های واقعی اپلیکیشن رسمی Google AI Edge Gallery — از طریق موتور
استنتاج [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) گوگل.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full technical design,
integration strategy, and known risks.

## Project status

- **Flutter shell (this codebase)**: complete — Material 3 UI, Persian/RTL, routing,
  local Drift database, streaming chat, markdown + syntax-highlighted code blocks,
  model download manager, generation settings, and a clearly-marked mock engine for
  UI development (`--dart-define=USE_MOCK_AI_ENGINE=true`).
- **Android native bridge**: scaffolded (Kotlin plugin in `packages/ai_engine/android`
  wired to the official `litertlm-android` Maven dependency) but **not yet compiled or
  run against a real device** — this development environment has no Android SDK/NDK.
  See the verification notice at the top of `GemmaEngineBridge.kt`.
- **Windows/macOS native bridge**: architecture is designed (see docs/ARCHITECTURE.md
  §5/§6) but not implemented — upstream LiteRT-LM does not publish a stable C API or
  prebuilt shared library for desktop yet, so this requires building LiteRT-LM from
  source with a first-party C ABI wrapper before Dart FFI bindings can be written.
  The same Flutter UI already builds and runs on Windows via
  `.github/workflows/windows-build.yml`; `AiEngine.isSupported` is `false` there, so
  the app shows an honest "not available on this platform yet" message instead of
  letting a user download a model it can't yet run.
- **App icon**: a real launcher icon/logo (not the Flutter default) is wired up for
  Android and Windows — see `lib/app/app_logo.dart` and docs/ARCHITECTURE.md Addendum 5.
- **Gated models**: the Gemma family is gated on Hugging Face behind a license
  click-through; add a personal access token in Settings ▸ "حساب Hugging Face" to
  download those models (stored via the platform keystore, not plain preferences).

## Running

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates lib/data/database.g.dart
flutter run --dart-define=USE_MOCK_AI_ENGINE=true            # UI development, no model/device needed
flutter run                                                    # real engine (Android only, for now)
```

## Testing

```sh
flutter analyze
flutter test
cd packages/ai_engine && flutter analyze && flutter test
```
