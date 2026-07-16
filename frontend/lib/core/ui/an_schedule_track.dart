import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import '../model/time_format.dart';
import 'an_focus_ring.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'an_tooltip.dart';
import 'icons.dart';
import 'tone.dart';

/// AnScheduleTrack (WRK-069 §12, S5) — the ABSOLUTE-TIME track: one horizontal axis, a «now» line, and
/// a swim [lane] per schedule (a trigger, a workflow), each carrying discrete [TrackEvent] dots. It
/// answers one question the rest of the board cannot: **what is about to happen, and did the recent
/// scheduled things actually run.**
///
/// Three event faces, and the difference between them is the whole point (each carries a SHAPE channel
/// beside its colour — WCAG 1.4.1, colour never speaks alone):
///   • [TrackEventKind.past]   — a SOLID dot in its run's status colour: it happened, here is how it went.
///   • [TrackEventKind.future] — a HOLLOW ring, and the caller's word for it says «预计»: a promise, not
///     a fact. It must never be able to read as measured history.
///   • [TrackEventKind.missed] — a grey ✕: the tick came due while the machine slept and was booked
///     WITHOUT a catch-up run (工单⑨). A desktop app oversleeping is its first reality, not a failure —
///     hence grey, never red (WRK-069 状态学「未执行」桶: a disposition is bookkeeping, not an error).
///
/// **Architecture — hybrid, the [AnGraphCanvas] precedent**: the furniture (axis rule, now line, lane
/// baselines) is a [CustomPaint]底层 because it is inert; the EVENTS are real widgets, because a
/// CustomPainter paints pixels with no identity — its `semanticsBuilder` yields nodes that cannot be
/// focused (custom_paint.dart creates no [FocusNode] anywhere), so ←→ traversal would be physically
/// impossible under a pure painter. See design-system.md §2「CustomPainter 只配画没有身份的像素」.
///
/// ## Keyboard: ONE tab stop (roving tabindex), like [AnRunMatrix]
///
/// Folding bounds the dot count per lane by PIXELS (~28 on a full-bleed rail), but 8 lanes still
/// measured **227 Tab stops** — a keyboard user who tabs into the track needs ~200 more presses to
/// leave. So the track is one stop, by the same physics the matrix documents at length:
///   • every dot owns a [FocusNode] this widget owns outright, and exactly one — the cursor's — has
///     `skipTraversal: false` (the flag that still allows EXPLICIT focus, which is what an arrow does;
///     `canRequestFocus: false` would forbid that too). Flutter leaves an externally-supplied node's
///     flags alone (`focus_scope.dart` writes them only `if (!widget._usingExternalFocus)`).
///   • arrows re-bind [DirectionalFocusIntent] to a [DirectionalFocusAction] subclass (the
///     `MenuAnchor` precedent) — never `onKeyEvent`, which would either bubble to [WidgetsApp]'s
///     default arrow→DirectionalFocusIntent bindings (focus jumps out mid-walk) or force us to
///     hand-roll every edge case.
///   • running off the edge calls `super.invoke(intent)` and the framework's own traversal walks the
///     user OUT. Nobody is trapped.
///   • ←→ walk a lane's dots in time order; **↑↓ land on the dot NEAREST IN TIME**, because a track is
///     a clock: the thing «above» 14:00 is the other lane's 14:00, not its third dot. An empty lane has
///     nothing to land on and is stepped over.
///
/// The cursor is addressed by (lane id, instant) — never an index — so a refresh that re-folds the
/// axis cannot slide it onto a different event.
///
/// **Screen reader**: unlike the matrix (a dense 480-cell field, where per-cell nodes are a wall and
/// the ROW summary is the answer), a lane's ~28 folded dots are each DISTINCT news — a run that
/// happened, a forecast, a tick that was missed — so every dot keeps its own node and its own sentence.
/// One [Semantics] container per lane, with `explicitChildNodes: true` — **load-bearing, not
/// decoration**: without it a labelled container ABSORBS its descendants' labels, the lane reads out
/// as one run-on string, and the dots stop being addressable nodes at all, which silently destroys the
/// ←→ walk this lane exists to host (caught by the semantics-tree dump, never by looking at it).
///
/// **Bucket folding** is what keeps both counts bounded: a `*/5` cron over 24h is 288 ticks that would
/// otherwise be sub-pixel confetti AND 288 focus stops. Events are folded per (pixel bucket, kind); a
/// folded dot carries [TrackEvent.count] and hovers the full list. Within one bucket the WORST status
/// wins (the same law as the run matrix's cell fold — a later green tick cannot erase an earlier
/// failure that really happened).
///
/// AnScheduleTrack 绝对时间轴:一条轴 + now 线 + 逐泳道离散事件点。三张脸各带**形状通道**(色永不独行):
/// 过去=实心着状态色 / 未来=空心环 + 调用方的「预计」词(是承诺不是事实,绝不能读成实测史) / missed=灰 ✕
/// (睡过头的刻度醒来记账不补跑;桌面 app 第一现实,非故障,故灰不红)。**架构=混合**(AnGraphCanvas 先例):
/// 家具(轴/now 线/泳道基线)走 CustomPaint 底层(惰性),**事件是真 widget**——painter 画的是**没有身份**的
/// 像素,它 semanticsBuilder 出的节点不可聚焦(custom_paint.dart 全文件不造任何 FocusNode),纯 painter 下
/// ←→ 遍历物理上做不到(见 design-system §2)。
///
/// **键盘=唯一一个 Tab 停靠**(roving tabindex,同 AnRunMatrix):折叠已按**像素**封住每泳道点数(全宽轨约 28),
/// 但 8 条泳道**实测仍有 227 个 Tab 停靠**——进去要再按 200 次才出得来。故:每点的 FocusNode 由本件自持,
/// **恰好一个**(光标那个)skipTraversal:false(该旗标仍允许**显式**聚焦=方向键做的事;canRequestFocus:false
/// 会连显式聚焦一起禁掉);外供节点的旗标框架不碰。**方向键覆盖 Intent 不抢键**(MenuAnchor 先例),用
/// onKeyEvent 收裸方向键会冒泡到 WidgetsApp 默认绑定、焦点半途跳出。**越界 `super.invoke` 交还框架**,永不
/// 困住。←→ 按时序走本泳道的点;**↑↓ 落在时间上最近的点**——轨是钟,14:00 的「上面」是另一条泳道的 14:00,
/// 不是它的第三个点;空泳道无处可落,跨过。光标用 (泳道 id, 时刻) 定址、绝不用下标——重折叠不得让它滑到
/// 另一个事件上。
///
/// **读屏**:与格阵(480 格的稠密场,逐格节点是一堵墙、答案在**行摘要**)不同,一条泳道的约 28 个折叠点**各是
/// 一条独立的新闻**(跑过的 run / 预告 / 错过的刻度),故每点保留自己的节点与句子。每泳道一个 Semantics 容器 +
/// `explicitChildNodes: true`——**承重的、非装饰**:没有它,带 label 的容器会**吸收**后代 label、泳道读成
/// 一长串,而点根本不再是可寻址节点=本泳道存在的意义(←→ 遍历)被静默摧毁(靠语义树 dump 抓到,肉眼看不出)。
///
/// **bucket 聚合**同时封住 widget 数与焦点停靠数(*/5 的 cron 一天 288 个刻度=亚像素纸屑 + 288 个焦点停靠);
/// 折叠按 (像素桶, kind),折叠点带 count、hover 出全清单;同桶取**最坏**状态(同矩阵格聚合律:后来的绿刻抹
/// 不掉真发生过的失败)。
enum TrackEventKind {
  /// It already happened — solid, status-coloured. 已发生:实心着状态色。
  past,

