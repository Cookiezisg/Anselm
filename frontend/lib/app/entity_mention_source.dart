import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/entity/mention_source.dart';
import '../features/entities/data/entity_kind.dart';
import '../features/entities/data/entity_providers.dart';

/// The app assembly's [MentionSource]: fans the query out to the four Quadrinity list endpoints
/// (`?search` = case-insensitive name substring, server-side) CONCURRENTLY and flattens in the fixed
/// kind order (function / handler / agent / workflow — Notion-style stable order builds muscle memory).
/// Capped per kind so one populous kind can't drown the panel. Lives in the APP layer — the only layer
/// allowed to import both the core seam and the entities feature; `make demo` gets it for free (the
/// entity repository is already the fixture there).
///
/// app 装配的 MentionSource:query 并发扇给四个积木 list 端点(`?search` 服务端名子串),按固定 kind 序拍平
/// (Notion 式稳定序练肌肉记忆);每类封顶防一类淹面板。放 app 层(唯一可同时 import core 缝与 entities
/// feature 的层);make demo 免费获得(彼处 entity repository 已是 fixture)。
class EntityMentionSource implements MentionSource {
  EntityMentionSource(this._ref);

  final Ref _ref;

  /// Per-kind cap: 4 kinds × 5 ≈ a 6–8 row panel with scroll headroom. 每类 5,面板 6–8 行+滚动余量。
  static const int _perKind = 5;

  @override
  Future<List<MentionCandidate>> search(String query) async {
    final repo = _ref.read(entityRepositoryProvider);
    final q = query.trim();
    final pages = await Future.wait([
      for (final kind in EntityKind.values)
        repo.listEntities(kind, limit: _perKind, search: q.isEmpty ? null : q),
    ]);
    return [
      for (final page in pages)
        for (final row in page.items)
          MentionCandidate(
            type: row.kind.name, // enum name == wire kind 枚举名=线缆 kind
            id: row.id,
            name: row.name,
            description: row.description,
          ),
    ];
  }
}

/// The override both mains install: `mentionSourceProvider.overrideWith(entityMentionSource)`.
/// 两个 main 安装的 override。
MentionSource entityMentionSource(Ref ref) => EntityMentionSource(ref);
