import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnScheduleTrack (WRK-069 §12, S5). Two layers: the PURE fold (no pump — the bucket engine is where
// «防爆» actually happens, and it must be provable without a widget tree) and the widget contract
// (three faces are distinguishable, a paused lane survives, every dot is focusable so ←→ works).
// 两层:纯折叠(免 pump——防爆真正发生在 bucket 引擎里,必须脱 widget 树可证)+ widget 契约(三脸可区分、
// 暂停泳道存活、每点可聚焦故 ←→ 成立)。

final _now = DateTime(2026, 7, 16, 12);

Widget _host(Widget child, {double width = 600}) => MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
    );

void main() {
  group('foldEvents (pure)', () {
    test('drops events outside the axis — an unplaceable event is never faked into place', () {
      final out = foldEvents(
        [
          TrackEvent(at: _now.add(const Duration(days: 30)), kind: TrackEventKind.future),
          TrackEvent(at: _now.subtract(const Duration(days: 30)), kind: TrackEventKind.past),
          TrackEvent(at: _now.add(const Duration(hours: 1)), kind: TrackEventKind.future),
        ],
        start: _now,
        spanMs: const Duration(hours: 24).inMilliseconds,
        trackWidth: 600,
      );
      expect(out.length, 1, reason: '轴外事件放不下就不渲,绝不硬塞进轴内假装放得下');
      expect(out.single.event.kind, TrackEventKind.future);
    });

    test('folds a */5 cron (288 ticks) into a bounded, counted set of dots', () {
      final out = foldEvents(
        [
          for (var i = 1; i <= 288; i++)
            TrackEvent(at: _now.add(Duration(minutes: i * 5)), kind: TrackEventKind.future),
        ],
        start: _now,
        spanMs: const Duration(hours: 24).inMilliseconds,
        trackWidth: 600,
      );
      // 600px / 24px bucket = buckets 0..24, plus bucket 25 for an event landing exactly on the
      // axis end (the right edge is closed) → 26 is the true ceiling. The point stands: the widget
      // count is bounded by PIXELS, not by data — 288 ticks cannot make 288 dots.
      // 600/24 → 桶 0..24,再加恰好落在轴末的事件占的第 25 桶(右缘闭合)=26 封顶。要害不变:widget 数由
      // **像素**封顶、不由数据封顶——288 个刻度变不出 288 个点。
      expect(out.length, lessThanOrEqualTo(26), reason: '288 刻度折成 ≤26 个点:防爆由像素桶保证');
      expect(out.fold<int>(0, (n, p) => n + p.event.count), 288,
          reason: '折叠不丢事件:计数总和必须仍是 288(聚合是诚实的,不是抽样)');
    });

    test('a bucket keeps its faces APART — missed and past never collapse into one dot', () {
      final at = _now.add(const Duration(hours: 1));
      final out = foldEvents(
        [
          TrackEvent(at: at, kind: TrackEventKind.past, status: AnStatus.done),
          TrackEvent(at: at, kind: TrackEventKind.missed),
        ],
        start: _now,
        spanMs: const Duration(hours: 24).inMilliseconds,
        trackWidth: 600,
      );
      expect(out.length, 2, reason: '同桶不同 kind 各出一点——一个点绝不替另两个 kind 撒谎');
      expect(out.map((p) => p.event.kind).toSet(),
          {TrackEventKind.past, TrackEventKind.missed});
    });

    test('within a kind the WORST status wins — a later green cannot erase a real failure', () {
      final base = _now.add(const Duration(hours: 1));
      final out = foldEvents(
        [
          TrackEvent(at: base, kind: TrackEventKind.past, status: AnStatus.done),
          TrackEvent(
              at: base.add(const Duration(seconds: 1)),
              kind: TrackEventKind.past,
              status: AnStatus.err),
          TrackEvent(
              at: base.add(const Duration(seconds: 2)),
              kind: TrackEventKind.past,
              status: AnStatus.done),
        ],
        start: _now,
        spanMs: const Duration(hours: 24).inMilliseconds,
        trackWidth: 600,
      );
      expect(out.length, 1);
      expect(out.single.event.status, AnStatus.err,
          reason: '同桶取最坏(同矩阵格律):后来的绿抹不掉真发生过的失败');
      expect(out.single.event.count, 3, reason: '折叠点如实报它代表几个事件');
    });

    test('a folded dot anchors on the EARLIEST instant in its bucket', () {
      final first = _now.add(const Duration(hours: 1));
      final out = foldEvents(
        [
          TrackEvent(at: first.add(const Duration(seconds: 30)), kind: TrackEventKind.future),
          TrackEvent(at: first, kind: TrackEventKind.future),
        ],
        start: _now,
        spanMs: const Duration(hours: 24).inMilliseconds,
        trackWidth: 600,
      );
      expect(out.single.event.at, first, reason: '桶是一段跨度,它的左缘(最早刻)是诚实的站位');
    });

    test('a zero/negative axis places nothing rather than dividing by it', () {
      expect(foldEvents([TrackEvent(at: _now, kind: TrackEventKind.future)],
              start: _now, spanMs: 0, trackWidth: 600),
          isEmpty);
      expect(foldEvents([TrackEvent(at: _now, kind: TrackEventKind.future)],
              start: _now, spanMs: 1000, trackWidth: 0),
          isEmpty);
    });
  });

  group('AnScheduleTrack (widget)', () {
    testWidgets('empty lanes render nothing — no ghost axis, no orphan ruler', (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(lanes: const [], now: _now)));
      expect(tester.getSize(find.byType(AnScheduleTrack)).height, 0,
          reason: '零泳道=零高:不留一条指着空无的轴,也不留孤零零的刻度眉');
    });

    testWidgets('a PAUSED lane greys but stays on the board with its word (判决①)', (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: const [TrackLane(id: 'c', label: '每晚归档', dimmed: true, note: '已暂停', events: [])],
        now: _now,
      )));
      expect(find.text('每晚归档'), findsOneWidget,
          reason: '判决①:暂停的泳道**绝不消失**——泳道没了会被读成「没有这条排程」而非「你暂停了它」');
      expect(find.text('已暂停'), findsOneWidget, reason: '灰显必须配词:色不独行');
    });

    testWidgets('the three faces are distinguishable — a missed tick wears a ✕ SHAPE, not just grey',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          TrackLane(id: 'a', label: 'A', events: [
            TrackEvent(
                at: _now.add(const Duration(hours: 2)),
                kind: TrackEventKind.past,
                status: AnStatus.done),
            TrackEvent(at: _now.add(const Duration(hours: 8)), kind: TrackEventKind.missed),
            TrackEvent(at: _now.add(const Duration(hours: 16)), kind: TrackEventKind.future),
          ]),
        ],
        now: _now,
        window: const Duration(hours: 24),
      )));
      // ✕ is a glyph — the shape channel (WCAG 1.4.1), so the face survives colour-blindness AND
      // greyscale. ✕ 是字形=形状通道:色盲与灰度下这张脸仍在。
      expect(find.byType(Icon), findsOneWidget, reason: 'missed 必须有 ✕ 形状,不能只靠灰色');
      // past + future are dots; the ✕ is not. 过去与未来是点,✕ 不是。
      expect(find.byType(AnStatusDot), findsNWidgets(2));
    });

    testWidgets('every dot is a real focus node — that is what makes ←→ traversal work', (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          TrackLane(id: 'a', label: 'A', events: [
            TrackEvent(at: _now.add(const Duration(hours: 4)), kind: TrackEventKind.future),
            TrackEvent(at: _now.add(const Duration(hours: 12)), kind: TrackEventKind.future),
          ]),
        ],
        now: _now,
        onTap: (_) {},
      )));
      // A dot must be a real widget with a real focus node: a CustomPainter paints pixels with no
      // identity — `semanticsBuilder` yields nodes that cannot be focused — so ←→ would be physically
      // impossible under a pure painter (design-system §7).
      // 点必须是带真焦点节点的真 widget:painter 画的是**没有身份**的像素,其 semanticsBuilder 出的节点不可
      // 聚焦,纯 painter 下 ←→ 物理上做不到(design-system §7)。
      expect(find.byType(AnInteractive), findsNWidgets(2));
      expect(find.byType(FocusableActionDetector), findsNWidgets(2));
    });

    group('keyboard: ONE tab stop (roving tabindex)', () {
      int trackStops() => FocusManager.instance.rootScope.traversalDescendants
          .where((n) => n.debugLabel?.startsWith('AnScheduleTrack') ?? false)
          .length;

      /// A `*/5` cron across several lanes — folding bounds the DOTS, but every dot was still its own
      /// Tab stop before the roving cursor (measured: 227 for 8 lanes).
      /// 多条泳道的 */5 cron:折叠封住了**点数**,但在 roving 光标之前每个点仍是一个 Tab 停靠(实测 8 泳道=227)。
      Widget busy() => _host(
            AnScheduleTrack(
              lanes: [
                for (var l = 0; l < 8; l++)
                  TrackLane(id: 'l$l', label: 'lane $l', events: [
                    for (var i = 1; i <= 288; i++)
                      TrackEvent(at: _now.add(Duration(minutes: i * 5)), kind: TrackEventKind.future),
                  ]),
              ],
              now: _now,
              onTap: (_) {},
            ),
            width: 1100,
          );

      testWidgets('8 lanes × 288 ticks is ONE Tab stop, not 227', (tester) async {
        await tester.pumpWidget(busy());
        expect(trackStops(), 1,
            reason: '折叠只封住点数;停靠数要靠 roving 光标封——一次 Tab 进、一次 Tab 出');
      });

      testWidgets('←→ walk the lane in time order; running off the edge hands focus back',
          (tester) async {
        await tester.pumpWidget(_host(Column(children: [
          AnScheduleTrack(
            lanes: [
              TrackLane(id: 'a', label: 'A', events: [
                TrackEvent(at: _now.add(const Duration(hours: 4)), kind: TrackEventKind.future),
                TrackEvent(at: _now.add(const Duration(hours: 12)), kind: TrackEventKind.future),
              ]),
            ],
            now: _now,
            onTap: (_) {},
          ),
          Focus(focusNode: FocusNode(debugLabel: 'after'), child: const SizedBox(width: 80, height: 40)),
        ])));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, contains('16:00'),
            reason: 'Tab 进来落在光标点(第一条泳道最早的点)');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, contains('2026-07-17 00:00'),
            reason: '→ 走到本泳道下一个点(时序)');
        // Off the axis's end we hand the intent BACK to the framework — and the framework's honest
        // answer to «→ with nothing to the right» is «focus stays», exactly as it is on any button.
        // Handing back is the contract; where focus lands is the framework's call, not ours. The
        // escape that matters is proved below, along the axis that HAS an exit.
        // 走出轴末即把 intent **交还**框架——而框架对「右边什么都没有」的诚实回答就是「焦点不动」,与任何按钮
        // 上一样。**交还**才是契约,落在哪由框架定、不由我们定;真正要紧的逃逸在下面那条**有出口**的轴上验。
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, contains('2026-07-17 00:00'),
            reason: '右边没有东西 → 框架说焦点不动;这是交还的结果,不是我们吞了这一下');
        // Down HAS somewhere to go — and that is the trap-free exit.
        // 向下**有**去处——那才是不困人的出口。
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'after',
            reason: '最后一条泳道再往下 → super.invoke → 默认遍历把用户送出轨道(MenuAnchor 同款);绝不困住');
      });

      testWidgets('↑↓ land on the dot NEAREST IN TIME, and step OVER an empty lane',
          (tester) async {
        await tester.pumpWidget(_host(AnScheduleTrack(
          lanes: [
            TrackLane(id: 'a', label: 'A', events: [
              TrackEvent(at: _now.add(const Duration(hours: 2)), kind: TrackEventKind.future),
              TrackEvent(at: _now.add(const Duration(hours: 20)), kind: TrackEventKind.future),
            ]),
            // A paused schedule legitimately holds no events — there is nothing to land on.
            // 暂停的排程合法地没有事件——无处可落。
            const TrackLane(id: 'b', label: 'B', dimmed: true, events: []),
            TrackLane(id: 'c', label: 'C', events: [
              TrackEvent(at: _now.add(const Duration(hours: 3)), kind: TrackEventKind.future),
              TrackEvent(at: _now.add(const Duration(hours: 19)), kind: TrackEventKind.future),
            ]),
          ],
          now: _now,
          onTap: (_) {},
        )));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(a, 2026-07-17 08:00'),
            reason: '光标在 A 的 20 小时后那个点');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        // A track is a CLOCK: ↓ from 08:00 must land on C's 07:00, not on C's first dot. And lane B
        // (empty) is stepped over rather than swallowing the press.
        // 轨是**钟**:从 08:00 往下必须落在 C 的 07:00,而不是 C 的第一个点;空泳道 B 被跨过,而不是把这一下吞掉。
        expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(c, 2026-07-17 07:00'),
            reason: '↓ 落在**时间上最近**的点(07:00),不是列表里的第一个(15:00);空泳道跨过');
      });
    });

    testWidgets('a dot reports itself on tap', (tester) async {
      TrackEvent? tapped;
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          TrackLane(id: 'a', label: 'A', events: [
            TrackEvent(at: _now.add(const Duration(hours: 4)), kind: TrackEventKind.future, id: 'e1'),
          ]),
        ],
        now: _now,
        onTap: (e) => tapped = e,
      )));
      await tester.tap(find.byType(AnInteractive));
      expect(tapped?.id, 'e1');
    });

    testWidgets('each lane is ONE semantics container reading its label + paused word (§12)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: [
          TrackLane(id: 'a', label: '数据清洗', events: [
            TrackEvent(
                at: _now.add(const Duration(hours: 4)),
                kind: TrackEventKind.future,
                label: '数据清洗'),
          ]),
          const TrackLane(id: 'c', label: '每晚归档', dimmed: true, note: '已暂停', events: []),
        ],
        now: _now,
        eventSemanticLabel: (lane, e) => '${lane.label} 14:00 预计',
      )));
      expect(find.bySemanticsLabel('数据清洗'), findsWidgets, reason: '§12:每 lane 一个语义节点');
      expect(find.bySemanticsLabel('每晚归档 · 已暂停'), findsOneWidget,
          reason: '读屏必须听得见「已暂停」——灰显是视觉,读屏用户看不见灰');
      expect(find.bySemanticsLabel('数据清洗 14:00 预计'), findsOneWidget,
          reason: '§12:事件读「{workflow} {time} {status}」');
      handle.dispose();
    });

    testWidgets('a lane with no events still renders its rail (an honest empty schedule)',
        (tester) async {
      await tester.pumpWidget(_host(AnScheduleTrack(
        lanes: const [TrackLane(id: 'a', label: 'A', events: [])],
        now: _now,
      )));
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(AnStatusDot), findsNothing, reason: '无事件不造点');
    });
  });
}
