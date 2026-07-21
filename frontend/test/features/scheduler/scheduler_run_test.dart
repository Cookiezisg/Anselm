import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/run/flowrun_node_list.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_run_provider.dart';
import 'package:anselm/features/scheduler/ui/scheduler_run.dart';
import 'package:anselm/features/scheduler/ui/scheduler_run_inspector.dart';
import 'package:anselm/features/scheduler/ui/scheduler_run_relay.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'stub_scheduler_repo.dart';

// S4 · the run flagship + its two-faced right island (WRK-069 §5/§6). The batteries pin the page's
// three PROMISES: (1) one selection moves every altitude and lives in the URL; (2) the island is
// never blank and never lies about what it doesn't know (cold-open / tombstone / un-pinned graph);
// (3) a 650KB result is physically isolated in the island and costs the page nothing. A live run
// breathes forever → FIXED pumps, never pumpAndSettle. S4 电池:三海拔单选区/岛永不空白也不撒谎/
// 650KB 隔离;活 run 永远呼吸,固定 pump、绝不 settle。

final _now = DateTime.now();

/// The page is a full flagship + a 380 island — a phone-sized default viewport would overflow every
/// zone and drown the assertions in layout noise. 桌面视口:手机默认尺寸会让每个区溢出、把断言淹没在
/// 布局噪声里。
void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _graph = Graph(
  nodes: [
    Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_fetch'),
    Node(id: 'gate', kind: NodeKind.control, ref: 'ctl_gate'),
    Node(id: 'analyze', kind: NodeKind.agent, ref: 'ag_analyze'),
    Node(id: 'notify', kind: NodeKind.action, ref: 'fn_notify'),
  ],
  edges: [
    Edge(id: 'e1', from: 'fetch', to: 'gate'),
    Edge(id: 'e2', from: 'gate', fromPort: 'high', to: 'analyze'),
    Edge(id: 'e3', from: 'analyze', to: 'notify'),
  ],
);

/// TODAY's active graph — deliberately DIFFERENT from the pinned one, so a battery can tell which
/// map the flagship drew (§5.2 顺修 run_cockpit 错图 bug). 当下 active 图:刻意与钉版不同,以便断言
/// 旗舰画的是哪张地图。
const _activeGraph = Graph(
  nodes: [
    Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_fetch'),
    Node(id: 'rewritten', kind: NodeKind.agent, ref: 'ag_new'),
  ],
  edges: [Edge(id: 'e1', from: 'fetch', to: 'rewritten')],
);

FlowrunNode _node(
  String nodeId,
  String status, {
  String kind = 'action',
  int iteration = 0,
  int readySec = 0,
  int? startSec,
  int? endSec,
  String? error,
  Map<String, Object?> result = const {},
}) => FlowrunNode(
  id: 'frn_${nodeId}_$iteration',
  flowrunId: 'fr_run1',
  nodeId: nodeId,
  iteration: iteration,
  kind: kind,
  status: status,
  result: result,
  error: error,
  readyAt: startSec == null
      ? null
      : _now.subtract(Duration(seconds: 60 - readySec)),
  startedAt: startSec == null
      ? null
      : _now.subtract(Duration(seconds: 60 - startSec)),
  createdAt: _now.subtract(
    Duration(seconds: 60 - (endSec ?? startSec ?? readySec)),
  ),
  completedAt: endSec == null
      ? null
      : _now.subtract(Duration(seconds: 60 - endSec)),
  updatedAt: _now,
);

// The run HEADER's error and the failing NODE's error are DIFFERENT fields (flowrun.error vs
// flowrun_nodes.error): the header carries the engine's summary of why the run died, the node the raw
// failure. Seeding them distinctly is what lets a battery prove which surface reads which.
// run 头的 error 与失败节点的 error 是两个字段(引擎摘要 vs 原始失败);种成不同的串,才能断言哪个面读的
// 是哪一个。
final _huge = 'x' * 650000;

/// A run whose analyze turn returned a 650KB monster — the isolation proof (§6). 650KB 隔离证明。
StubSchedulerRepo _bigRepo() => _repo(
  status: 'completed',
  nodes: [
    _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
    _node(
      'analyze',
      'completed',
      kind: 'agent',
      readySec: 2,
      startSec: 3,
      endSec: 9,
      result: {'payload': _huge},
    ),
  ],
);

/// A run whose analyze looped three turns — the ×N fold + the iteration switcher. 循环 ×3。
StubSchedulerRepo _loopRepo() => _repo(
  status: 'completed',
  nodes: [
    for (var i = 0; i < 3; i++)
      _node(
        'analyze',
        'completed',
        kind: 'agent',
        iteration: i,
        readySec: i * 2,
        startSec: i * 2 + 1,
        endSec: i * 2 + 2,
        result: {'turn': i},
      ),
  ],
);

const _runError =
    'analyze failed: the run stopped here\n  run-level detail line';