  /// It is scheduled — hollow, spoken as a forecast. 已排程:空心,措辞为预告。
  future,

  /// It came due while the app slept; booked, never caught up (工单⑨). 睡过头的刻度:记账不补跑。
  missed,
}

/// One dot on a lane. [status] colours only a [TrackEventKind.past] dot (a forecast has no outcome to
/// wear, and a missed tick's outcome IS «it did not run»). [label] is the caller's already-localized
/// word for what this is (core holds no copy). [count] > 1 means this dot STANDS FOR that many folded
/// events — it is never a lie about one event, it is an honest aggregate.
/// 泳道上的一个点。status 只给过去的点着色(预告没有结局可穿,missed 的结局就是「没跑」);label=调用方
/// 已本地化的词(core 不含文案);count>1=此点**代表**这么多折叠事件(不是对单个事件撒谎,是诚实聚合)。
class TrackEvent {
  const TrackEvent({
    required this.at,
    required this.kind,
    this.status,
    this.label = '',
    this.id = '',
    this.count = 1,
  });

  final DateTime at;
  final TrackEventKind kind;

  /// The run outcome a PAST dot wears; ignored on the other two faces. 过去点穿的结局;另两脸忽略。
  final AnStatus? status;

  final String label;
  final String id;

  /// How many events this dot stands for after bucket folding (≥1). 折叠后此点代表几个事件(≥1)。
  final int count;
}

