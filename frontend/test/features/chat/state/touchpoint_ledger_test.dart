import 'package:anselm/core/contract/page.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/touchpoint_ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// touchpointLedger (WRK-061 W1) — REST keyset hydration ⊕ durable touchpoint Signal straight-patch,
// R-2 entity aggregation. Batteries: hydrate/empty/failed-retry, loadMore dedupe, the §5-9 cursor
// special (page 3 loaded, signals for a LOADED and an UNLOADED row both land), durable-only patching,
// R-2 (multi-verb one entity / mcp name normalization / deleted tombstone / newer-lastAt wins).
// 台账电池:水化/空/失败重试、翻页去重、§5-9 专测(翻到第3页时已载/未载行各来一条信号)、只吃 durable、
// R-2 聚合(多动词一实体/mcp 按名归一/deleted 墓碑/lastAt 新者胜)。

const _conv = 'cv_1';

Touchpoint _tp(
  String id, {
  String kind = 'function',
  String itemId = '',
  String name = '',
  TouchpointVerb verb = TouchpointVerb.created,
  required DateTime at,
  int count = 1,
}) => Touchpoint(
  id: id,
  conversationId: _conv,
  itemKind: kind,
  itemId: itemId.isEmpty ? 'fn_$id' : itemId,
  itemName: name,
  verb: verb,
  lastActor: TouchpointActor.assistant,
  count: count,
  firstAt: at,
  lastAt: at,
);

final _t0 = DateTime.utc(2026, 7, 8, 10);

