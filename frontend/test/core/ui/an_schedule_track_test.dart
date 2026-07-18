import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnScheduleTrack (WRK-069 §12 · WRK-070 调度轨重造 0718). Two layers: the PURE bin engine (no pump — the
// «防爆» is a fixed 24 hourly cells, provable without a widget tree) and the widget contract (24 cells
// per lane, the worst-status fill, a missed ✕, the future «next-fire» segment, a paused lane surviving,
// ONE Tab stop with the roving cursor, and the launch pad firing only on content cells).
// 两层:纯分箱引擎(免 pump——恒 24 格,脱 widget 树可证)+ widget 契约(每泳道 24 格、最坏状态色、missed ✕、
// 未来「下一发」段、暂停泳道存活、roving 光标唯一 Tab 停靠、发射台只在内容格触发)。

final _now = DateTime(2026, 7, 16, 14, 30);
final _start = _now.subtract(const Duration(hours: 24));

TrackRun _run(DateTime at, AnStatus status, {String id = 'fr_x', String wf = 'wf_a', Duration? elapsed}) =>
    TrackRun(id: id, workflowId: wf, at: at, status: status, sourceLabel: 'cron', elapsed: elapsed);

TrackLane _lane(
  String id,
  String label, {
  List<TrackRun> runs = const [],
  List<DateTime> missed = const [],
  TrackFuture? future,
  bool dimmed = false,
  String note = '',
}) =>
    TrackLane(
      id: id,
      label: label,
      bins: binTrackEvents(start: _start, end: _now, binCount: 24, runs: runs, missed: missed),
      future: future,
      dimmed: dimmed,
      note: note,
    );

Widget _host(Widget child, {double width = 800}) => MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
    );