/// One swim lane = one schedule. [dimmed] is the PAUSED face (判决①): a paused trigger's lane greys
/// but **never disappears** — a stop-the-bleeding switch the user threw must stay visible, and a lane
/// that vanished would read as «no such schedule» instead of «you paused this». Its [note] carries the
/// caller's «已暂停» word. A dimmed lane legitimately holds zero future events (the backend refuses to
/// stamp a next-fire on a paused trigger — see [TriggerSchedule]).
/// 一泳道=一条排程。dimmed=**暂停脸**(判决①):暂停的 trigger 泳道**灰显但绝不消失**——用户扳下的止血阀
/// 必须看得见,泳道消失会被读成「没有这条排程」而非「你暂停了它」;note 带调用方的「已暂停」词。灰泳道
/// 合法地零未来事件(后端拒绝给暂停的 trigger 盖下次时间戳)。
class TrackLane {
  const TrackLane({
    required this.id,
    required this.label,
    required this.events,
    this.dimmed = false,
    this.note = '',
  });

  final String id;
  final String label;
  final List<TrackEvent> events;
  final bool dimmed;
  final String note;
}

class AnScheduleTrack extends StatefulWidget {
  const AnScheduleTrack({
    required this.lanes,
    required this.now,
    this.window = const Duration(hours: 24),
    this.pastWindow = Duration.zero,
    this.onTap,
    this.eventSemanticLabel,
    this.foldedLabel,
    super.key,
  });

  final List<TrackLane> lanes;

  /// The «now» instant — the axis anchor and the line's position. now 时刻:轴锚点与线位。
  final DateTime now;

  /// How far FORWARD the axis reaches from [now]. 轴自 now 向前伸多远。
  final Duration window;

  /// How far BACK the axis reaches from [now]. Zero (the default) puts the now line at the left edge —
  /// an honest «this track starts at now» for a caller with no history to show. Callers WITH past
  /// events pass a span, and the line moves right by pastWindow/(pastWindow+window).
  /// 轴自 now 向后伸多远。0(默认)把 now 线放在最左——对没有历史可给的调用方,这是诚实的「本轨自 now 起」;
  /// 有过去事件的调用方传一个跨度,线便右移 pastWindow/(pastWindow+window)。
  final Duration pastWindow;

  final void Function(TrackEvent)? onTap;

  /// Builds one dot's screen-reader sentence — «{lane} {time} {status}» (§12). Core owns no copy, so
  /// the caller renders it; absent → the dot falls back to its own [TrackEvent.label].
  /// 逐点读屏句「{泳道} {时刻} {状态}」;core 不含文案故由调用方渲;缺省时点回落自己的 label。
  final String Function(TrackLane lane, TrackEvent event)? eventSemanticLabel;

  /// The word for a folded dot's count («+N 个»). 折叠点的计数词。
  final String Function(int count)? foldedLabel;

  @override
  State<AnScheduleTrack> createState() => _AnScheduleTrackState();
}

/// The roving cursor's address: which lane, and WHICH INSTANT on it — never an index, so a re-fold
/// (the axis is width-dependent) cannot slide the cursor onto a different event.
/// 光标地址:哪条泳道 + 哪个**时刻**;绝不用下标——重折叠(轴随宽度变)不得让光标滑到另一个事件上。
typedef _TrackCursor = (String laneId, DateTime at);

class _AnScheduleTrackState extends State<AnScheduleTrack> {
  _TrackCursor? _cursor;
  final Map<_TrackCursor, FocusNode> _nodes = {};

