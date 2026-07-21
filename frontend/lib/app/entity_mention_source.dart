import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/entity/mention_source.dart';
import '../features/documents/data/document_repository.dart';
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

  /// An entity ID's prefix (`<prefix>_<16hex>`) pins its kind, so a `[[id]]` wikilink resolves with a single
  /// targeted `getEntityRow` per id — no guessing across kinds. 前缀定 kind,每 id 一次精确 getEntityRow。
  static const Map<String, EntityKind> _prefixKind = {
    'fn': EntityKind.function,
    'hd': EntityKind.handler,
    'ag': EntityKind.agent,
    'wf': EntityKind.workflow,
    'ctl': EntityKind.control,
    'apf': EntityKind.approval,
    'trg': EntityKind.trigger,
  };

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async {
    final repo = _ref.read(entityRepositoryProvider);
    final entries = await Future.wait([
      for (final id in ids.toSet())
        () async {
          try {
            // A doc→doc wikilink is the Notion-core case — resolve `doc_` against the documents seam
            // (the app layer may import both features). doc→doc wikilink 是 Notion 核心场景,doc_ 走文档缝。
            if (id.startsWith('doc_')) {
              final doc = await _ref
                  .read(documentsRepositoryProvider)
                  .getDocument(id);
              return MapEntry(id, doc.name);
            }
            final kind = _prefixKind[id.split('_').first];
            if (kind == null) {
              return null; // unknown prefix → chip falls back to the id. 未知前缀→回落 id。
            }
            final row = await repo.getEntityRow(kind, id);
            return MapEntry(id, row.name);
          } catch (_) {
            return null; // deleted / not found → fall back to the id. 删了/找不到→回落 id。
          }
        }(),
    ]);
    return {
      for (final e in entries)
        if (e != null) e.key: e.value,
    };
  }
}

/// The override both mains install: `mentionSourceProvider.overrideWith(entityMentionSource)`.
/// 两个 main 安装的 override。
MentionSource entityMentionSource(Ref ref) => EntityMentionSource(ref);
