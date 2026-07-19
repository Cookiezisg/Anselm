import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/stage_expansion.dart';
import 'package:anselm/features/chat/state/stage_group_collapse.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 三段式文法 §3 (0719, 用户改判 kind→时间档) — the sidestage's settled Cast buckets by last-touched time into
// 刚刚 / 早些时候 / 更早 (AnRow permanent-chevron heads, one grammar with the tray), with two anti-fragmentation
// rules: an empty tier draws no head; a SINGLE tier draws NO head at all (bare rows). Grouping never hides
// live / auto-expanded work (force-open). + §2 the head's quiet glance strip. 时间三档分组 + 速览带电池。

const _conv = 'cv_1';

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'group test',
        createdAt: DateTime.utc(2026, 7, 19),
        updatedAt: DateTime.utc(2026, 7, 19),
        lastMessageAt: DateTime.utc(2026, 7, 19),
      ),
    ]);

Widget _host(FixtureChatRepository repo, {bool reduced = false}) => ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Builder(
            builder: (context) {
              final panel = Scaffold(
                body: SizedBox(width: 340, height: 680, child: StagePanel(conversationId: _conv)),
              );
              // reduced → the fold reveal collapses instantly (AnExpandReveal double-gate). reduced=即时。
              return reduced
                  ? MediaQuery(
                      data: MediaQuery.of(context).copyWith(disableAnimations: true), child: panel)
                  : panel;
            },
          ),
        ),
      ),
    );

// [ago] BEFORE now (wall-clock) so the tier is deterministic regardless of run time: <10min → 刚刚, days → 更早.
// 相对 now 定档:<10min=刚刚、跨天=更早。
Touchpoint _tp(String id, String kind, String itemId, String name, TouchpointVerb verb, Duration ago) {
  final at = DateTime.now().toUtc().subtract(ago);
  return Touchpoint(
    id: id, conversationId: _conv, itemKind: kind, itemId: itemId, itemName: name, verb: verb,
    lastActor: TouchpointActor.assistant, count: 1, firstAt: at, lastAt: at,
  );
}

Future<void> _hydrate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(StagePanel)), listen: false);