  /// The folded dots per lane, parallel to [AnScheduleTrack.lanes]. The fold is width-dependent (that
  /// IS the pixel-bucket law), so it is computed inside the layout and memoized here — which makes the
  /// keyboard model and the rendered dots read from ONE list. A cursor that disagreed with what is on
  /// screen would be a bug factory.
  /// 逐泳道的折叠点(与 lanes 平行)。折叠依赖宽度(像素桶律本体),故在布局内算出、在此记忆化——让**键盘模型
  /// 与渲染出的点读同一份清单**。光标与屏上所见不一致会是一座 bug 工厂。
  List<List<PlacedEvent>> _folded = const [];

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AnScheduleTrack old) {
    super.didUpdateWidget(old);
    if (old.lanes != widget.lanes) {
      // A folded dot always stands on one of its lane's real instants, so the raw events bound the
      // live key set — no need for the (width-dependent) fold to prune.
      // 折叠点总是站在它那条泳道某个**真实**时刻上,故原始事件即可界定活键集——剪枝不需要(依赖宽度的)折叠。
      final live = <_TrackCursor>{
        for (final l in widget.lanes)
          for (final e in l.events) (l.id, e.at),
      };
      _nodes.removeWhere((k, n) {
        if (live.contains(k)) return false;
        n.dispose();
        return true;
      });
    }
  }

  Duration get _span => widget.pastWindow + widget.window;

  /// Where the cursor IS, as (lane index, dot index) — derived from the memoized fold, never stored:
  /// an event that left the axis must not leave a ghost behind.
  /// 光标**当前**在哪(泳道下标, 点下标):自记忆化的折叠派生、绝不存旧——离场的事件不得留下幽灵。
  (int, int)? get _resolved {
    if (_folded.length != widget.lanes.length) return null;
    final cur = _cursor;
    if (cur != null) {
      final li = widget.lanes.indexWhere((l) => l.id == cur.$1);
      if (li >= 0) {
        final di = _folded[li].indexWhere((p) => p.event.at == cur.$2);
        if (di >= 0) return (li, di);
      }
    }
    for (var l = 0; l < _folded.length; l++) {
      if (_folded[l].isNotEmpty) return (l, 0);
    }
    return null;
  }

  FocusNode _nodeFor(_TrackCursor key, {required bool cursor}) {
    final n = _nodes.putIfAbsent(key, () => FocusNode(debugLabel: 'AnScheduleTrack $key'));
    n.skipTraversal = !cursor;
    return n;
  }

  void _cursorTo(_TrackCursor key) {
    if (_cursor == key) return;
    setState(() => _cursor = key);
  }

  bool _move(TraversalDirection dir) {
    final at = _resolved;
    if (at == null) return false;
    final (li, di) = at;
    switch (dir) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        // Visual, not ordinal (APG) — and a Row mirrors under RTL. 视觉方向(APG);RTL 下 Row 会镜像。
        final step = (dir == TraversalDirection.right ? 1 : -1) *
            (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
        final next = di + step;
        if (next < 0 || next >= _folded[li].length) return false;
        _focus(li, next);
        return true;
      case TraversalDirection.up:
      case TraversalDirection.down:
        final step = dir == TraversalDirection.down ? 1 : -1;
        final t = _folded[li][di].event.at;
        for (var l = li + step; l >= 0 && l < _folded.length; l += step) {
          final dots = _folded[l];
          if (dots.isEmpty) continue; // nothing to land on — step over 无处可落,跨过
          // A track is a CLOCK: what sits «above» 14:00 is the other lane's 14:00, not its third dot.
          // 轨是**钟**:14:00 的「上面」是另一条泳道的 14:00,不是它的第三个点。
          var best = 0;
          for (var i = 1; i < dots.length; i++) {
            if (dots[i].event.at.difference(t).abs() < dots[best].event.at.difference(t).abs()) {
              best = i;
            }
          }
          _focus(l, best);
          return true;
        }
        return false;
    }
  }

  void _focus(int li, int di) {
    final lane = widget.lanes[li];
    final event = _folded[li][di].event;
    final key = (lane.id, event.at);
    setState(() => _cursor = key);
    // Explicit focus — the very thing skipTraversal keeps legal. The focused node carries the dot's
    // sentence, which is what a screen reader reads on Windows/Linux.
    // 显式聚焦——skipTraversal 保留的正是这一手;被聚焦的节点带着点的句子,Windows/Linux 读屏读的就是它。
    _nodeFor(key, cursor: true).requestFocus();
    // macOS only, and not a preference: its engine bridge drops FOCUS_CHANGED into the «not
    // meaningful on Mac» skip group, so a focused node is SILENT there — while Windows/Linux DO fire
    // it and a second channel would double-read (flutter#153020). `liveRegion` is not the fallback:
    // no-op on all three desktops (flutter#167318, open). Same law as [AnRunMatrix]'s `_announce`.
    // 只在 macOS,且不是偏好:mac bridge 把 FOCUS_CHANGED 归进「在 Mac 上没意义」的跳过组,被聚焦的节点
    // 在那里是**哑的**;Windows/Linux 会发焦点通知,再加一发会双读(flutter#153020)。liveRegion 不是退路
    // ——三个桌面全是 no-op(flutter#167318 至今 OPEN)。同 AnRunMatrix 的 _announce 一律。
    final sentence = widget.eventSemanticLabel?.call(lane, event) ?? event.label;
    if (sentence.isEmpty || defaultTargetPlatform != TargetPlatform.macOS) return;
    SemanticsService.sendAnnouncement(View.of(context), sentence, Directionality.of(context));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lanes.isEmpty) return const SizedBox.shrink();
    final spanMs = _span.inMilliseconds;
    // A zero/negative axis can place nothing — refuse to draw a scale rather than divide by it.
    // 零/负跨度的轴放不下任何东西——拒绝画一把没有意义的尺,而不是拿它做除数。
    if (spanMs <= 0) return const SizedBox.shrink();
    final start = widget.now.subtract(widget.pastWindow);
    final nowAt = widget.pastWindow.inMilliseconds / spanMs;
    // Reset the memo to the current shape BEFORE layout refills it: a stale slot from a previous
    // lane list must never be read as this one's.
    // 布局回填**之前**先把记忆化重置成当前形状:上一份 lane 清单的残留槽绝不能被当成这一份的。
    _folded = [for (var i = 0; i < widget.lanes.length; i++) const <PlacedEvent>[]];

    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _TrackDirectionalFocusAction(this),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ruler(context, start),
          for (var i = 0; i < widget.lanes.length; i++) _lane(context, i, start, spanMs, nowAt),
        ],
      ),
    );
  }

  /// The scale eyebrow — start / span / end, three honest anchors (the [AnNodeGantt] ruler law: no
  /// evenly-divided fake ticks on an axis whose labels would collide).
  ///
  /// Stamps are DATE+TIME, not [fmtClock]'s wall clock: this axis spans hours-to-days (a 24h window
  /// starting at 12:00 ENDS at 12:00), so a clock would print the identical string at both ends and
  /// the ruler would silently say the axis goes nowhere. (The gantt's axis is seconds-wide, which is
  /// why the opposite choice is right THERE — the grain follows the span, and neither is a default.)
  /// 刻度眉三锚点。戳走**日期+时刻**而非 fmtClock 的墙钟:本轴跨度是小时到天(12:00 起的 24h 窗**终于**
  /// 12:00),用钟点会让两端印出同一个字符串、刻度眉静默宣称这条轴哪也没去。(甘特的轴是秒级跨度,故那边
  /// 的相反选择才对——**粒度随跨度走**,两者都不是默认。)
  Widget _ruler(BuildContext context, DateTime start) {
    final c = context.colors;
    final style = AnText.metaTabular().copyWith(color: c.inkFaint);
    return Padding(
      padding: const EdgeInsets.only(
          left: AnSize.ganttLaneW + AnSpace.s12, right: AnSpace.s8, bottom: AnSpace.s4),
      // Flexible stamps: a full date+time is ~110px and there are two of them, so a narrow host (a
      // gallery cell, a squeezed ocean) would overflow a rigid Row by more than the gutter is wide.
      // They ellipsize instead — the span in the middle still carries the axis's length, so the
      // eyebrow degrades rather than breaks. 可伸缩的戳:日期+时刻各约 110px、共两个,窄宿主(画廊格、
      // 被挤窄的海洋)下刚性 Row 会溢出;改为裁切——中间的跨度仍带着轴长,故刻度眉是**降级**而非破裂。
      child: Row(children: [
        Flexible(
            child:
                Text(fmtDateTime(start), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(child: Center(child: Text(fmtWaited(widget.window), maxLines: 1, style: style))),
        Flexible(
            child: Text(fmtDateTime(widget.now.add(widget.window)),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }

  Widget _lane(BuildContext context, int li, DateTime start, int spanMs, double nowAt) {
    final c = context.colors;
    final lane = widget.lanes[li];
    // ONE semantics container per lane (§12): the reader hears the lane, then walks its dots.
    // `explicitChildNodes` is LOAD-BEARING, not decoration: without it a labelled container ABSORBS
    // its descendants' labels, and the lane node comes out reading «数据清洗 / 数据清洗 / 数据清洗
    // 14:00 预计» as one run-on string while the dots stop being addressable nodes at all — which
    // would silently destroy the ←→ walk this lane exists to host (caught by the semantics-tree dump,
    // not by looking at it).
    // 每泳道一个语义容器(§12):先听见泳道,再遍历它的点。**explicitChildNodes 是承重的、非装饰**——没有它,
    // 带 label 的容器会**吸收**后代的 label,泳道节点读成「数据清洗/数据清洗/数据清洗 14:00 预计」一长串,
    // 而点根本不再是可寻址节点=本泳道存在的意义(←→ 遍历)被静默摧毁(靠语义树 dump 抓到,肉眼看不出)。
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: lane.note.isEmpty ? lane.label : '${lane.label} · ${lane.note}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        child: SizedBox(
          height: AnSize.row,
          child: Row(children: [
            SizedBox(
              width: AnSize.ganttLaneW - AnSpace.s8,
              child: Row(children: [
                Flexible(
                  child: Text(
                    lane.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: lane.dimmed ? c.inkFaint : c.inkMuted),
                  ),
                ),
                // The paused word rides IN the lane, never replaces it (判决①). 暂停词随泳道,不取代它。
                if (lane.note.isNotEmpty) ...[
                  const SizedBox(width: AnSpace.s6),
                  Text(lane.note,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AnText.meta.copyWith(color: c.inkFaint)),
                ],
              ]),
            ),
            const SizedBox(width: AnSpace.s12),
            Expanded(child: _rail(context, li, start, spanMs, nowAt)),
          ]),
        ),
      ),
    );
  }

  Widget _rail(BuildContext context, int li, DateTime start, int spanMs, double nowAt) {
    final lane = widget.lanes[li];
    return LayoutBuilder(builder: (context, cst) {
      final w = cst.maxWidth;
      if (w <= 0) return const SizedBox.shrink();
      final dots = foldEvents(lane.events, start: start, spanMs: spanMs, trackWidth: w);
      // The memo the keyboard model reads (see [_folded]). 键盘模型读的那份记忆化(见 _folded)。
      if (li < _folded.length) _folded[li] = dots;
      final at = _resolved;
      return Stack(clipBehavior: Clip.none, children: [
        // Furniture BELOW the dots and inert — a painter draws the baseline + now line, and takes no
        // hit test (IgnorePointer), so it can never steal a dot's click. 家具在点之下且惰性:painter 画
        // 基线与 now 线、不吃命中(IgnorePointer),绝不抢点的点击。
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TrackFurniture(
                line: context.colors.line,
                nowColor: context.colors.accent,
                nowAt: nowAt,
              ),
            ),
          ),
        ),
        for (var di = 0; di < dots.length; di++)
          Positioned(
            left: (dots[di].at * w).clamp(0.0, w) - AnSize.controlSm / 2,
            top: 0,
            bottom: 0,
            width: AnSize.controlSm,
            child: _Dot(
              lane: lane,
              event: dots[di].event,
              onTap: widget.onTap == null
                  ? null
                  : (e) {
                      _cursorTo((lane.id, e.at));
                      widget.onTap!(e);
                    },
              semanticLabel: widget.eventSemanticLabel?.call(lane, dots[di].event),
              foldedLabel: widget.foldedLabel,
              focusNode: widget.onTap == null
                  ? null
                  : _nodeFor((lane.id, dots[di].event.at), cursor: at == (li, di)),
            ),
          ),
      ]);
    });
  }
}

