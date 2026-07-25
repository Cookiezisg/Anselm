import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/contract/entities/skill.dart';
import '../core/entity/mention_source.dart';
import '../features/library/data/library_repository.dart';
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
    // Each kind fails INDEPENDENTLY. `Future.wait` fails fast, so one kind erroring — a flaky endpoint, a
    // 401 after a workspace switch, a 410 — used to reject the whole search; the composer's catch then
    // CLOSES the picker (correctly: stale candidates would insert a wrong mention), and the panel simply
    // never appeared. One kind having a bad day must cost that kind's rows, not the whole feature.
    //
    // Whether this was the cause of the reported "@ 弹不出来" is NOT established — that needs the user's
    // machine, and the panel has other ways to stay shut. It is a real fault-isolation hole either way.
    //
    // 每一类**独立**失败。`Future.wait` 是快速失败的,故任一类出错(端点抖动、切工作区后的 401、410)原先会让
    // 整个 search reject,composer 的 catch 随即**关掉面板**(它没做错:留着过期候选会插错提及),于是面板干脆
    // 不出现。一类不舒服该花掉的是那一类的行,不是整个功能。
    //
    // 这是否**就是**用户报的「@ 弹不出来」的成因,**尚未确证**——那需要他的机器,而面板不开还有别的路径。
    // 但无论如何,这是一个真实的故障隔离缺口。
    final results = await Future.wait([
      Future.wait([
        for (final kind in EntityKind.values)
          // `Future.sync` because a repository may throw SYNCHRONOUSLY (a bad argument, a disposed client):
          // calling it bare would blow up before `.catchError` is attached and the isolation would be a
          // fiction. A test that made a fixture throw synchronously is what surfaced this.
          // 用 `Future.sync`,因为仓储可能**同步**抛错(参数不对、client 已 dispose):裸调用会在 `.catchError`
          // 挂上之前就炸掉,隔离就成了空话。是一条让 fixture 同步抛错的测试把它照出来的。
          Future.sync(
                () => repo.listEntities(
                  kind,
                  limit: _perKind,
                  search: q.isEmpty ? null : q,
                ),
              )
              .then<List<MentionCandidate>>(
                (page) => [
                  for (final row in page.items)
                    MentionCandidate(
                      type: row.kind.name, // enum name == wire kind 枚举名=线缆 kind
                      id: row.id,
                      name: row.name,
                      description: row.description,
                    ),
                ],
              )
              .catchError((_) => const <MentionCandidate>[]),
      ]),
      _skillCandidates(q),
    ]);
    final pages = results[0] as List;
    final skills = results[1] as List<MentionCandidate>;
    return [
      for (final page in pages)
        for (final candidate in page as List<MentionCandidate>) candidate,
      // Skills last (after the Quadrinity) — @-mentioning one ACTIVATES it (WRK-076). Only INLINE
      // skills appear (fork's activation is a subagent dispatch, not a @ semantic — the model
      // drives fork via activate_skill). 技能置后:@ 即激活;只列 inline(fork 归模型 activate_skill)。
      ...skills,
    ];
  }

  /// The turn's @-mentionable skills: every INLINE skill (fork excluded), client-filtered by name
  /// (the skills list is a bounded full set, no server search). id = the slug name. Capped like a
  /// kind. @ 可激活的技能:全部 inline(排除 fork),客户端按名过滤(skills 是有界全集),id=slug 名。
  Future<List<MentionCandidate>> _skillCandidates(String query) async {
    try {
      // `Future.sync` for the same reason as the kinds above — an `async` body only converts throws that
      // happen inside IT, and `listSkills()` is called before the await. 与上面各类同理:`async` 体只转换
      // **它自己内部**发生的抛错,而 `listSkills()` 是在 await 之前被调用的。
      final skills = await Future.sync(
        () => _ref.read(libraryRepositoryProvider).listSkills(),
      );
      final q = query.toLowerCase();
      final out = <MentionCandidate>[];
      for (final s in skills) {
        if (s.context == kSkillContextFork) continue; // fork 不进 @
        if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) continue;
        out.add(
          MentionCandidate(
            type: 'skill',
            id: s.name, // skill is name-addressed 名即身份
            name: s.name,
            description: s.description,
          ),
        );
        if (out.length >= _perKind) break;
      }
      return out;
    } catch (_) {
      return const []; // a skills-list hiccup must never break the @ picker. 技能列表故障不砸 @ 面板。
    }
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
                  .read(libraryRepositoryProvider)
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