void main() {
  // ── the pure tier classifier — deterministic boundaries (三档分界 / 跨天 / 10-min window edge) ──
  group('sidestageTierKey — three-tier boundaries', () {
    final now = DateTime(2026, 7, 19, 15, 0);
    test('within the 10-min window → just (boundary inclusive)', () {
      expect(sidestageTierKey(now, now), 'just');
      expect(sidestageTierKey(now.subtract(const Duration(minutes: 5)), now), 'just');
      expect(sidestageTierKey(now.subtract(const Duration(minutes: 10)), now), 'just'); // exactly 10 = just
    });
    test('earlier the same calendar day → today', () {
      expect(sidestageTierKey(now.subtract(const Duration(minutes: 11)), now), 'today');
      expect(sidestageTierKey(DateTime(2026, 7, 19, 1, 0), now), 'today');
    });
    test('a past calendar day → earlier', () {
      expect(sidestageTierKey(DateTime(2026, 7, 18, 23, 0), now), 'earlier');
      expect(sidestageTierKey(now.subtract(const Duration(days: 2)), now), 'earlier');
    });
    test('the 10-min window wins even across midnight → just (the current burst)', () {
      final justAfterMidnight = DateTime(2026, 7, 19, 0, 5);
      expect(sidestageTierKey(DateTime(2026, 7, 18, 23, 58), justAfterMidnight), 'just');
    });
  });

  group('sidestage time-tier grouping (widget)', () {
    setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

    testWidgets('multiple tiers → heads (label + count); an EMPTY tier draws NO head', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'workflow', 'wf_old', 'nightly_rollup', TouchpointVerb.viewed, const Duration(days: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);

      // 刚刚 (2) + 更早 (1) heads render; 早些时候 is EMPTY → no head (空段不渲组头). 两档头 + 空档无头。
      expect(find.text(t.chat.stage.groupJustNow), findsOneWidget);
      expect(find.text(t.chat.stage.groupEarlier), findsOneWidget);
      expect(find.text(t.chat.stage.groupEarlierToday), findsNothing);
      // All three entity rows visible (tiers default open). 三行皆现。
      expect(find.text('sync_inventory'), findsOneWidget);
      expect(find.text('reconcile'), findsOneWidget);
      expect(find.text('nightly_rollup'), findsOneWidget);
      // 2 tier heads + 3 entity rows = 5 AnRows (each is an AnRow — one grammar). 2 头 + 3 行 = 5。
      expect(find.byType(AnRow), findsNWidgets(5));
    });

    testWidgets('a SINGLE tier draws NO head — bare rows (anti-目录病)', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'document', 'doc_1', '值班手册', TouchpointVerb.viewed, const Duration(minutes: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);

      // All in 刚刚 → one tier → NO heads at all, just the three bare rows. 全刚刚 → 无头、裸三行。
      expect(find.text(t.chat.stage.groupJustNow), findsNothing);
      expect(find.text(t.chat.stage.groupEarlierToday), findsNothing);
      expect(find.text(t.chat.stage.groupEarlier), findsNothing);
      expect(find.byType(AnRow), findsNWidgets(3));
      expect(find.text('sync_inventory'), findsOneWidget);
    });

    testWidgets('tapping a tier head folds its rows away (the other tier is untouched)', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'workflow', 'wf_old', 'nightly_rollup', TouchpointVerb.viewed, const Duration(days: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);

      await tester.tap(find.text(t.chat.stage.groupJustNow)); // fold 刚刚
      await tester.pump(); // rebuild → the reveal starts collapsing 起帧
      await tester.pump(const Duration(milliseconds: 400)); // past AnMotion.mid (240) → settled 收合完成

      expect(find.text('sync_inventory'), findsNothing);
      expect(find.text('reconcile'), findsNothing);
      expect(find.text(t.chat.stage.groupJustNow), findsOneWidget); // head stays 头留存
      expect(find.text('nightly_rollup'), findsOneWidget); // the 更早 tier untouched 更早档不动
    });

    testWidgets('folding rides the STANDARD collapse slide — a mid-frame still shows the rows (not instant)',
        (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'workflow', 'wf_old', 'nightly_rollup', TouchpointVerb.viewed, const Duration(days: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);

      await tester.tap(find.text(t.chat.stage.groupJustNow)); // fold 刚刚
      await tester.pump(); // start the reveal 起帧
      await tester.pump(AnMotion.fast); // 120ms into a 240ms collapse — MID-TRANSITION 半途
      // The rows are still built (clipped by the reveal) — proof the fold ANIMATES, not an instant jump.
      // 行仍在树(被 reveal 裁)——证明是滑动过渡、非瞬跳。
      expect(find.text('sync_inventory'), findsOneWidget, reason: 'mid-collapse frame still holds the row');
      await tester.pump(const Duration(milliseconds: 300)); // finish 收合完成
      expect(find.text('sync_inventory'), findsNothing);
    });

    testWidgets('reduced motion → the fold is INSTANT (AnExpandReveal double-gate)', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'workflow', 'wf_old', 'nightly_rollup', TouchpointVerb.viewed, const Duration(days: 3)),
      ];
      await tester.pumpWidget(_host(repo, reduced: true));
      await _hydrate(tester);

      await tester.tap(find.text(t.chat.stage.groupJustNow)); // fold 刚刚
      await tester.pump(); // one frame — reduced sets the reveal to 0 instantly 一帧即收
      expect(find.text('sync_inventory'), findsNothing, reason: 'reduced motion collapses instantly');
    });

    testWidgets('a collapsed tier FORCE-OPENS when a row inside it is (auto-)expanded (深跳/auto-expand lock)',
        (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t3', 'workflow', 'wf_old', 'nightly_rollup', TouchpointVerb.viewed, const Duration(days: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);
      final container = _container(tester);

      container.read(stageGroupCollapseProvider(_conv).notifier).toggle('just'); // fold 刚刚
      await tester.pump(); // rebuild → collapse starts 起帧
      await tester.pump(const Duration(milliseconds: 400)); // settled 收合完成
      expect(find.text('sync_inventory'), findsNothing);

      // The director / deep-jump programmatically EXPANDS a row inside the collapsed tier → the tier must
      // force-open (the reveal animates the same slide) so the auto-expanded row is never hidden.
      // 导演器/深跳展开折叠档内行 → 档强制展开(reveal 播同一滑动)、绝不藏。
      container.read(stageExpansionProvider(_conv).notifier).open('function:fn_a');
      await tester.pump(); // rebuild → force-open starts 起帧
      await tester.pump(const Duration(milliseconds: 400)); // settled 展开完成
      expect(find.text('sync_inventory'), findsOneWidget, reason: 'the collapsed tier force-opened');
    });

    testWidgets('the glance strip shows touched · executed · needs-you, signal-only', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'document', 'doc_1', '值班手册', TouchpointVerb.viewed, const Duration(minutes: 3)),
      ];
      repo.interactions[_conv] = [
        const Interaction(
            toolCallId: 'tc_gate', kind: InteractionKind.danger, tool: 'delete_function', resolved: false),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);
      // N = 3 touched, M = 1 executed (fn_b), K = 1 awaiting — one quiet joined line. 三段速览。
      expect(find.text('3 触点 · 1 执行 · 1 待你处理'), findsOneWidget);
    });

    testWidgets('the glance strip drops K when nothing awaits, and vanishes when all-zero', (tester) async {
      final repo = _repo();
      repo.touchpoints[_conv] = [
        _tp('t1', 'function', 'fn_a', 'sync_inventory', TouchpointVerb.edited, const Duration(minutes: 1)),
        _tp('t2', 'function', 'fn_b', 'reconcile', TouchpointVerb.executed, const Duration(minutes: 2)),
        _tp('t3', 'document', 'doc_1', '值班手册', TouchpointVerb.viewed, const Duration(minutes: 3)),
      ];
      await tester.pumpWidget(_host(repo));
      await _hydrate(tester);
      expect(find.text('3 触点 · 1 执行'), findsOneWidget);
      expect(find.textContaining('待你处理'), findsNothing);

      await tester.pumpWidget(_host(_repo()));
      await _hydrate(tester);
      expect(find.textContaining('触点'), findsNothing);
      expect(find.text(t.chat.stage.island), findsOneWidget); // the head title still renders 头标题仍在
    });
  });
}