/// Arrows move the CURSOR along the track, and hand back to the framework at the edge — the
/// `MenuAnchor` precedent. 方向键在轨内挪光标,到边即交还框架——MenuAnchor 同款先例。
class _TrackDirectionalFocusAction extends DirectionalFocusAction {
  _TrackDirectionalFocusAction(this.state);

  final _AnScheduleTrackState state;

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (state._move(intent.direction)) return;
    super.invoke(intent);
  }
}

/// A placed dot — its axis fraction plus the (possibly folded) event it stands for. 已定位的点。
class PlacedEvent {
  const PlacedEvent(this.at, this.event);
  final double at;
  final TrackEvent event;
}

/// Fold [events] onto a [trackWidth]-wide axis: drop what falls outside, bucket by pixel × kind, and
/// collapse each bucket to ONE dot carrying the bucket's count. Pure — unit-tested without a pump.
///
/// Why (bucket, kind) and not just bucket: the three faces answer different questions, and a bucket
/// that held both a missed tick and a completed run must not silently pick one — at most three dots
/// can share a bucket (a rare, honest crowd) instead of one dot that lies about the other two.
/// Within a kind the WORST status wins and the EARLIEST instant anchors the dot (a bucket is a span;
/// its left edge is the honest place to stand).
///
/// 把事件折到 trackWidth 宽的轴上:轴外的丢弃,按 (像素桶 × kind) 聚合,每桶收成一个带计数的点。纯函数。
/// **为何按 (桶,kind) 而非只按桶**:三张脸回答的是不同的问题,一个同时装着 missed 刻度与 completed run
/// 的桶绝不能静默挑一个——至多三点共享一桶(罕见且诚实的拥挤),好过一个点对另两个撒谎。同 kind 内取
/// **最坏**状态、以**最早**时刻定锚(桶是一段跨度,它的左缘是诚实的站位)。
List<PlacedEvent> foldEvents(
  List<TrackEvent> events, {
  required DateTime start,
  required int spanMs,
  required double trackWidth,
  double bucketPx = AnSize.controlSm,
}) {
  if (spanMs <= 0 || trackWidth <= 0) return const [];
  final buckets = <String, List<TrackEvent>>{};
  for (final e in events) {
    final offMs = e.at.difference(start).inMilliseconds;
    if (offMs < 0 || offMs > spanMs) continue; // outside the axis — unplaceable, so unshown 轴外不渲
    final at = offMs / spanMs;
    final bucket = (at * trackWidth / bucketPx).floor();
    (buckets['${e.kind.name}/$bucket'] ??= []).add(e);
  }
  final out = <PlacedEvent>[];
  for (final group in buckets.values) {
    group.sort((a, b) => a.at.compareTo(b.at));
    final first = group.first;
    final count = group.fold<int>(0, (n, e) => n + e.count);
    final status = group.length == 1
        ? first.status
        : group.map((e) => e.status).fold<AnStatus?>(null, _worst);
    final offMs = first.at.difference(start).inMilliseconds;
    out.add(PlacedEvent(
      offMs / spanMs,
      TrackEvent(
        at: first.at,
        kind: first.kind,
        status: status,
        label: first.label,
        id: first.id,
        count: count,
      ),
    ));
  }
  // Time order IS reading order — and it is also what the semantics tree walks, since the dots are
  // Positioned siblings whose default order the framework derives from their rects (verified by the
  // semantics dump). No sortKey: an OrdinalSortKey's `name` is a BUCKET sorted lexicographically
  // before its order, so naming lanes would sort «lane10» before «lane2».
  // 时序即读序——也是语义树走的序:点是 Positioned 兄弟,框架按其 rect 推默认序(语义树 dump 已验)。
  // 不加 sortKey:OrdinalSortKey 的 name 是**分桶**、按字典序排在 order 之前,给泳道命名会让 lane10 排在
  // lane2 前面。
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Worst-disposition fold (err > wait > run > done > idle) — the run matrix's cell law, verbatim: a
/// later success cannot erase an earlier failure that really happened.
/// 最坏处置折叠(同矩阵格律,逐字):后来的成功抹不掉真发生过的失败。
AnStatus? _worst(AnStatus? a, AnStatus? b) {
  if (a == null) return b;
  if (b == null) return a;
  const rank = {
    AnStatus.err: 4,
    AnStatus.wait: 3,
    AnStatus.run: 2,
    AnStatus.done: 1,
    AnStatus.idle: 0,
  };
  return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
}

/// The inert furniture: a hairline lane baseline + the «now» rule. Inert = zero semantics, zero hit
/// test — the dots own both. 惰性家具:发丝基线 + now 线;零语义零命中(那两样归点)。
class _TrackFurniture extends CustomPainter {
  const _TrackFurniture({required this.line, required this.nowColor, required this.nowAt});

  final Color line;
  final Color nowColor;
  final double nowAt;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, y - AnSize.hairline / 2, size.width, AnSize.hairline),
      Paint()..color = line,
    );
    final x = (nowAt * size.width).clamp(0.0, size.width - AnSize.hairline);
    canvas.drawRect(
      Rect.fromLTWH(x, 0, AnSize.hairline, size.height),
      Paint()..color = nowColor,
    );
  }

  @override
  bool shouldRepaint(_TrackFurniture old) =>
      old.line != line || old.nowColor != nowColor || old.nowAt != nowAt;
}

