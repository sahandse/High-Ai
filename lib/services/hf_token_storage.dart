import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _hfTokenKey = 'hf_access_token';

/// Stores the user's optional Hugging Face access token in the platform
/// keystore (Android Keystore / Windows Credential Manager via
/// `flutter_secure_storage`) rather than plain `SharedPreferences`, since
/// it's a real credential — not app preference data.
///
/// Needed because some model repos (the Gemma family, confirmed on a real
/// device — see docs/ARCHITECTURE.md) are gated behind Hugging Face's
/// license click-through and return 401/403 to an unauthenticated request
/// even for a `litert-community` mirror.
class HfTokenStorage {
  const HfTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _hfTokenKey);

  Future<void> write(String? token) {
    if (token == null || token.isEmpty) return _storage.delete(key: _hfTokenKey);
    return _storage.write(key: _hfTokenKey, value: token);
  }
}

/// Overridden in `main()`, same pattern as `settingsServiceProvider`.
final hfTokenStorageProvider = Provider<HfTokenStorage>(
  (ref) => throw UnimplementedError('hfTokenStorageProvider was not overridden'),
);

class HfTokenController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(hfTokenStorageProvider).read();

  Future<void> setToken(String? token) async {
    await ref.read(hfTokenStorageProvider).write(token);
    state = AsyncData(token == null || token.isEmpty ? null : token);
  }
}

final hfTokenProvider = AsyncNotifierProvider<HfTokenController, String?>(
  HfTokenController.new,
);