const _nodeError =
    'timeout: LLM 30s no answer\n  at analyze step\n  stack frame two';

StubSchedulerRepo _repo({
  String status = 'failed',
  List<FlowrunNode>? nodes,
  bool orphan = false,
  bool pinnedMissing = false,
  // NO map at all: the pinned version is unreadable AND the host has no current graph either — the
  // flagship then has nothing to draw and must say so (vs [pinnedMissing], which still falls back to
  // today's active map and merely disclaims it). 一张图都没有:钉版读不出**且**宿主也无当前图——旗舰
  // 无可画,必须明说(对比 pinnedMissing:那时还能回退 active 图,只是要免责声明)。
  bool noGraph = false,
  Map<String, List<FlowrunActivityRow>> activity = const {},
}) => StubSchedulerRepo(
  workflows: orphan
      ? const []
      : [
          SchedulerWorkflowRow(
            id: 'wf_a',
            name: '数据清洗流水线',
            lifecycleState: 'active',
            updatedAt: _now,
          ),
        ],
  graphByWorkflow: noGraph ? const {} : const {'wf_a': _activeGraph},
  pinnedGraphByVersion: pinnedMissing || noGraph
      ? const {}
      : const {'wfv_pinned7': _graph},
  runs: [
    Flowrun(
      id: 'fr_run1',
      workflowId: 'wf_a',
      versionId: 'wfv_pinned7',
      pinnedRefs: const {'analyze': 'agv_analyze5'},
      origin: 'cron',
      triggerId: 'tr_cron',
      firingId: 'trf_1',
      status: status,
      error: status == 'failed' ? _runError : null,
      replayCount: 1,
      startedAt: _now.subtract(const Duration(seconds: 60)),
      completedAt: status == 'running'
          ? null
          : _now.subtract(const Duration(seconds: 51)),
      updatedAt: _now,
    ),
  ],
  nodesByRun: {
    'fr_run1':
        nodes ??
        [
          _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
          _node(
            'gate',
            'completed',
            kind: 'control',
            readySec: 2,
            startSec: 2,
            endSec: 3,
            result: const {'__port': 'high'},
          ),
          _node(
            'analyze',
            'failed',
            kind: 'agent',
            readySec: 3,
            startSec: 4,
            endSec: 9,
            error: _nodeError,
          ),
        ],
  },
  activityByRun: activity,
);

Widget _host(
  StubSchedulerRepo repo, {
  String? node,
  int? iter,
  bool relay = false,
}) {
  // The overlay pushes confirm dialogs onto the ROUTER's navigator — a detached key would silently
  // swallow every dialog. 操作反馈另走 noticeCenterProvider;这里的路由 key 只守确认框。
  final navKey = GlobalKey<NavigatorState>();
  final router = _router(navKey, node: node, iter: iter, relay: relay);
  return ProviderScope(
    overrides: [
      sseGatewayProvider.overrideWithValue(null),
      schedulerRepositoryProvider.overrideWithValue(repo),
      // The island's face derives from selectedSchedulerProvider, which derives ONE-WAY from this
      // router's delegate — the same seam the app root injects (§11 选区单向派生自 URL).
      // 岛的脸派生自选区,选区单向派生自路由 delegate——与 app 根注入同一条缝。
      goRouterProvider.overrideWithValue(router),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        theme: AnTheme.light(),
        routerConfig: router,
        builder: (context, child) =>
            AnOverlayHost(navigatorKey: navKey, child: child!),
      ),
    ),
  );
}