void main() {
  (ProviderContainer, FixtureChatRepository) harness() {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return (c, repo);
  }

  test(
    'hydrates the first page; an empty ledger is EMPTY, not loading',
    () async {
      final (c, repo) = harness();
      repo.touchpoints[_conv] = [
        _tp('tp_a', at: _t0),
        _tp('tp_b', at: _t0.add(const Duration(minutes: 1))),
      ];
      c.listen(touchpointLedgerProvider(_conv), (_, _) {});
      await pumpEventQueue();
      final s = c.read(touchpointLedgerProvider(_conv));
      expect(s.hydrated, isTrue);
      expect(s.rows.length, 2);
      expect(s.entities.first.primary.id, 'tp_b'); // freshest first 新者在前

      final (c2, _) = harness();
      c2.listen(touchpointLedgerProvider(_conv), (_, _) {});
      await pumpEventQueue();
      expect(c2.read(touchpointLedgerProvider(_conv)).isEmpty, isTrue);
    },
  );

  test(
    'loadMore pages forward and dedupes by row id (newer lastAt wins)',
    () async {
      final (c, repo) = harness();
      repo.touchpoints[_conv] = [
        for (var i = 0; i < 120; i++)
          _tp('tp_$i', at: _t0.add(Duration(minutes: i))),
      ];
      c.listen(touchpointLedgerProvider(_conv), (_, _) {});
      await pumpEventQueue();
      expect(
        c.read(touchpointLedgerProvider(_conv)).rows.length,
        50,
      ); // default page 默认页宽
      expect(c.read(touchpointLedgerProvider(_conv)).hasMore, isTrue);
      await c.read(touchpointLedgerProvider(_conv).notifier).loadMore();
      await c.read(touchpointLedgerProvider(_conv).notifier).loadMore();
      final s = c.read(touchpointLedgerProvider(_conv));
      expect(s.rows.length, 120);
      expect(s.hasMore, isFalse);
    },
  );

  test(
    '§5-9: deep-paged window + signals for a LOADED and an UNLOADED row both upsert cleanly',
    () async {
      final (c, repo) = harness();
      repo.touchpoints[_conv] = [
        for (var i = 0; i < 120; i++)
          _tp('tp_$i', at: _t0.add(Duration(minutes: i))),
      ];
      c.listen(touchpointLedgerProvider(_conv), (_, _) {});
      await pumpEventQueue();
      await c
          .read(touchpointLedgerProvider(_conv).notifier)
          .loadMore(); // 100 rows loaded 已载百行
      final now = _t0.add(const Duration(hours: 3));
      // A LOADED row re-touched (sort key mutates — jumps to the top). 已载行再触碰,跳顶。
      repo.touch(_tp('tp_119', at: now, count: 2));
      // An UNLOADED row (page 3 territory) touched — its signal delivers it despite never being paged in.
      // 未载行(第三页地界)被触碰——信号直接送达,无需翻到它。
      repo.touch(_tp('tp_3', at: now.add(const Duration(seconds: 1))));
      await pumpEventQueue();
      final s = c.read(touchpointLedgerProvider(_conv));
      expect(
        s.rows.length,
        101,
      ); // 100 + the unloaded arrival (loaded one deduped) 已载去重、未载新增
      expect(s.rows['tp_119']!.count, 2);
      expect(
        s.entities.first.primary.id,
        'tp_3',
      ); // freshest tops the cast 最新登顶
      // The kept cursor still pages the remainder without loss. 游标继续翻,余量不丢。
      await c.read(touchpointLedgerProvider(_conv).notifier).loadMore();
      expect(c.read(touchpointLedgerProvider(_conv)).rows.length, 120);
    },
  );

  test('only DURABLE signals patch; an ephemeral echo is ignored', () async {
    final (c, repo) = harness();
    c.listen(touchpointLedgerProvider(_conv), (_, _) {});
    await pumpEventQueue();
    repo.emitFrame(
      _conv,
      StreamEnvelope(
        seq: 0, // ephemeral 灰身
        scope: const StreamScope(kind: 'conversation', id: _conv),
        id: 'tp_x',
        frame: FrameSignal(
          node: StreamNode(
            type: 'touchpoint',
            content: _tp('tp_x', at: _t0).toJson(),
          ),
        ),
      ),
    );
    await pumpEventQueue();
    expect(c.read(touchpointLedgerProvider(_conv)).rows, isEmpty);
  });

  test(
    'R-2: verbs of one item aggregate to ONE entity row, freshest verb fronting',
    () {
      final rows = [
        _tp(
          'tp_1',
          itemId: 'fn_x',
          name: 'rollup',
          verb: TouchpointVerb.created,
          at: _t0,
        ),
        _tp(
          'tp_2',
          itemId: 'fn_x',
          verb: TouchpointVerb.edited,
          at: _t0.add(const Duration(minutes: 5)),
        ),
        _tp(
          'tp_3',
          itemId: 'fn_x',
          verb: TouchpointVerb.executed,
          at: _t0.add(const Duration(minutes: 2)),
        ),
        _tp(
          'tp_4',
          itemId: 'fn_y',
          name: 'other',
          verb: TouchpointVerb.viewed,
          at: _t0,
        ),
      ];
      final entities = TouchpointLedgerController.aggregate(rows);
      expect(entities.length, 2);
      final x = entities.first;
      expect(x.key, 'fn_x');
      expect(x.primary.verb, TouchpointVerb.edited); // freshest 最新动词主显
      expect(x.secondary.map((r) => r.verb), [
        TouchpointVerb.executed,
        TouchpointVerb.created,
      ]);
      // 兄弟借名: the edited row has no name — the entity still shows the created row's snapshot.
      expect(x.displayName, 'rollup');
    },
  );

  test('R-2: mcp rows normalize to the NAME key (three id paths converge)', () {
    final rows = [
      _tp(
        'tp_1',
        kind: 'mcp',
        itemId: 'mcp_abc123',
        name: 'github',
        verb: TouchpointVerb.created,
        at: _t0,
      ),
      _tp(
        'tp_2',
        kind: 'mcp',
        itemId: 'github',
        name: 'github',
        verb: TouchpointVerb.executed,
        at: _t0.add(const Duration(minutes: 1)),
      ),
    ];
    final entities = TouchpointLedgerController.aggregate(rows);
    expect(entities.length, 1);
    expect(entities.single.key, 'github');
    expect(entities.single.byVerb.length, 2);
  });

  test('R-2: any deleted row tombstones the whole entity', () {
    final rows = [
      _tp(
        'tp_1',
        itemId: 'fn_x',
        name: 'rollup',
        verb: TouchpointVerb.created,
        at: _t0,
      ),
      _tp(
        'tp_2',
        itemId: 'fn_x',
        verb: TouchpointVerb.deleted,
        at: _t0.add(const Duration(minutes: 9)),
      ),
    ];
    final e = TouchpointLedgerController.aggregate(rows).single;
    expect(e.tombstoned, isTrue);
    expect(e.primary.verb, TouchpointVerb.deleted);
  });

  test('failed initial hydration surfaces failed + retry recovers', () async {
    final repo = _FailOnceRepository();
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(touchpointLedgerProvider(_conv), (_, _) {});
    await pumpEventQueue();
    expect(c.read(touchpointLedgerProvider(_conv)).failed, isTrue);
    repo.touchpoints[_conv] = [_tp('tp_a', at: _t0)];
    await c.read(touchpointLedgerProvider(_conv).notifier).retry();
    final s = c.read(touchpointLedgerProvider(_conv));
    expect(s.failed, isFalse);
    expect(s.rows.length, 1);
  });

  test(
    '410 resync refetches page one and MERGES (gap rows have fresh lastAt → they land in page 1)',
    () async {
      final (c, repo) = harness();
      repo.touchpoints[_conv] = [
        for (var i = 0; i < 60; i++)
          _tp('tp_$i', at: _t0.add(Duration(minutes: i))),
      ];
      c.listen(touchpointLedgerProvider(_conv), (_, _) {});
      await pumpEventQueue();
      expect(c.read(touchpointLedgerProvider(_conv)).rows.length, 50);
      // The gap: a brand-new row lands while we were disconnected (no signal received). 缺口内新行,无信号。
      repo.touchpoints[_conv]!.add(
        _tp('tp_gap', at: _t0.add(const Duration(hours: 2))),
      );
      repo.emitResync();
      await pumpEventQueue();
      final s = c.read(touchpointLedgerProvider(_conv));
      expect(
        s.rows.containsKey('tp_gap'),
        isTrue,
      ); // page-one merge covers the gap 首页并入覆盖缺口
      expect(
        s.rows.length,
        greaterThanOrEqualTo(51),
      ); // loaded window survives 已载窗口存续
      expect(s.hasMore, isTrue);
    },
  );
}

/// Fails the FIRST listTouchpoints (initial hydration), then serves normally. 首拉失败后恢复。
class _FailOnceRepository extends FixtureChatRepository {
  bool _failed = false;

  @override
  Future<Page<Touchpoint>> listTouchpoints(
    String conversationId, {
    String? cursor,
    int? limit,
    String? kind,
    TouchpointVerb? verb,
  }) {
    if (!_failed) {
      _failed = true;
      throw StateError('scripted hydration failure');
    }
    return super.listTouchpoints(
      conversationId,
      cursor: cursor,
      limit: limit,
      kind: kind,
      verb: verb,
    );
  }
}
