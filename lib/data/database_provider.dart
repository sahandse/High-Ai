import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Single shared [AppDatabase] instance for the app's lifetime. Riverpod
/// disposes it (closing the underlying SQLite connection) if this provider
/// is ever torn down, e.g. in a test using `ProviderContainer`.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