/// One event dot — a real focus node (so the framework's directional traversal gives ←→ for free) with
/// its own screen-reader sentence and a hover list. 一个事件点:真焦点节点(←→ 由框架方向性遍历白送),
/// 自带读屏句与 hover 清单。
class _Dot extends StatelessWidget {
  const _Dot({
    required this.lane,
    required this.event,
    this.onTap,
    this.semanticLabel,
    this.foldedLabel,
    this.focusNode,
  });

  final TrackLane lane;
  final TrackEvent event;
  final void Function(TrackEvent)? onTap;
  final String? semanticLabel;
  final String Function(int count)? foldedLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tap = onTap;
    final folded = event.count > 1 && foldedLabel != null ? foldedLabel!(event.count) : '';
    final tip = [
      if (event.label.isNotEmpty) event.label,
      '${fmtDateTime(event.at)}${folded.isEmpty ? '' : ' · $folded'}',
    ].join('\n');

    Widget mark = switch (event.kind) {
      // Solid, in its outcome's colour. Never defaults to done: an unknown status folds to idle
      // (neutral) — a dot must not be able to claim a success it never had.
      // 实心着结局色;绝不默认 done——未知状态折 idle 中性,点不得声称它没有过的成功。
      TrackEventKind.past =>
        AnStatusDot.raw((event.status ?? AnStatus.idle).tone.fg(c), size: AnSize.dot),
      // Hollow ring = a forecast. The «预计» wording lives in the caller's label/tooltip.
      // 空心环=预告;「预计」措辞在调用方的 label/tooltip 里。
      TrackEventKind.future =>
        AnStatusDot.raw(lane.dimmed ? c.inkFaint : c.inkMuted, hollow: true, size: AnSize.dot),
      // A grey ✕ — a SHAPE, not just a colour (WCAG 1.4.1), and grey because a missed tick is
      // bookkeeping, not an error. 灰 ✕:靠**形状**而非只靠色(WCAG 1.4.1);灰,因为错过是记账不是故障。
      TrackEventKind.missed => Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkFaint),
    };
    if (lane.dimmed && event.kind == TrackEventKind.past) {
      mark = Opacity(opacity: AnOpacity.stratum, child: mark);
    }

    final dot = Semantics(
      label: semanticLabel ?? event.label,
      child: ExcludeSemantics(
        child: Center(
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            mark,
            // The fold badge rides ABOVE the dot so the dot's own position stays exact — the count is
            // metadata about the dot, never a nudge to where it stands.
            // 计数徽在点**之上**,点位保持精确——计数是关于点的元数据,绝不挪动它的站位。
            if (event.count > 1)
              Positioned(
                bottom: AnSize.dot,
                child: Text('${event.count}',
                    style: AnText.metaTabular().copyWith(color: c.inkFaint)),
              ),
          ]),
        ),
      ),
    );

    final body = tap == null
        ? dot
        : AnInteractive(
            onTap: () => tap(event),
            focusNode: focusNode,
            builder: (context, states) => AnFocusRing(
              active: states.contains(WidgetState.focused),
              radius: AnRadius.tag,
              child: dot,
            ),
          );
    return tip.isEmpty ? body : AnTooltip(message: tip, child: body);
  }
}