GoRouter _router(
  GlobalKey<NavigatorState> navKey, {
  String? node,
  int? iter,
  bool relay = false,
}) {
  return GoRouter(
    navigatorKey: navKey,
    initialLocation: relay
        ? '/scheduler/runs/fr_run1'
        : Uri(
            path: '/scheduler/w/wf_a/runs/fr_run1',
            queryParameters: {'node': ?node, if (iter != null) 'iter': '$iter'},
          ).toString(),
    routes: [
      GoRoute(
        path: '/scheduler/runs/:frId',
        builder: (c, s) =>
            SchedulerRunRelayView(flowrunId: s.pathParameters['frId']!),
      ),
      // The ✕/bare-Esc exit's landing pad (需求⑥) — the operations home, stubbed to a marker.
      // ✕/裸 Esc 出口的落点:运营主页,桩成标记。
      GoRoute(
        path: '/scheduler/w/:wfId',
        builder: (c, s) => Text('HOME LANDED ${s.pathParameters['wfId']}'),
      ),
      GoRoute(
        path: '/scheduler/w/:wfId/runs/:frId',
        builder: (c, s) => Scaffold(
          body: Row(
            children: [
              Expanded(
                child: SchedulerRunView(
                  workflowId: s.pathParameters['wfId']!,
                  flowrunId: s.pathParameters['frId']!,
                  nodeId: s.uri.queryParameters['node'],
                  iteration: int.tryParse(s.uri.queryParameters['iter'] ?? ''),
                ),
              ),
              const SizedBox(width: 380, child: SchedulerRunInspector()),
            ],
          ),
        ),
      ),
      GoRoute(path: '/chat/:id', builder: (c, s) => const Text('CHAT LANDED')),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  StubSchedulerRepo repo, {
  String? node,
  int? iter,
  bool relay = false,
}) async {
  await tester.pumpWidget(_host(repo, node: node, iter: iter, relay: relay));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('三海拔节奏 (0718 全模块对齐审计)', () {
    testWidgets(
      'altitude seams stack FLUSH (each AnSection carries its own 24 bottom — 曾 24/48/48) '
      'and the gantt wears the same frame as its two neighbours',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        Rect secOf(Finder inner) => tester.getRect(
          find.ancestor(of: inner, matching: find.byType(AnSection)).first,
        );
        final graphSec = secOf(find.byType(AnGraphCanvas));
        final ganttSec = secOf(find.byType(AnNodeGantt));
        final ledgerSec = secOf(find.byType(FlowrunNodeList));
        expect(
          ganttSec.top - graphSec.bottom,
          moreOrLessEquals(0, epsilon: 0.6),
          reason: '图→甘特贴合(24 在段自身底距,外无 top 垫)',
        );
        expect(
          ledgerSec.top - ganttSec.bottom,
          moreOrLessEquals(0, epsilon: 0.6),
          reason: '甘特→台账贴合',
        );
        // The gantt is FRAMED like the graph canvas and the ledger window — no bare altitude floating
        // between two bordered cards (0718 对齐审计:左轨同源). 甘特穿框,不再裸浮两卡之间。
        expect(
          find.ancestor(
            of: find.byType(AnNodeGantt),
            matching: find.byType(AnWindow),
          ),
          findsOneWidget,
          reason: '甘特住 AnWindow',
        );
      },
    );
  });

  group('卷宗头 (§5.1)', () {
    testWidgets(
      'the error sentence is the FIRST LINE, and the same string reaches the ledger row',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        // The HEAD speaks the run header's FIRST LINE only — its detail line stays out of the head.
        // 头只说 run 头 error 的首句,细节行不进头。
        final head = find.byType(SchedulerRunView);
        expect(
          find.descendant(
            of: head,
            matching: find.textContaining(
              'analyze failed: the run stopped here',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: head,
            matching: find.textContaining('run-level detail line'),
          ),
          findsNothing,
          reason: 'run 头 error 的全文归右岛卷宗脸',
        );
        // The failing NODE's sentence reaches the ledger row — the same errorSentence() fold, applied
        // to the node's own field. 失败节点的首句进台账行:同一个 errorSentence(),作用在节点自己的字段上。
        expect(
          find.descendant(
            of: find.byType(FlowrunNodeList),
            matching: find.textContaining('timeout: LLM 30s no answer'),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      '«排队 x · 执行 y» renders off REAL ⑫/⑤ data, and the ↻N + origin badges ride along',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        expect(
          find.textContaining(t.scheduler.run.queueWord),
          findsWidgets,
          reason: '排队段有 ⑫ 真数据',
        );
        expect(find.textContaining(t.scheduler.run.execWord), findsWidgets);
        expect(
          find.textContaining(t.scheduler.run.pinnedVersion),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'the un-pinnable graph SAYS so instead of passing today\'s map off as the run\'s',
      (tester) async {
        _desktop(tester);
        final repo = _repo(pinnedMissing: true);
        await _pump(tester, repo);
        expect(
          repo.versionAsked,
          contains('wfv_pinned7'),
          reason: '先问钉版(§5.2)',
        );
        expect(
          find.textContaining(t.scheduler.run.graphNotPinned),
          findsOneWidget,
          reason: '取不到钉版 → 明说这是当下的图',
        );
      },
    );

    testWidgets(
      'a pinned run draws the PINNED topology, never today\'s rewritten one',
      (tester) async {
        _desktop(tester);
        final repo = _repo();
        await _pump(tester, repo);
        expect(repo.versionAsked, ['wfv_pinned7']);
        // 'rewritten' exists only in the ACTIVE graph — seeing it would be the run_cockpit 错图 bug.
        // rewritten 只存在于 active 图:它出现即是 run_cockpit 的错图 bug。
        expect(find.text('rewritten'), findsNothing);
        expect(find.text('analyze'), findsWidgets);
        expect(
          find.textContaining(t.scheduler.run.graphNotPinned),
          findsNothing,
        );
      },
    );

    testWidgets(
      'with NO map to draw, the altitude says «we cannot know» — it never vanishes in '
      'silence (§5 三海拔:静默掉一拔会被读成页面坏了)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(noGraph: true));
        expect(
          find.text(t.scheduler.run.graphEmpty),
          findsOneWidget,
          reason: '诚实话在场——不是静默消失',
        );
        expect(find.byType(AnGraphCanvas), findsNothing, reason: '没有图就不画图');
        // The wrong-map banner would be a lie here — there IS no map to disclaim.
        // 错图免责声明在此是谎:根本没有图可免责。
        expect(
          find.textContaining(t.scheduler.run.graphNotPinned),
          findsNothing,
        );
        // The other two altitudes are untouched — what is missing is the MAP, not the page.
        // 另两拔照常:缺的是**地图**,不是页面。
        expect(find.byType(AnNodeGantt), findsOneWidget, reason: '甘特照常');
        expect(find.byType(FlowrunNodeList), findsOneWidget, reason: '台账照常');
      },
    );
  });

  group('孤儿墓碑 (§5.7)', () {
    testWidgets(
      'a soft-deleted host keeps the page reachable, wears the tombstone, and disables '
      'everything but replay',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(orphan: true));
        expect(find.text(t.scheduler.run.orphanBadge), findsOneWidget);
        // Replay survives (a run's archive is repairable without its host); triage does not.
        // replay 活着(档案不依赖宿主即可修);诊断不。
        expect(
          find.widgetWithText(AnButton, t.scheduler.run.replay),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(AnButton, t.scheduler.run.triage),
          findsNothing,
        );
      },
    );
  });

  group('冷打开推测态 (§5.5)', () {
    testWidgets(
      'a live run with NO node rows renders the pinned stubs + an honest empty ledger — '
      'never a blank page',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(status: 'running', nodes: const []));
        expect(find.byType(AnNodeGantt), findsOneWidget, reason: '钉版图的占位仍在场');
        expect(
          find.text(t.scheduler.run.ledgerEmpty),
          findsOneWidget,
          reason: '诚实空台账,而非空白',
        );
        expect(find.textContaining(t.scheduler.run.notRun), findsWidgets);
      },
    );

    testWidgets(
      'a live run WITH settled rows labels its un-rowed front «推测执行中», not a fact',
      (tester) async {
        _desktop(tester);
        await _pump(
          tester,
          _repo(
            status: 'running',
            nodes: [
              _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
              _node(
                'gate',
                'completed',
                kind: 'control',
                readySec: 2,
                startSec: 2,
                endSec: 3,
                result: const {'__port': 'high'},
              ),
            ],
          ),
        );
        expect(
          find.text(t.run.inferredRunning),
          findsWidgets,
          reason: 'analyze 是推测前沿:标注它,不假装量到了',
        );
      },
    );
  });

  group('三海拔单选区 (§5 + §6 双脸)', () {
    testWidgets(
      'no selection → the island shows the DOSSIER face (never blank)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        expect(find.text(t.scheduler.run.dossierTitle), findsOneWidget);
        // The dossier is where the error lives IN FULL. 卷宗才是错误全文的家。
        expect(
          find.descendant(
            of: find.byType(SchedulerRunInspector),
            matching: find.textContaining('run-level detail line'),
          ),
          findsOneWidget,
          reason: 'run 头 error 的全文住卷宗脸',
        );
        expect(
          find.text(t.scheduler.run.pinnedRefsHead),
          findsOneWidget,
          reason: '钉住的闭包',
        );
      },
    );

    testWidgets(
      '?node= → the island swaps to the INSPECTOR face for that node',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(), node: 'analyze', iter: 0);
        expect(find.text(t.scheduler.run.inspectorTitle), findsOneWidget);
        expect(find.text(t.scheduler.run.dossierTitle), findsNothing);
      },
    );

    testWidgets(
      'picking a ledger row WRITES the selection into the URL (shareable, reloadable)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        expect(find.text(t.scheduler.run.dossierTitle), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(FlowrunNodeList),
            matching: find.text('fetch'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final router = GoRouter.of(
          tester.element(find.byType(FlowrunNodeList)),
        );
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['node'],
          'fetch',
          reason: '选区的唯一真相是 URL',
        );
        expect(find.text(t.scheduler.run.inspectorTitle), findsOneWidget);
      },
    );

    testWidgets(
      'picking the SAME row again clears the selection back to the dossier (Esc\'s twin)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(), node: 'fetch', iter: 0);
        await tester.tap(
          find.descendant(
            of: find.byType(FlowrunNodeList),
            matching: find.text('fetch'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final router = GoRouter.of(
          tester.element(find.byType(SchedulerRunView)),
        );
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['node'],
          isNull,
        );
        expect(find.text(t.scheduler.run.dossierTitle), findsOneWidget);
      },
    );

    // The Esc LADDER's two rungs (需求⑥ 0717-晚, 复审: interactive code must not land untested).
    // The key rides the page's own CallbackShortcuts+Focus (settings 先例, 真机验证过的形) — the
    // test puts focus inside that subtree the way any page interaction does.
    // Esc 阶梯两档:键挂页自己的 CallbackShortcuts+Focus(设置先例);测试照真用把焦点放进该子树。
    testWidgets(
      'Esc rung 1: WITH a node selection, Esc clears it and STAYS on the flagship',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(), node: 'fetch', iter: 0);
        Focus.of(tester.element(find.byType(AnPage).first)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final router = GoRouter.of(
          tester.element(find.byType(SchedulerRunView)),
        );
        final uri = router.routerDelegate.currentConfiguration.uri;
        expect(uri.queryParameters['node'], isNull, reason: '第一档:清选区');
        expect(uri.path, '/scheduler/w/wf_a/runs/fr_run1', reason: '还在旗舰,不出门');
        expect(find.text(t.scheduler.run.dossierTitle), findsOneWidget);
      },
    );

    testWidgets(
      'Esc rung 2: with NOTHING selected, Esc IS the ✕ — back to the operations home',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo());
        Focus.of(tester.element(find.byType(AnPage).first)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('HOME LANDED wf_a'),
          findsOneWidget,
          reason: '第二档:无选区的裸 Esc=✕,回运营主页',
        );
        // Ride out the route transition before asserting the flagship LEFT the tree (fixed pumps —
        // the suite never settles). 等转场走完再断言旗舰离树(固定 pump,套件不 settle)。
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(SchedulerRunView), findsNothing);
      },
    );
  });

  group('检查器脸 (§6)', () {
    testWidgets(
      'the dossier KV: label «状态» + LOCALIZED value + pinned «v7» — never a status word '
      'as a label, never a raw wire word, never a bare wfv_ id (「运行中 failed」帧 0717-深夜)',
      (tester) async {
        _desktop(tester);
        // A CANCELLED seed: the EN word ('Cancelled') differs from the wire word ('cancelled'), so the
        // raw-leak probe is provable — a failed seed can't tell (en run.failed IS 'failed').
        // 取消态种子:EN 词与线缆词大小写可分辨,裸词探针才可证——failed 种子在 EN 下词=线缆词,测不出。
        await _pump(tester, _repo(status: 'cancelled'));
        final island = find.byType(SchedulerRunInspector);
        expect(
          find.descendant(
            of: island,
            matching: find.text(t.scheduler.run.kvStatus),
          ),
          findsWidgets,
          reason: '标签是「状态」栏目词,不是某个状态的词',
        );
        expect(
          find.descendant(of: island, matching: find.text(t.run.runCancelled)),
          findsWidgets,
          reason: '值走本地化词表(flowrunStatusWord)',
        );
        expect(
          find.descendant(of: island, matching: find.text('cancelled')),
          findsNothing,
          reason: '裸线缆词曾直渲(「运行中 → failed」同病)',
        );
        expect(
          find.descendant(of: island, matching: find.text(t.status.run)),
          findsNothing,
          reason: 'status.run(运行中)曾错当标签——非在跑 run 的岛里不该有这词',
        );
        expect(
          find.descendant(of: island, matching: find.text('v7')),
          findsOneWidget,
          reason: '钉版念人话版本号(需求⑤)',
        );
        expect(
          find.descendant(of: island, matching: find.textContaining('wfv_')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the Output viewport is CONTENT-HEIGHT for a small result — 3 keys must not prop '
      'open 240px of blank (WRK-070 B8)',
      (tester) async {
        _desktop(tester);
        await _pump(
          tester,
          _repo(
            status: 'completed',
            nodes: [
              _node(
                'fetch',
                'completed',
                readySec: 0,
                startSec: 1,
                endSec: 2,
                result: const {'rows': 4200, 'digest': 'sha256:aa', 'ok': true},
              ),
            ],
          ),
          node: 'fetch',
          iter: 0,
        );
        expect(
          tester.getSize(find.byType(AnJsonTree)).height,
          AnSize.row * 3,
          reason: '3 键=3 行内容高,不撑 240',
        );
      },
    );

    testWidgets(
      '…and CAPS at the viewport for a big result — deeper content scrolls within '
      '(WRK-070 B8)',
      (tester) async {
        _desktop(tester);
        await _pump(
          tester,
          _repo(
            status: 'completed',
            nodes: [
              _node(
                'fetch',
                'completed',
                readySec: 0,
                startSec: 1,
                endSec: 2,
                result: {for (var i = 0; i < 12; i++) 'k$i': i},
              ),
            ],
          ),
          node: 'fetch',
          iter: 0,
        );
        expect(
          tester.getSize(find.byType(AnJsonTree)).height,
          AnSize.jsonViewport,
          reason: '12 键超上限=封顶 240,框内滚',
        );
      },
    );

    testWidgets(
      'a 650KB result is NEVER dumped on the page (§5.4 页面本身零 JSON 倾倒)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _bigRepo());
        expect(
          find.descendant(
            of: find.byType(SchedulerRunView),
            matching: find.textContaining(_huge.substring(0, 200)),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(SchedulerRunView),
            matching: find.byType(AnJsonTree),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a 650KB result opens in the island\'s VIRTUALIZED tree without exploding the build',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _bigRepo(), node: 'analyze', iter: 0);
        // Bounded + virtualized: only the visible rows materialize, so the monster costs what you see.
        // 有界+虚拟化:只物化可见行,巨物只花你看到的那点钱。
        expect(find.byType(AnJsonTree), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '650KB 不得炸 build');
      },
    );

    testWidgets('a loop node grows the iteration switcher (§6 «#0 ▾» 逐轮取证)', (
      tester,
    ) async {
      _desktop(tester);
      await _pump(tester, _loopRepo(), node: 'analyze', iter: 2);
      expect(find.text(t.scheduler.run.iterationPick), findsOneWidget);
      expect(find.byType(AnDropdown<int>), findsOneWidget);
    });

    testWidgets(
      'a single-turn node grows NO switcher — a one-option control is noise',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(), node: 'fetch', iter: 0);
        expect(find.text(t.scheduler.run.iterationPick), findsNothing);
      },
    );

    testWidgets(
      'the ⑤ execId reaches the inspector as the execution-log coordinate',
      (tester) async {
        _desktop(tester);
        final repo = _repo(
          activity: {
            'fr_run1': [
              FlowrunActivityRow(
                nodeId: 'analyze',
                iteration: 0,
                kind: 'agent',
                execId: 'agx_deadbeef0000001',
                status: 'failed',
                startedAt: _now.subtract(const Duration(seconds: 56)),
                endedAt: _now.subtract(const Duration(seconds: 51)),
                elapsedMs: 5000,
              ),
            ],
          },
        );
        await _pump(tester, repo, node: 'analyze', iter: 0);
        expect(repo.activityAsked, contains('fr_run1'));
        expect(find.text(t.scheduler.run.execLogHead), findsOneWidget);
        expect(find.textContaining('agx_deadbeef0000001'), findsOneWidget);
      },
    );

    testWidgets(
      'a node with no row (a stale shared ?node=) is honest, not blank',
      (tester) async {
        _desktop(tester);
        await _pump(tester, _repo(), node: 'ghost_node', iter: 0);
        expect(find.text(t.scheduler.run.inspectorTitle), findsOneWidget);
        expect(find.text('ghost_node'), findsWidgets);
      },
    );
  });

  group('活动读失败 (⑤ 的诚实回退)', () {
    testWidgets(
      'listActivity throwing degrades the gantt to the row\'s own stamps, never blanks',
      (tester) async {
        _desktop(tester);
        final repo = StubSchedulerRepo(
          workflows: [
            SchedulerWorkflowRow(
              id: 'wf_a',
              name: 'x',
              lifecycleState: 'active',
              updatedAt: _now,
            ),
          ],
          pinnedGraphByVersion: const {'wfv_pinned7': _graph},
          failActivity: true,
          runs: [
            Flowrun(
              id: 'fr_run1',
              workflowId: 'wf_a',
              versionId: 'wfv_pinned7',
              status: 'completed',
              startedAt: _now.subtract(const Duration(seconds: 60)),
              completedAt: _now.subtract(const Duration(seconds: 51)),
              updatedAt: _now,
            ),
          ],
          nodesByRun: {
            'fr_run1': [
              _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
            ],
          },
        );
        await _pump(tester, repo);
        expect(find.byType(AnNodeGantt), findsOneWidget);
        // The queue leg survives (it comes from ⑫ on the ROW, not from ⑤). 排队段仍在(它来自行的 ⑫)。
        expect(find.textContaining(t.scheduler.run.queueWord), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('fr_ 中转位 (§11)', () {
    testWidgets('resolves the host workflow and hands over to the flagship', (
      tester,
    ) async {
      _desktop(tester);
      await _pump(tester, _repo(), relay: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(SchedulerRunView),
        findsOneWidget,
        reason: 'fr_ id 直达旗舰',
      );
      final router = GoRouter.of(tester.element(find.byType(SchedulerRunView)));
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/scheduler/w/wf_a/runs/fr_run1',
      );
    });

    testWidgets('an unresolvable id gets a SENTENCE, not a blank screen', (
      tester,
    ) async {
      _desktop(tester);
      await _pump(tester, StubSchedulerRepo(), relay: true);
      expect(find.text(t.scheduler.run.relayFailedTitle), findsOneWidget);
      expect(find.byType(SchedulerRunView), findsNothing);
    });
  });

  group('操作 (§10)', () {
    testWidgets(
      'AI triage 202 → hands the user straight into the chat conversation',
      (tester) async {
        _desktop(tester);
        final repo = _repo();
        await _pump(tester, repo);
        await tester.tap(
          find.widgetWithText(AnButton, t.scheduler.run.triage).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(repo.triageOrder, ['fr_run1']);
        expect(find.text('CHAT LANDED'), findsOneWidget);
      },
    );

    testWidgets(
      'replay confirms with the REAL memoization numbers, already in hand (no extra fetch)',
      (tester) async {
        _desktop(tester);
        final repo = _repo();
        await _pump(tester, repo);
        await tester.tap(
          find.widgetWithText(AnButton, t.scheduler.run.replay).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // 2 completed rows reused, 1 failed rerun — the page already held every node row. 真数字在手。
        expect(
          find.text(t.scheduler.home.replayBody(failed: '1', completed: '2')),
          findsOneWidget,
          reason: '记忆化承诺文案:重跑 1 个失败节点、复用 2 个已完成结果',
        );
      },
    );
  });

  group('活性军规 (§0/§5.6)', () {
    test(
      'a tick PAINTS the live front but never touches the DB truth rows',
      () async {
        // The rule under test is the fold, so drive the seam directly (a real gateway needs a socket).
        // 待测的是折叠规则,故直驱帧缝。
        final repo = _repo(
          status: 'running',
          nodes: [
            _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            sseGatewayProvider.overrideWithValue(null),
            schedulerRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        await container.read(schedulerRunProvider('fr_run1').future);
        final ctrl = container.read(schedulerRunProvider('fr_run1').notifier);

        ctrl.onFrameForTest(_tickEnv('fr_run1', 'gate', 'completed'));
        var d = container.read(schedulerRunProvider('fr_run1')).value!;
        expect(d.comp.nodes.map((n) => n.nodeId), [
          'fetch',
        ], reason: 'tick 不进耐久缓存');
        expect(
          d.nodes.map((n) => n.nodeId),
          containsAll(['fetch', 'gate']),
          reason: 'tick 只作画',
        );

        // A SIBLING run's tick on the same workflow scope is not ours. 兄弟 run 的 tick 不是我们的。
        ctrl.onFrameForTest(_tickEnv('fr_other', 'notify', 'completed'));
        d = container.read(schedulerRunProvider('fr_run1')).value!;
        expect(d.nodes.map((n) => n.nodeId), isNot(contains('notify')));
      },
    );

    test(
      'a reconcile re-reads the RUN, not the immutable map (a 4s poll must not re-fetch a pinned '
      'version that cannot have changed)',
      () async {
        final repo = _repo(status: 'running');
        final container = ProviderContainer(
          overrides: [
            sseGatewayProvider.overrideWithValue(null),
            schedulerRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        await container.read(schedulerRunProvider('fr_run1').future);
        expect(repo.versionAsked, ['wfv_pinned7'], reason: '首读取钉版');

        await container
            .read(schedulerRunProvider('fr_run1').notifier)
            .refresh();
        expect(repo.versionAsked, [
          'wfv_pinned7',
        ], reason: '对账重用已解出的钉版:不可变的东西不重读');
        expect(repo.activityAsked.length, 2, reason: '活动随 run 生长,每次都重读');
      },
    );

    test(
      'a reconcile RETRIES a version that failed to pin (a transient 404 must not brand the page '
      '«un-pinned» forever)',
      () async {
        final repo = _repo(pinnedMissing: true);
        final container = ProviderContainer(
          overrides: [
            sseGatewayProvider.overrideWithValue(null),
            schedulerRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        await container.read(schedulerRunProvider('fr_run1').future);
        await container
            .read(schedulerRunProvider('fr_run1').notifier)
            .refresh();
        expect(repo.versionAsked.length, 2, reason: '没钉上的会再试');
      },
    );

    test('a truth row never regresses to a tick placeholder', () async {
      final repo = _repo(
        status: 'running',
        nodes: [
          _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 2),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          sseGatewayProvider.overrideWithValue(null),
          schedulerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(schedulerRunProvider('fr_run1').future);
      final ctrl = container.read(schedulerRunProvider('fr_run1').notifier);
      ctrl.onFrameForTest(_tickEnv('fr_run1', 'fetch', 'completed'));
      final d = container.read(schedulerRunProvider('fr_run1')).value!;
      final fetch = d.nodes.firstWhere((n) => n.nodeId == 'fetch');
      expect(fetch.startedAt, isNotNull, reason: '真相行的戳不被无戳的 tick 占位抹掉');
    });
  });

  // ── 三段式文法 §1+§2 (0719): the run inspector head is AnPanelHead + a §2 glance strip carrying the
  // run's parent WORKFLOW operational context, read off the rail. 头=AnPanelHead + 父 workflow 速览带。
  group('head 三段式文法 (§1+§2)', () {
    // A repo whose rail returns real 7d stats (20% ok, 4 failing) + a future cron fire for wf_a, so
    // all three glance segments render. 让三段速览段全渲的 repo。
    StubSchedulerRepo glanceRepo() => StubSchedulerRepo(
      workflows: [
        SchedulerWorkflowRow(
          id: 'wf_a',
          name: '数据清洗流水线',
          lifecycleState: 'active',
          updatedAt: _now,
        ),
      ],
      byWorkflow: const [
        WorkflowRunStats(
          workflowId: 'wf_a',
          successRate: 0.2,
          consecutiveFailures: 4,
        ),
      ],
      triggers: [
        TriggerEntity(
          id: 'tr_cron',
          name: 'nightly',
          kind: TriggerSource.cron,
          listening:
              true, // the rail joins next-fires only for LISTENING triggers 只连监听中
          nextFireAt: _now.add(const Duration(hours: 2)),
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
      edges: const [
        EntityRelation(
          id: 'rel_1',
          kind: 'equip',
          fromKind: 'workflow',
          fromId: 'wf_a',
          toKind: 'trigger',
          toId: 'tr_cron',
          toName: 'nightly',
        ),
      ],
      graphByWorkflow: const {'wf_a': _activeGraph},
      pinnedGraphByVersion: const {'wfv_pinned7': _graph},
      runs: [
        Flowrun(
          id: 'fr_run1',
          workflowId: 'wf_a',
          versionId: 'wfv_pinned7',
          origin: 'cron',
          triggerId: 'tr_cron',
          status: 'failed',
          error: _runError,
          startedAt: _now.subtract(const Duration(seconds: 60)),
          completedAt: _now.subtract(const Duration(seconds: 51)),
          updatedAt: _now,
        ),
      ],
      nodesByRun: {
        'fr_run1': [
          _node('analyze', 'failed', kind: 'agent', error: _nodeError),
        ],
      },
    );

    testWidgets(
      'head = AnPanelHead (dossier title, NO ⋯ — replay/triage are body actions)',
      (tester) async {
        _desktop(tester);
        await _pump(tester, glanceRepo());
        final head = tester.widget<AnPanelHead>(
          find.descendant(
            of: find.byType(SchedulerRunInspector),
            matching: find.byType(AnPanelHead),
          ),
        );
        expect(head.title, t.scheduler.run.dossierTitle);
        expect(head.menuEntries, isEmpty); // no panel-scoped action → no ⋯
      },
    );

    testWidgets('§2 glance: 下次点火 · 近 7 天成功率 · 连败 (all read off the rail)', (
      tester,
    ) async {
      _desktop(tester);
      await _pump(tester, glanceRepo());
      // The rail futures resolve on top of the run — pump a little more. 让 rail 落定。
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final tr = t.scheduler.run;
      expect(
        find.textContaining(tr.glanceSuccess(pct: 20)),
        findsOneWidget,
      ); // 近 7 天 20% 成功
      expect(
        find.textContaining(tr.glanceStreak(n: 4)),
        findsOneWidget,
      ); // 连败 4
      // The glance is ONE ' · '-joined Text — pull it and prove ALL THREE segments (next-fire · rate ·
      // streak) are present, locale-agnostically (the next-fire duration word is clock-fragile).
      // glance 是一条 ' · ' 拼接 Text:取它证三段齐(下次点火·成功率·连败),locale 无关。
      final glance = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AnPanelHead),
              matching: find.byType(Text),
            ),
          )
          .map((w) => w.data)
          .whereType<String>()
          .firstWhere((s) => s.contains(tr.glanceStreak(n: 4)));
      final segs = glance.split(' · ');
      expect(segs.length, 3, reason: '下次点火 · 成功率 · 连败 三段齐');
      expect(
        segs.first,
        tr.glanceNextFire(d: segs.first.split(' ').last),
      ); // first = next-fire
    });

    testWidgets(
      '§2 glance omits absent segments — no rail stats → no band (全空不渲)',
      (tester) async {
        _desktop(tester);
        // _repo() seeds NO byWorkflow stats / triggers / edges → the rail has nothing for wf_a. 无 rail 数据。
        await _pump(tester, _repo());
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final tr = t.scheduler.run;
        expect(
          find.byType(AnPanelHead),
          findsOneWidget,
        ); // the head still stands 头还在
        // No band at all — the head carries only its title Text (no glance segment). 无速览带,只剩标题。
        expect(
          find.descendant(
            of: find.byType(AnPanelHead),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(tr.glanceStreak(n: 4)), findsNothing);
      },
    );
  });
}

/// The EPHEMERAL flowrun tick exactly as the backend sends it (events.md workflow 行:seq=0,
/// workflow scope, `node.type="run"`, content `{flowrunId,nodeId,iteration,status,port?}`).
/// 真帧形的 ephemeral flowrun tick。
StreamEnvelope _tickEnv(String frId, String nodeId, String status) =>
    StreamEnvelope(
      seq: 0, // ephemeral — the whole point 正是重点
      scope: const StreamScope(kind: 'workflow', id: 'wf_a'),
      id: 'n1',
      frame: FrameSignal(
        node: StreamNode(
          type: 'run',
          content: {
            'flowrunId': frId,
            'nodeId': nodeId,
            'iteration': 0,
            'status': status,
          },
        ),
      ),
    );