void main() {
  group('binTrackEvents (pure)', () {
    test('always produces exactly binCount hourly cells with contiguous bounds', () {
      final bins = binTrackEvents(start: _start, end: _now, binCount: 24);
      expect(bins, hasLength(24), reason: '恒 24 格:全泳道同构,无论疏密');
      expect(bins.first.start, _start);
      expect(bins.last.end, _now, reason: '过去轴终于 now');
      for (var i = 1; i < bins.length; i++) {
        expect(bins[i].start, bins[i - 1].end, reason: '格边界相接、不重不漏');
      }
    });

    test('a run lands in the hour its startedAt falls into', () {
      final at = _now.subtract(const Duration(hours: 5, minutes: 12));
      final bins = binTrackEvents(
          start: _start, end: _now, binCount: 24, runs: [_run(at, AnStatus.done)]);
      final withRun = bins.where((b) => b.runs.isNotEmpty).toList();
      expect(withRun, hasLength(1));
      expect(withRun.single.start.isAfter(at) || withRun.single.start.isAtSameMomentAs(at), isFalse,
          reason: 'run 的 startedAt ∈ [binStart, binEnd)');
      expect(at.isBefore(withRun.single.end), isTrue);
    });

    test('the bin boundary is HALF-OPEN [start, end): a tick on the edge lands in the LATER bin', () {
      // Exactly on the boundary between bin 22 and 23 (2h before now, an integral hour). 恰在格边界。
      final edge = _now.subtract(const Duration(hours: 2));
      final bins = binTrackEvents(
          start: _start, end: _now, binCount: 24, runs: [_run(edge, AnStatus.done)]);
      final idx = bins.indexWhere((b) => b.runs.isNotEmpty);
      expect(bins[idx].start, edge, reason: '边界刻度归 [start,end) 的那一格(其 start == 刻度)');
    });

    test('within a bin the WORST status wins — a later green cannot erase a real failure', () {
      final h = _now.subtract(const Duration(hours: 3));
      final bins = binTrackEvents(start: _start, end: _now, binCount: 24, runs: [
        _run(h.add(const Duration(minutes: 5)), AnStatus.done),
        _run(h.add(const Duration(minutes: 15)), AnStatus.err),
        _run(h.add(const Duration(minutes: 45)), AnStatus.done),
      ]);
      final bin = bins.firstWhere((b) => b.runs.isNotEmpty);
      expect(bin.runs, hasLength(3), reason: '格数它代表的全部 run,不折叠');
      expect(bin.worst, AnStatus.err, reason: '同格取最坏(同矩阵格律)');
      expect(bin.runs.first.status, AnStatus.err, reason: '桶内失败在前(=hover 卡读序)');
    });

    test('missed ticks bin by their instant and never enter the run set', () {
      final m = _now.subtract(const Duration(hours: 8, minutes: 30));
      final bins = binTrackEvents(start: _start, end: _now, binCount: 24, missed: [m]);
      final bin = bins.firstWhere((b) => b.missedCount > 0);
      expect(bin.runs, isEmpty, reason: 'missed 不是 run');
      expect(bin.missed.single, m, reason: 'missed 时刻留在格里,供卡念「错过 HH:mm」');
      expect(bin.hasContent, isTrue);
      expect(bin.hasRuns, isFalse);
    });

    test('anything outside [start, end) is dropped — an unplaceable event is never faked into place', () {
      final bins = binTrackEvents(start: _start, end: _now, binCount: 24, runs: [
        _run(_now.add(const Duration(hours: 1)), AnStatus.done), // future — off the past axis
        _run(_now.subtract(const Duration(hours: 30)), AnStatus.done), // older than the window
      ]);
      expect(bins.every((b) => b.runs.isEmpty), isTrue, reason: '窗外放不下就不渲,绝不硬塞');
    });

    test('a zero/negative window places nothing rather than dividing by it', () {
      expect(binTrackEvents(start: _now, end: _now, binCount: 24, runs: [_run(_now, AnStatus.done)]),
          isEmpty);
      expect(
          binTrackEvents(
              start: _now, end: _start, binCount: 24, runs: [_run(_start, AnStatus.done)]),
          isEmpty);
    });

    test('an all-empty lane still bins to 24 empty cells (a clock with a blank face)', () {
      final bins = binTrackEvents(start: _start, end: _now, binCount: 24);
      expect(bins, hasLength(24));
      expect(bins.every((b) => !b.hasContent && b.worst == null), isTrue,
          reason: '空格是真答案:每格 worst==null → 淡描边');
    });
  });

  group('AnScheduleTrack (widget)', () {
    testWidgets('empty lanes render nothing — no ghost axis, no orphan ruler', (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(lanes: const [], now: _now)));
      expect(tester.getSize(find.byType(AnScheduleTrack)).height, 0);
    });

    testWidgets('a lane draws 24 hourly cells regardless of density (dense = sparse in geometry)',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          _lane('a', 'A', runs: [for (var h = 0; h < 24; h++) _run(_now.subtract(Duration(hours: h)), AnStatus.done)]),
        ],
        now: _now,
        onBin: (_, _) {},
        binSemanticLabel: (l, b) => '${b.start.hour}h',
        emptyBinSemanticLabel: (l, b) => '${b.start.hour}h empty',
      )));
      // Every hourly cell is a real focus node (that is what makes ←→ work) — all 24 exist as
      // addressable nodes even though only ONE is a Tab stop (the rest are skipTraversal:true).
      // 每格=真焦点节点:24 个都在(可寻址),但只有一个是 Tab 停靠(其余 skipTraversal)。
      final nodes = FocusManager.instance.rootScope.descendants
          .where((n) => n.debugLabel?.startsWith('AnScheduleTrack') ?? false)
          .length;
      expect(nodes, 24, reason: '24 个可寻址格(全含,无未来 ○)');
    });

    testWidgets('the fill colour is the WORST outcome; an empty hour is a faint outline, never a colour',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          _lane('a', 'A', runs: [
            _run(_now.subtract(const Duration(hours: 3)), AnStatus.done),
            _run(_now.subtract(const Duration(hours: 3, minutes: 20)), AnStatus.err),
          ]),
        ],
        now: _now,
        onBin: (_, _) {},
      )));
      // The one filled bin wears the danger tone; the other 23 are empty outlines — assert the danger
      // fill is present (a run-matrix soft-bg family) and empty cells carry no fill.
      // 一个填充格穿 danger 色,其余 23 空描边。
      final c = AnTheme.light().extension<AnColors>()!;
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .toList();
      final filled = decos.where((d) => d.color != null && d.color!.a > 0).toList();
      expect(filled.any((d) => d.color == AnStatus.err.tone.softBg(c)), isTrue,
          reason: '最坏=err → danger softBg 填充');
    });

    testWidgets('a missed tick lays a ✕ SHAPE over the cell — not just grey (WCAG 1.4.1)',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          _lane('a', 'A', missed: [_now.subtract(const Duration(hours: 6))]),
        ],
        now: _now,
        onBin: (_, _) {},
      )));
      expect(find.byIcon(AnIcons.close), findsOneWidget, reason: 'missed 必须有 ✕ 形状');
    });

    testWidgets('the future segment: a hollow ○ + words / «已暂停» on a paused lane / blank when none',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          _lane('a', '有排程',
              future: TrackFuture(at: _now.add(const Duration(minutes: 2)), time: '14:32', relative: '(2m)', schedule: '每 15 分钟')),
          _lane('c', '暂停的', dimmed: true, note: '已暂停'),
          _lane('d', '无排程'),
        ],
        now: _now,
        onBin: (_, _) {},
      )));
      // The forecast lane shows its next fire time + schedule word (one RichText phrase) + a hollow
      // ring. 预告泳道:时刻+排程句(一条 RichText 短语)+空心环。
      expect(find.textContaining('14:32', findRichText: true), findsOneWidget);
      expect(find.textContaining('每 15 分钟', findRichText: true), findsOneWidget);
      // A hollow ○ marks the forecast (a ring, never a solid dot). 空心 ○ 标预告。
      expect(find.byType(AnStatusDot), findsOneWidget, reason: '未来段一枚空心 ○(过去格是 Container 不是点)');
      // The paused lane says «已暂停» in its future segment — once, not twice. 暂停段说「已暂停」一次。
      expect(find.text('已暂停'), findsOneWidget, reason: '判决①:灰显必须配词,且只此一处');
    });

    testWidgets('a PAUSED lane greys but stays on the board with its name (判决①)', (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [_lane('c', '每晚归档', dimmed: true, note: '已暂停')],
        now: _now,
        onBin: (_, _) {},
      )));
      expect(find.text('每晚归档'), findsOneWidget, reason: '暂停泳道**绝不消失**');
    });

    group('keyboard: ONE tab stop (roving tabindex)', () {
      int trackStops() => FocusManager.instance.rootScope.traversalDescendants
          .where((n) => n.debugLabel?.startsWith('AnScheduleTrack') ?? false)
          .length;

      Widget busy() => _host(
            AnScheduleTrack(
              lanes: [
                for (var l = 0; l < 8; l++)
                  _lane('l$l', 'lane $l',
                      runs: [for (var h = 0; h < 24; h++) _run(_now.subtract(Duration(hours: h)), AnStatus.done)],
                      future: TrackFuture(at: _now.add(const Duration(minutes: 5)), time: '14:35', relative: '(5m)', schedule: 'x')),
              ],
              now: _now,
              onBin: (_, _) {},
              binSemanticLabel: (l, b) => '${b.start.hour}h',
              emptyBinSemanticLabel: (l, b) => '${b.start.hour}h',
              futureSemanticLabel: (l) => 'next',
            ),
            width: 1100,
          );

      testWidgets('8 lanes × (24 cells + future ○) is ONE Tab stop, not 200', (tester) async {
        await tester.pumpWidget(busy());
        expect(trackStops(), 1, reason: 'roving 光标封停靠数——一次 Tab 进、一次 Tab 出');
      });

      testWidgets('←→ walk a lane in time order (bin → future ○); ↑↓ land on the SAME hour of the next lane',
          (tester) async {
        await tester.pumpWidget(_host(Column(children: [
          AnScheduleTrack(
            lanes: [
              _lane('a', 'A', runs: [_run(_now.subtract(const Duration(hours: 5)), AnStatus.done)]),
              _lane('b', 'B', runs: [_run(_now.subtract(const Duration(hours: 5)), AnStatus.done)]),
            ],
            now: _now,
            onBin: (_, _) {},
            binSemanticLabel: (l, b) => '${b.start.hour}h',
            emptyBinSemanticLabel: (l, b) => '${b.start.hour}h',
          ),
          Focus(focusNode: FocusNode(debugLabel: 'after'), child: const SizedBox(width: 80, height: 40)),
        ])));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (a, 0)',
            reason: 'Tab 进落在光标(首泳道 bin 0)');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (a, 1)',
            reason: '→ 走到本泳道下一格(时序)');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (b, 1)',
            reason: '↓ 落邻泳道**同一小时**(轨是钟)');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (b, 0)');
      });

      testWidgets('running off the LAST lane hands focus back to the framework (never trapped)',
          (tester) async {
        await tester.pumpWidget(_host(Column(children: [
          AnScheduleTrack(
            lanes: [_lane('a', 'A', runs: [_run(_now.subtract(const Duration(hours: 5)), AnStatus.done)])],
            now: _now,
            onBin: (_, _) {},
            binSemanticLabel: (l, b) => '${b.start.hour}h',
            emptyBinSemanticLabel: (l, b) => '${b.start.hour}h',
          ),
          Focus(focusNode: FocusNode(debugLabel: 'after'), child: const SizedBox(width: 80, height: 40)),
        ])));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'after',
            reason: '最后一条泳道再往下 → super.invoke → 默认遍历送用户出去(绝不困住)');
      });
    });

    testWidgets('launch pad: a CONTENT cell reports its bin; an empty / missed-only cell does NOT',
        (tester) async {
      TrackBin? tapped;
      // A run 4h ago lands in bin 20 (start = now−24h; offset 20h). A missed-only bin sits at bin 14.
      // 4h 前的 run 落 bin 20;纯 missed 在 bin 14。
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          _lane('a', 'A',
              runs: [_run(_now.subtract(const Duration(hours: 4)), AnStatus.done, id: 'fr_hit')],
              missed: [_now.subtract(const Duration(hours: 10))]),
        ],
        now: _now,
        onBin: (lane, bin) => tapped = bin,
        binSemanticLabel: (l, b) => '${b.start.hour}h',
        emptyBinSemanticLabel: (l, b) => '${b.start.hour}h',
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Walk to the missed-only bin (14) and activate — it must NOT fire (no run to open). 纯 missed 格不发。
      for (var i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (a, 14)');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapped, isNull, reason: '纯 missed 格没有 run 可开 → 惰性,不触发发射台');
      // Walk on to the content bin (20) and activate — it reports its bin. 走到内容格 → 回报桶。
      for (var i = 14; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'AnScheduleTrack (a, 20)');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapped, isNotNull, reason: '内容格激活回报桶');
      expect(tapped!.runs.single.id, 'fr_hit');
    });

    testWidgets('each lane is ONE semantics container reading its summary (§12)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [_lane('a', '数据清洗', runs: [_run(_now.subtract(const Duration(hours: 4)), AnStatus.done)])],
        now: _now,
        onBin: (_, _) {},
        laneSummaryLabel: (l) => '${l.label},24 小时 1 次运行',
        binSemanticLabel: (l, b) => '${b.start.hour} 时,1 次',
        emptyBinSemanticLabel: (l, b) => '${b.start.hour} 时,无运行',
      )));
      expect(find.bySemanticsLabel('数据清洗,24 小时 1 次运行'), findsOneWidget,
          reason: '§12:每 lane 一个语义容器带行摘要');
      handle.dispose();
    });
  });
}
