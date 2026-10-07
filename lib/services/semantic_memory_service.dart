import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_engine_provider.dart';
import '../data/database_provider.dart';

class SemanticMemoryMatch {
  const SemanticMemoryMatch({
    required this.content,
    required this.role,
    required this.conversationId,
    required this.score,
  });

  final String content;
  final String role;
  final String conversationId;
  final double score;
}

class _SemanticMemoryEntry {
  const _SemanticMemoryEntry({
    required this.messageId,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.vector,
  });

  final String messageId;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final List<double> vector;

  Map<String, Object?> toJson() => {
        'messageId': messageId,
        'conversationId': conversationId,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'vector': vector,
      };

  static _SemanticMemoryEntry fromJson(Map<String, Object?> json) =>
      _SemanticMemoryEntry(
        messageId: json['messageId'] as String,
        conversationId: json['conversationId'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        vector: (json['vector'] as List)
            .map((value) => (value as num).toDouble())
            .toList(growable: false),
      );
}

/// Small privacy-first local vector store.
///
/// High-Ai deliberately keeps this implementation dependency-free. The
/// expected personal-chat corpus is small enough that a normalized dot
/// product scan is fast, while avoiding a cloud vector DB or another native
/// database dependency. If the corpus grows substantially this service can
/// later be swapped for an HNSW implementation behind the same API.
class SemanticMemoryService {
  SemanticMemoryService(this._ref);

  final Ref _ref;
  List<_SemanticMemoryEntry>? _cache;

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/semantic_memory');
    await dir.create(recursive: true);
    return File('${dir.path}/vectors.json');
  }

  Future<List<_SemanticMemoryEntry>> _entries() async {
    if (_cache != null) return _cache!;
    final file = await _file();
    if (!await file.exists()) {
      return _cache = <_SemanticMemoryEntry>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString()) as List;
      return _cache = decoded
          .map((item) => _SemanticMemoryEntry.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList();
    } catch (_) {
      return _cache = <_SemanticMemoryEntry>[];
    }
  }

  Future<void> _persist(List<_SemanticMemoryEntry> entries) async {
    _cache = entries;
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<void> indexMessage({
    required String messageId,
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final text = content.trim();
    if (text.length < 3) return;
    if (!await _ref.read(aiEngineProvider).isEmbeddingModelLoaded()) return;

    final entries = await _entries();
    entries.removeWhere((entry) => entry.messageId == messageId);

    try {
      final vector = await _ref.read(aiEngineProvider).embedText(text);
      if (vector.isEmpty) return;
      entries.add(
        _SemanticMemoryEntry(
          messageId: messageId,
          conversationId: conversationId,
          role: role,
          content: text,
          createdAt: DateTime.now(),
          vector: vector,
        ),
      );
      // Keep the on-device store bounded. 5000 x 256 float-like JSON values
      // is already ample for personal chat history and avoids runaway growth.
      if (entries.length > 5000) {
        entries.removeRange(0, entries.length - 5000);
      }
      await _persist(entries);
    } catch (_) {
      // Semantic memory is an enhancement; chat must keep working if an
      // embedding request fails on a particular device/backend.
    }
  }

  Future<List<SemanticMemoryMatch>> search(
    String query, {
    String? excludeConversationId,
    int limit = 4,
    double minimumScore = 0.42,
  }) async {
    if (query.trim().isEmpty) return const [];
    if (!await _ref.read(aiEngineProvider).isEmbeddingModelLoaded()) {
      return const [];
    }

    try {
      final queryVector = await _ref.read(aiEngineProvider).embedText(query.trim());
      if (queryVector.isEmpty) return const [];
      final entries = await _entries();
      final matches = <SemanticMemoryMatch>[];

      for (final entry in entries) {
        if (entry.vector.length != queryVector.length) continue;
        if (excludeConversationId != null &&
            entry.conversationId == excludeConversationId) {
          continue;
        }
        final score = _cosine(queryVector, entry.vector);
        if (score < minimumScore) continue;
        matches.add(
          SemanticMemoryMatch(
            content: entry.content,
            role: entry.role,
            conversationId: entry.conversationId,
            score: score,
          ),
        );
      }

      matches.sort((a, b) => b.score.compareTo(a.score));
      return matches.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> backfillFromDatabase() async {
    if (!await _ref.read(aiEngineProvider).isEmbeddingModelLoaded()) return;
    final db = _ref.read(databaseProvider);
    final messages = await db.select(db.messages).get();
    for (final message in messages) {
      if (!message.isComplete || message.content.trim().length < 3) continue;
      await indexMessage(
        messageId: message.id,
        conversationId: message.conversationId,
        role: message.role,
        content: message.content,
      );
    }
  }

  Future<void> removeMessage(String messageId) async {
    final entries = await _entries();
    entries.removeWhere((entry) => entry.messageId == messageId);
    await _persist(entries);
  }

  Future<void> removeConversation(String conversationId) async {
    final entries = await _entries();
    entries.removeWhere((entry) => entry.conversationId == conversationId);
    await _persist(entries);
  }

  Future<void> clear() async {
    _cache = <_SemanticMemoryEntry>[];
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    var aNorm = 0.0;
    var bNorm = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      aNorm += a[i] * a[i];
      bNorm += b[i] * b[i];
    }
    final denominator = math.sqrt(aNorm) * math.sqrt(bNorm);
    return denominator == 0 ? 0 : dot / denominator;
  }
}

final semanticMemoryProvider = Provider<SemanticMemoryService>(
  SemanticMemoryService.new,
);
