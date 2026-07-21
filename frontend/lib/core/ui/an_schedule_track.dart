import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_a11y.dart';
import 'an_focus_ring.dart';
import 'an_scroll_behavior.dart';
import 'an_hover_card.dart';
import 'an_status_dot.dart';
import 'icons.dart';
import 'tone.dart';

/// AnScheduleTrack (WRK-069 §12 · WRK-070 调度轨重造 v2 0718「直接复用 Matrix View」) — the schedule
/// board's one row per schedule, in the RUN MATRIX's own visual grammar (one grid language per ocean):
///
///   • **PAST = Matrix-View cells in whole-hour bins**: every lane wears the same row of controlSm
///     squares (soft-tint fill + status-coloured hairline, the AnRunMatrix cell verbatim; an empty hour
///     is a faint-outlined square — «empty is a real answer»). WHOLE hours only (0718 v2「都弄整个小时
///     的」— no minute-offset window edges); the caller hands 25 bins (24 complete hours + the one in
///     progress, a superset of any rolling 24h KPI window, so the 「错过 N」 evidence stays complete). A
///     `missed` tick never enters the fill; it lays a grey ✕ INSIDE the cell (the matrix's «×N 在格内»
///     grammar; a SHAPE beside the colour, WCAG 1.4.1).
///     The grid SCROLLS SIDEWAYS inside itself, ANCHORED AT THE NEWEST EDGE with the lane names frozen
///     left and the forecast frozen right (the matrix's frozen-lane scroll grammar) — the v1 blue now
///     line and start/span/now ruler are retired: under the right anchor the trailing edge IS now, and
///     the column heads (sliding with the grid) name every hour themselves ([binHeadLabel]: «20», a
///     «7/19» date on the midnight anchor).
///   • **FUTURE = a fixed-width FROZEN segment, NOT a timeline** (Cronitor/Healthchecks next-run
///     one-liner): one hollow ring ○ + «HH:mm (relative word)» + the schedule's own words. A forecast
///     has no history to draw, so it says its next moment in a sentence rather than pretending to a
///     position. A paused lane says «已暂停».
///
/// The cells COUNT every run, whatever its source (the grid answers HEALTH, not «cron execution rate» —
/// the hover card names each run's source honestly); `missed` alone still comes from the firing ledger.
///
/// **Click = launch pad** (the AnRunMatrix «tap a cell = go there» law): a cell with exactly one run
/// opens that run's flagship, a cell with several opens the workflow's operations home, and an empty or
/// missed-only cell is INERT (a dead affordance is a lie — there is nowhere true to go). The future ○ is
/// display-only.
///
/// **Hover = a non-interactive detail card** ([AnHoverCard], scroll-frozen): content cells and the future
/// ○ reveal a card listing the hour's runs (status · time · source · elapsed, failures on top) or the
/// forecast; empty cells reveal nothing.
///
/// **Architecture — cells are real widgets** (design-system §2「CustomPainter 只配画没有身份的像素」):
/// a CustomPainter's pixels have no identity — its `semanticsBuilder` yields nodes that cannot be
/// focused, so ←→ traversal is physically impossible under a pure painter. (The v1 now-line painter was
/// the track's last furniture; it retired with the ruler — there is nothing left to paint.)
///
/// ## Keyboard: ONE tab stop (roving tabindex), like [AnRunMatrix]
///
/// The cursor's unit is a CELL — every hourly bin (empty ones included: a track is a CLOCK and an empty
/// hour is still a face on it) plus the future ○ where a lane has one. Arrows DRAG THE VIEWPORT along
/// (the matrix law: `FocusTraversalPolicy.defaultTraversalRequestFocusCallback`, never a hand-rolled
/// ensureVisible). Every position owns a [FocusNode]
/// this widget owns outright, and exactly one — the cursor's — has `skipTraversal: false` (the flag that
/// still allows EXPLICIT focus, which is what an arrow does). Arrows re-bind [DirectionalFocusIntent] to a
/// [DirectionalFocusAction] subclass (the `MenuAnchor` precedent) and running off the edge calls
/// `super.invoke` so the framework walks the user OUT — nobody is trapped. ←→ walk a lane's bins in time
/// order (bin23 → the future ○); **↑↓ land on the SAME hour of the adjacent lane** (a track is a clock,
/// the thing «above» 14:00 is the other lane's 14:00). The cursor is addressed by **(lane id, slot)**, a
/// stable address — a refresh cannot slide it onto a different hour.
///
/// ## Screen reader: a per-lane summary + a sentence per cell
///
/// One [Semantics] container per lane with `explicitChildNodes: true` (**load-bearing, not decoration**:
/// without it a labelled container ABSORBS its descendants' labels, the lane reads as one run-on string
/// and the cells stop being addressable nodes at all — silently destroying the ←→ walk this lane exists
/// to host, caught by the semantics-tree dump, never by looking). The container carries the lane's whole
/// pattern ([laneSummaryLabel]); each cell keeps its own sentence ([binSemanticLabel] / a bare empty-hour
/// line / [futureSemanticLabel]); cursor moves announce on macOS via [AnA11y.announceFocusMove].
///
/// AnScheduleTrack v2(0718 用户提案「直接复用 Matrix View」——一个海洋一种格语言):**过去=矩阵同款方格的整点
/// 分箱**(controlSm 方格、soft 填充+状态色发丝描边逐字同矩阵;空=淡描边「空是真答案」;调用方给 25 格=24 完整
/// 小时+进行中那格,任意滚动 24h KPI 窗的超集,「错过 N」证据恒完整);missed 在**格内**叠灰 ✕(矩阵「×N 在格内」
/// 文法,形状通道,永不藏进聚合)。**格阵在自己肚子里横滚、右锚最新端**,名字车道冻结在左、预告段冻结在右(矩阵
/// 冻结车道滚动文法)——v1 的蓝 now 线与「起点/跨度/now」刻度眉退役:右锚下右缘即现在,列头随格同滚、每小时自报
/// 姓名([binHeadLabel]:「20」,0 点锚「7/19」)。**未来=定宽冻结段非时间轴**(Cronitor next-run 一句话)。格**统计
/// 所有来源的 run**(答健康,来源在 hover 卡如实标注),唯 missed 仍从 firing 账来。**点击=发射台**(同矩阵)。
/// **hover=不可交互明细卡**(滚动冻结)。**键盘=唯一一个 Tab 停靠**(roving,同 AnRunMatrix):光标单位=格(含空格
/// ——轨是钟)+ 未来 ○;方向键重绑 Intent、出边 super.invoke 交还框架,**且把视口拖着走**(矩阵立法:框架自己的
/// defaultTraversalRequestFocusCallback,绝不手搓 ensureVisible)。←→ 按时序走本泳道(末格→未来 ○);↑↓ 落邻泳道
/// **同一小时**;光标 (泳道 id, slot) 定址。**读屏**:每 lane 一 Semantics 容器 + explicitChildNodes(承重),
/// 容器带行摘要,每格带自己的句子;光标移动 macOS 补一发 announceFocusMove。

/// One run inside a bin — its detail for the hover card AND the click target. [status] is already folded
/// ([AnStatus.fromRaw]); [sourceLabel] is the caller's localized source phrase (core holds no copy);
/// [elapsed] is null while the run is in flight (never a zero that reads as «instant»).
/// 桶内一次 run:hover 卡明细 + 点击目标。status 已折好;sourceLabel=调用方本地化来源词(core 无文案);
/// elapsed 在跑期间为 null(绝不用会被读成「瞬时」的 0)。
class TrackRun {
  const TrackRun({
    required this.id,
    required this.workflowId,
    required this.at,
    required this.status,
    this.sourceLabel = '',
    this.elapsed,
  });

  final String id;
  final String workflowId;

  /// The run's start instant — the bin it lands in and the card's time word. run 开始时刻。
  final DateTime at;
  final AnStatus status;
  final String sourceLabel;
  final Duration? elapsed;
}

/// One hourly cell on a lane's past grid. [runs] are the runs that STARTED in [start, end) (failures
/// first, then time-ascending — the hover card's reading order); [missedCount] is the misfire ticks that
/// came due in the same hour (a grey ✕ overlay, never folded into the colour).
/// 一格:startedAt ∈ [start,end) 的 run(失败在前、其余按时序——hover 卡读序)+ 同小时的 missed 刻度数
/// (灰 ✕ 覆层,绝不折进格色)。
class TrackBin {
  const TrackBin({
    required this.index,
    required this.start,
    required this.end,
    this.runs = const [],
    this.missed = const [],
  });

  final int index;
  final DateTime start;
  final DateTime end;
  final List<TrackRun> runs;

  /// The misfire ticks that came due in this hour (their instants, so the hover card can say «错过
  /// HH:mm» for each). Kept as instants, not just a count, because the card lists them. 本小时的 missed
  /// 刻度(时刻,故卡可逐条念「错过 HH:mm」)。
  final List<DateTime> missed;

  int get missedCount => missed.length;

  bool get hasRuns => runs.isNotEmpty;

  /// Something to hover / a place a ✕ can sit. A bin with neither is genuinely empty. 有内容(可 hover)。
  bool get hasContent => runs.isNotEmpty || missedCount > 0;

  /// The colour a cell wears = the WORST outcome across its runs (the run-matrix cell law: a later
  /// success cannot erase an earlier failure). Null = no runs → the faint empty outline.
  /// 格色=各 run 最坏结局(同矩阵:后来的成功抹不掉真发生过的失败);null=无 run → 淡描边空格。
  AnStatus? get worst {
    AnStatus? out;
    for (final r in runs) {
      out = _worstStatus(out, r.status);
    }
    return out;
  }
}

/// The future half — the next fire as a SENTENCE, not a position. All three words are pre-localized by
/// the caller (core holds no copy): [time] «17:55» / «7/19 09:00», [relative] «(in 2m)» (parenthesised,
/// so it never collides with the bare KPI «in 2m»), [schedule] the trigger's own cadence words. A paused
/// lane carries NO future (the backend stamps no next-fire on a paused trigger); the widget says «已暂停»
/// from the lane's [TrackLane.note] instead. 未来半=一句话而非位置;三词皆调用方已本地化;暂停泳道无 future。
class TrackFuture {
  const TrackFuture({
    required this.at,
    this.time = '',
    this.relative = '',
    this.schedule = '',
  });

  /// The next-fire instant — carried for ordering / a11y, not rendered directly. 下一发时刻(排序/读屏)。
  final DateTime at;
  final String time;
  final String relative;
  final String schedule;
}

/// One swim lane = one schedule. [bins] is the past grid (already binned by [binTrackEvents], the same
/// list the keyboard model and the renderer read, so a cursor can never disagree with the screen).
/// [dimmed] is the PAUSED face (判决①): a paused lane greys but NEVER disappears — a stop-the-bleeding
/// switch the user threw must stay visible — and it carries the caller's «已暂停» word in [note] and a
/// null [future].
/// 一泳道=一条排程。bins=过去格(已由 binTrackEvents 分好,键盘模型与渲染读同一份);dimmed=暂停脸(判决①):
/// 灰显但绝不消失,note 带「已暂停」词、future 为空。
class TrackLane {
  const TrackLane({
    required this.id,
    required this.label,
    required this.bins,
    this.future,
    this.dimmed = false,
    this.note = '',
  });

  final String id;
  final String label;
  final List<TrackBin> bins;
  final TrackFuture? future;
  final bool dimmed;
  final String note;
}

/// Worst-disposition fold (err > wait > run > done > idle) — the run matrix's cell law, verbatim: a
/// later success cannot erase an earlier failure that really happened.
/// 最坏处置折叠(同矩阵格律,逐字):后来的成功抹不掉真发生过的失败。
AnStatus? _worstStatus(AnStatus? a, AnStatus? b) {
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

/// Bin [runs] + [missed] instants into [binCount] equal cells spanning `[start, end)` (24 hourly cells
/// over the past 24h). Pure — unit-tested without a pump. A run/tick lands in bin `i` iff its instant is
/// in `[start + i·w, start + (i+1)·w)`; anything outside `[start, end)` is dropped (unplaceable, so
/// unshown). Within a bin, runs are ordered FAILURES-FIRST then time-ascending, which is the hover card's
/// reading order — computed once here so the card never re-sorts.
///
/// 把 [runs] + [missed] 时刻分入 `[start, end)` 的 [binCount] 等分格(过去 24h 的 24 个小时格)。纯函数。
/// 落格规则:instant ∈ `[start + i·w, start + (i+1)·w)`;窗外丢弃(放不下就不渲)。桶内 run 按**失败在前、
/// 其余时序**排(=hover 卡读序,只在此排一次)。
List<TrackBin> binTrackEvents({
  required DateTime start,
  required DateTime end,
  required int binCount,
  List<TrackRun> runs = const [],
  List<DateTime> missed = const [],
}) {
  assert(binCount > 0, 'a track needs at least one bin');
  final spanMs = end.difference(start).inMilliseconds;
  // A zero/negative window can place nothing — return empty bins rather than divide by it.
  // 零/负窗放不下任何东西——返空格,不拿它做除数。
  if (spanMs <= 0) return const [];

  DateTime edge(int i) =>
      start.add(Duration(milliseconds: (spanMs * i / binCount).round()));
  final bounds = [for (var i = 0; i <= binCount; i++) edge(i)];

  int? slotOf(DateTime at) {
    final offMs = at.difference(start).inMilliseconds;
    if (offMs < 0 || offMs >= spanMs) {
      return null; // outside the axis — unplaceable 轴外不渲
    }
    final s = (offMs * binCount / spanMs).floor();
    return s < 0 ? 0 : (s >= binCount ? binCount - 1 : s);
  }

  final runsBySlot = List.generate(binCount, (_) => <TrackRun>[]);
  final missedBySlot = List.generate(binCount, (_) => <DateTime>[]);
  for (final r in runs) {
    final s = slotOf(r.at);
    if (s != null) runsBySlot[s].add(r);
  }
  for (final m in missed) {
    final s = slotOf(m);
    if (s != null) missedBySlot[s].add(m);
  }

  return [
    for (var i = 0; i < binCount; i++)
      TrackBin(
        index: i,
        start: bounds[i],
        end: bounds[i + 1],
        // Failures first, then time-ascending — the hover card reads a bin in this order. 失败在前、其余时序。
        runs: runsBySlot[i]
          ..sort((a, b) {
            final af = a.status == AnStatus.err, bf = b.status == AnStatus.err;
            if (af != bf) return af ? -1 : 1;
            return a.at.compareTo(b.at);
          }),
        missed: missedBySlot[i]..sort(),
      ),
  ];
}

class AnScheduleTrack extends StatefulWidget {
  const AnScheduleTrack({
    required this.lanes,
    required this.now,
    this.binHeadLabel,
    this.onBin,
    this.binSemanticLabel,
    this.emptyBinSemanticLabel,
    this.futureSemanticLabel,
    this.laneSummaryLabel,
    this.binHoverBuilder,
    this.futureHoverBuilder,
    super.key,
  });

  final List<TrackLane> lanes;

  /// The «now» instant (a11y ordering / callers' relative words). now 时刻(读屏/相对词用)。
  final DateTime now;

  /// The column-head word above one cell («20», or «7/19» on the midnight anchor) — the caller's
  /// glyphs, so the RULER of v1 (start stamp / span / now line) is fully retired: under the
  /// right-anchored scroll the trailing edge IS now, and every column names its own hour (用户
  /// 0718:「可以拖动的,每个小时都说明一下是哪一个小时」).
  /// 每格列头词(「20」,0 点锚「7/19」)——调用方的记号;v1 的刻度眉(起点戳/跨度/now 线)整体退役:
  /// 右锚下右缘即现在,每列自报所在小时。
  final String Function(TrackBin bin)? binHeadLabel;

  /// A content cell was activated — the caller decides where to go (1 run → flagship, N → home). Never
  /// fired for an empty or missed-only bin. 内容格被激活;去处归调用方;空/纯 missed 格永不触发。
  final void Function(TrackLane lane, TrackBin bin)? onBin;

  /// One cell's screen-reader sentence when it has runs. 有 run 的格的读屏句。
  final String Function(TrackLane lane, TrackBin bin)? binSemanticLabel;

  /// One empty cell's sentence («{HH} 时,无运行»). 空格句。
  final String Function(TrackLane lane, TrackBin bin)? emptyBinSemanticLabel;

  /// The future ○'s sentence («预计 {time},{schedule}»). 未来 ○ 句。
  final String Function(TrackLane lane)? futureSemanticLabel;

  /// The lane container's whole-pattern summary. 泳道容器行摘要。
  final String Function(TrackLane lane)? laneSummaryLabel;

  /// The hover card's body for a content cell (lazy — built only while shown). 内容格 hover 卡体(惰性)。
  final WidgetBuilder? Function(TrackLane lane, TrackBin bin)? binHoverBuilder;

  /// The hover card's body for the future ○. 未来 ○ 的 hover 卡体。
  final WidgetBuilder? Function(TrackLane lane)? futureHoverBuilder;

  @override
  State<AnScheduleTrack> createState() => _AnScheduleTrackState();
}

/// The roving cursor's address: which lane, and which SLOT on it — a bin index in `[0, binCount)`, or
/// [_futureSlot] for the future ○. A stable (id, slot) pair, never a widget index.
/// 光标地址:哪条泳道 + 哪个 slot(bin 下标,或 [_futureSlot] 表未来 ○);稳定对,绝非 widget 下标。
typedef _TrackCursor = (String laneId, int slot);

/// The slot that addresses a lane's future ○ (to the right of the last bin). 未来 ○ 的 slot(末格右侧)。
const int _futureSlot = -1;

/// Row pitch — a Matrix-View cell (controlSm square) plus one s4 breathing gap; the frozen lane-name
/// column, the grid rows and the frozen future segment all read this ONE height so the three segments
/// can never drift out of register. 行节距=矩阵格(24 方格)+s4 行距;三段同读此一高,永不错位。
const double _kRowH = AnSize.controlSm + AnSpace.s4;

/// The column-head lane's height (the hour words). 列头行高(小时词)。
const double _kHeadH = AnSize.icon;

class _AnScheduleTrackState extends State<AnScheduleTrack> {
  _TrackCursor? _cursor;
  final Map<_TrackCursor, FocusNode> _nodes = {};
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _hScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnScheduleTrack old) {
    super.didUpdateWidget(old);
    if (old.lanes != widget.lanes) {
      // Prune focus nodes whose (lane, slot) address no longer exists. 剪掉地址已不存在的焦点节点。
      final live = <_TrackCursor>{
        for (final l in widget.lanes) ...[
          for (final b in l.bins) (l.id, b.index),
          if (l.future != null) (l.id, _futureSlot),
        ],
      };
      _nodes.removeWhere((k, n) {
        if (live.contains(k)) return false;
        n.dispose();
        return true;
      });
    }
  }

  int get _binCount =>
      widget.lanes.isEmpty ? 0 : widget.lanes.first.bins.length;

  bool _slotExists(TrackLane lane, int slot) => slot == _futureSlot
      ? lane.future != null
      : (slot >= 0 && slot < lane.bins.length);

  /// Where the cursor IS, as (lane index, slot) — derived from the current lanes, never stored stale.
  /// 光标**当前**在哪(泳道下标, slot):自当前 lanes 派生、绝不存旧。
  (int, int)? get _resolved {
    final cur = _cursor;
    if (cur != null) {
      final li = widget.lanes.indexWhere((l) => l.id == cur.$1);
      if (li >= 0 && _slotExists(widget.lanes[li], cur.$2)) return (li, cur.$2);
    }
    // Default = the first lane's NEWEST bin — under the right anchor that is the spot the user can
    // always see (v2: bin 0 is 25 hours ago and off-screen; landing the cursor there would Tab the
    // user into a cell they cannot see). 默认=首泳道**最新**格:右锚下那才是恒可见处(bin0 在 25 小时前
    // 的屏外,Tab 落那儿=落进看不见的格)。
    for (var li = 0; li < widget.lanes.length; li++) {
      if (widget.lanes[li].bins.isNotEmpty) {
        return (li, widget.lanes[li].bins.length - 1);
      }
    }
    return null;
  }

  FocusNode _nodeFor(_TrackCursor key, {required bool cursor}) {
    final n = _nodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'AnScheduleTrack $key'),
    );
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
    final (li, slot) = at;
    final lane = widget.lanes[li];
    switch (dir) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        // A lane reads bin0 … bin(binCount-1) → future ○; RTL mirrors the visual direction.
        // 一泳道读 bin0…bin(n-1)→未来 ○;RTL 镜像视觉方向。
        final forward = dir == TraversalDirection.right;
        final step =
            (forward ? 1 : -1) *
            (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
        final ordered = <int>[
          for (var i = 0; i < lane.bins.length; i++) i,
          if (lane.future != null) _futureSlot,
        ];
        final idx = ordered.indexOf(slot);
        if (idx < 0) return false;
        final next = idx + step;
        if (next < 0 || next >= ordered.length) return false;
        _focus(li, ordered[next], dir);
        return true;
      case TraversalDirection.up:
      case TraversalDirection.down:
        // A track is a CLOCK: ↑↓ preserve the SLOT (the hour), landing on the same column of the
        // adjacent lane. A lane without the future ○ is stepped over on the future slot.
        // 轨是钟:↑↓ 保持 slot(小时),落邻泳道同一列;未来 slot 上,无 ○ 的泳道被跨过。
        final dl = dir == TraversalDirection.down ? 1 : -1;
        for (var l = li + dl; l >= 0 && l < widget.lanes.length; l += dl) {
          if (_slotExists(widget.lanes[l], slot)) {
            _focus(l, slot, dir);
            return true;
          }
        }
        return false;
    }
  }

  void _focus(int li, int slot, [TraversalDirection? dir]) {
    final lane = widget.lanes[li];
    final key = (lane.id, slot);
    setState(() => _cursor = key);
    final node = _nodeFor(key, cursor: true);
    if (dir == null || node.context == null) {
      node.requestFocus();
    } else {
      // Drag the viewport along (the AnRunMatrix law, verbatim): an explicit requestFocus skips the
      // framework's scroll-into-view (it lives on requestFocusCallback, which only runs on TRAVERSAL),
      // and this grid scrolls sideways inside itself — so call the framework's own callback with the
      // SAME alignment policy its directional traversal picks; the stock mapping survives the reversed
      // axis unchanged (矩阵实测背书,非推断).
      // 把视口拖着一起走(矩阵立法逐字):显式 requestFocus 跳过框架滚动入视,故调框架自己的回调,对齐策略
      // 照抄其方向遍历;原生映射在反转轴下原样成立(矩阵实测)。
      FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
        node,
        alignmentPolicy: switch (dir) {
          TraversalDirection.up || TraversalDirection.left =>
            ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          TraversalDirection.down || TraversalDirection.right =>
            ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        },
      );
    }
    // The focused node is the mechanism (Windows/Linux); this is the macOS-only repair — rule in
    // [AnA11y.announceFocusMove]. 被聚焦的节点是机制;这是给 macOS 补的那块。
    AnA11y.announceFocusMove(context, _sentence(lane, slot));
  }

  String _sentence(TrackLane lane, int slot) {
    if (slot == _futureSlot) {
      return widget.futureSemanticLabel?.call(lane) ?? '';
    }
    final bin = lane.bins[slot];
    if (bin.hasRuns) return widget.binSemanticLabel?.call(lane, bin) ?? '';
    return widget.emptyBinSemanticLabel?.call(lane, bin) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lanes.isEmpty || _binCount == 0) return const SizedBox.shrink();
    final c = context.colors;
    final at = _resolved;
    // The AnRunMatrix three-segment layout, verbatim (0718 v2「直接复用 Matrix View」): the lane-name
    // column FROZEN outside the scroller (under the reverse anchor the oldest edge is off-screen by
    // construction, and a grid whose rows can't be named is unreadable), the hour grid scrolling
    // sideways inside itself ANCHORED AT THE NEWEST EDGE (offset 0 = now's hour — the v1 now line is
    // retired: the trailing edge IS now), and the next-fire segment FROZEN on the right (the forecast
    // must stay readable wherever the grid is scrolled). The column heads ride INSIDE the scroller —
    // every hour names itself as it slides by.
    // 矩阵三段布局逐字复用:名字车道冻结在滚动器外(右锚下最旧缘天然在屏外,叫不出行名的格阵没法读)、
    // 小时格阵在自己肚子里横滚**右锚最新端**(offset 0=当前小时——v1 的 now 线退役:右缘即现在)、下一发段
    // 冻结在右(滚到哪预告都在)。列头随滚动器走——每个小时滑过时自报姓名。
    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _TrackDirectionalFocusAction(this),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: _kHeadH + AnSpace.s4),
              for (final lane in widget.lanes) _laneLabel(context, lane),
            ],
          ),
          const SizedBox(width: AnSpace.s12),
          Flexible(
            child: RawScrollbar(
              controller: _hScroll,
              thumbVisibility: true,
              thumbColor: c.lineStrong,
              radius: const Radius.circular(AnRadius.pill),
              thickness: AnSpace.s4,
              minThumbLength: AnSize.controlSm,
              child: ScrollConfiguration(
                behavior: const AnScrollBehavior(),
                // reverse: offset 0 = the NEWEST (trailing) edge — first frame opens on the current
                // hour with no post-frame jump (矩阵同律). reverse:offset 0=最新缘,首帧即当前小时。
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _colHeads(context),
                      for (var i = 0; i < widget.lanes.length; i++)
                        _lane(context, i, at),
                      // The bar is an OVERLAY — give the last lane its own strip (矩阵同款条道).
                      // 条是覆层,给末行让出一条道。
                      const SizedBox(height: AnSpace.s8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AnSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: _kHeadH + AnSpace.s4),
              for (var i = 0; i < widget.lanes.length; i++)
                SizedBox(
                  height: _kRowH,
                  width: AnSize.trackFutureW,
                  child: _future(context, i, widget.lanes[i], at),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The column-head row: one word per hour cell («20», «7/19» at midnight), sliding WITH the grid so
  /// a dragged view always names what it shows (v1's start/span/now ruler is retired wholesale).
  /// 列头行:每格一词(「20」,0 点「7/19」),随格同滚——拖到哪就标到哪;v1 三锚刻度眉整体退役。
  Widget _colHeads(BuildContext context) {
    final c = context.colors;
    final heads = widget.lanes.first.bins;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final bin in heads)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AnSpace.s4),
              child: SizedBox(
                width: AnSize.controlSm,
                height: _kHeadH,
                child: Center(
                  child: Text(
                    widget.binHeadLabel?.call(bin) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: AnText.metaTabular().copyWith(color: c.inkFaint),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// One frozen lane label (dimmed on a paused lane); the «已暂停» word rides the FUTURE segment —
  /// one word, one place. 冻结泳道名(暂停灰显);「已暂停」词在未来段——一词一处。
  Widget _laneLabel(BuildContext context, TrackLane lane) {
    final c = context.colors;
    return SizedBox(
      height: _kRowH,
      width: AnSize.ganttLaneW,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          lane.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AnText.meta.copyWith(
            color: lane.dimmed ? c.inkFaint : c.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _lane(BuildContext context, int li, (int, int)? at) {
    final lane = widget.lanes[li];
    // ONE semantics container per lane (§12): the reader hears the summary, then walks the cells.
    // `explicitChildNodes` is LOAD-BEARING (see the class doc). 每泳道一个语义容器(§12),explicitChildNodes 承重。
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          widget.laneSummaryLabel?.call(lane) ??
          (lane.note.isEmpty ? lane.label : '${lane.label} · ${lane.note}'),
      child: SizedBox(
        height: _kRowH,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final bin in lane.bins)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AnSpace.s4),
                child: _binCell(context, li, lane, bin, at),
              ),
          ],
        ),
      ),
    );
  }

  Widget _binCell(
    BuildContext context,
    int li,
    TrackLane lane,
    TrackBin bin,
    (int, int)? at,
  ) {
    final c = context.colors;
    final worst = bin.worst;
    final tone = worst?.tone;
    // The Matrix View cell, verbatim (0718 v2 用户提案「直接复用」): a controlSm SQUARE, soft-tint fill
    // + status-coloured hairline for a run cell, a transparent faint-outlined square for an empty hour
    // (空是真答案,同矩阵「未及」). A missed tick lays a grey ✕ INSIDE the cell (matrix's «×N 在格内»
    // grammar; a SHAPE beside the colour, WCAG 1.4.1) — one mark whatever the count, the number lives
    // in the hover card. 矩阵格逐字复用:controlSm 方格、soft 填充+状态色发丝描边,空格透明淡描边;missed
    // 在格内叠灰 ✕(矩阵「×N 在格内」文法,形状通道)——一枚记号不论几次,数目在 hover 卡。
    Widget square = Container(
      width: AnSize.controlSm,
      height: AnSize.controlSm,
      decoration: BoxDecoration(
        color: tone == null ? const Color(0x00000000) : tone.softBg(c),
        borderRadius: BorderRadius.circular(AnRadius.tag),
        border: Border.all(
          color: tone == null ? c.line : tone.fg(c),
          width: AnSize.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: bin.missedCount > 0
          ? Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkMuted)
          : null,
    );
    if (lane.dimmed && worst != null) {
      square = Opacity(opacity: AnOpacity.stratum, child: square);
    }

    // Content cell (has runs) → launch pad + hover card; missed-only or empty → inert, no card.
    // 内容格(有 run)→ 发射台 + hover 卡;纯 missed / 空 → 惰性、无卡。
    final tappable = widget.onBin != null && bin.hasRuns;
    final hover = bin.hasContent
        ? widget.binHoverBuilder?.call(lane, bin)
        : null;
    final sentence = bin.hasRuns
        ? widget.binSemanticLabel?.call(lane, bin)
        : widget.emptyBinSemanticLabel?.call(lane, bin);

    return Center(
      child: _Cell(
        focusNode: widget.onBin == null
            ? null
            : _nodeFor((lane.id, bin.index), cursor: at == (li, bin.index)),
        tappable: tappable,
        onActivate: tappable ? () => _activate(lane, bin) : null,
        hoverBuilder: hover,
        semanticLabel: sentence,
        child: square,
      ),
    );
  }

  void _activate(TrackLane lane, TrackBin bin) {
    _cursorTo((lane.id, bin.index));
    widget.onBin?.call(lane, bin);
  }

  Widget _future(BuildContext context, int li, TrackLane lane, (int, int)? at) {
    final c = context.colors;
    final f = lane.future;
    // No forecast to draw. A paused lane says «已暂停»; a lane with only non-cron sources (no knowable
    // next fire) leaves the segment blank. 无预告可画:暂停说「已暂停」;仅非 cron 源(下次不可知)留空。
    if (f == null) {
      final word = lane.dimmed ? lane.note : '';
      return word.isEmpty
          ? const SizedBox.shrink()
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                word,
                maxLines: 1,
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
            );
    }

    final ring = AnStatusDot.raw(
      lane.dimmed ? c.inkFaint : c.inkMuted,
      hollow: true,
      size: AnSize.dot,
    );
    // The ○ is fixed; the whole «HH:mm (relative) · schedule» phrase rides ONE Expanded RichText with
    // ellipsis, so a long trigger name (or a squeezed segment) degrades rather than overflowing — the
    // time stays highest priority. 时刻词优先,整句一条 Expanded RichText 省略号:长名/挤压时降级不溢出。
    final line = Row(
      children: [
        ring,
        const SizedBox(width: AnSpace.s6),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: AnText.meta.copyWith(color: c.ink),
              children: [
                if (f.time.isNotEmpty) TextSpan(text: f.time),
                if (f.relative.isNotEmpty)
                  TextSpan(
                    text: ' ${f.relative}',
                    style: TextStyle(color: c.inkFaint),
                  ),
                if (f.schedule.isNotEmpty)
                  TextSpan(
                    text: ' · ${f.schedule}',
                    style: TextStyle(color: c.inkFaint),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return _Cell(
      focusNode: widget.onBin == null
          ? null
          : _nodeFor((lane.id, _futureSlot), cursor: at == (li, _futureSlot)),
      // The future ○ is display-only (never a launch pad). 未来 ○ 只读、非发射台。
      tappable: false,
      onActivate: null,
      hoverBuilder: widget.futureHoverBuilder?.call(lane),
      semanticLabel: widget.futureSemanticLabel?.call(lane),
      child: line,
    );
  }
}

/// Arrows move the CURSOR along the track, and hand back to the framework at the edge — the `MenuAnchor`
/// precedent. 方向键在轨内挪光标,到边即交还框架——MenuAnchor 同款先例。
class _TrackDirectionalFocusAction extends DirectionalFocusAction {
  _TrackDirectionalFocusAction(this.state);

  final _AnScheduleTrackState state;

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (state._move(intent.direction)) return;
    super.invoke(intent);
  }
}

/// One roving-cursor cell — a real [FocusNode] (so directional traversal gives ←→ for free), a keyboard
/// focus ring, an optional launch tap, and an optional hover card. Every cell is focusable when the
/// track is interactive (a track is a clock — even an empty hour is a stop); only content cells activate.
/// 一个 roving 光标格:真焦点节点(←→ 白送)+ 键盘焦点环 + 可选发射点击 + 可选 hover 卡;交互轨下每格可聚焦
/// (轨是钟,空格也是一站),唯内容格可激活。
class _Cell extends StatefulWidget {
  const _Cell({
    required this.child,
    this.focusNode,
    this.tappable = false,
    this.onActivate,
    this.hoverBuilder,
    this.semanticLabel,
  });

  final Widget child;
  final FocusNode? focusNode;
  final bool tappable;
  final VoidCallback? onActivate;
  final WidgetBuilder? hoverBuilder;
  final String? semanticLabel;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticLabel;
    Widget visual = AnFocusRing(
      active: _focused,
      radius: AnRadius.tag,
      child: widget.child,
    );
    if (label != null && label.isNotEmpty) {
      visual = Semantics(
        label: label,
        button: widget.tappable,
        child: ExcludeSemantics(child: visual),
      );
    }
    // ONE FocusableActionDetector owns focus + activation (principle #8, the AnInteractive substrate).
    // enabled ⟺ the track is interactive (a focusNode was supplied): every cell is then focusable — the
    // owner's `skipTraversal` on its node makes exactly one a Tab stop, an arrow's explicit focus still
    // lands (Flutter leaves an external node's flags alone). Empty cells carry no shortcuts/actions, so
    // Enter over an empty hour does nothing while the cursor can still rest there («轨是钟»).
    // 一个 FAD 掌焦点+激活:enabled ⟺ 交互轨(给了 focusNode)→ 每格可聚焦,持有者的 skipTraversal 让恰一个成 Tab 停靠,
    // 方向键显式聚焦仍落;空格无 shortcuts/actions,Enter 在空小时上无事,光标仍可停(轨是钟)。
    Widget cell = FocusableActionDetector(
      enabled: widget.focusNode != null,
      focusNode: widget.focusNode,
      mouseCursor: widget.tappable
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      shortcuts: widget.tappable
          ? const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            }
          : const <ShortcutActivator, Intent>{},
      actions: widget.tappable
          ? <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onActivate?.call();
                  return null;
                },
              ),
            }
          : const <Type, Action<Intent>>{},
      // Ring only on KEYBOARD focus (a mouse click moves the cursor without highlighting). 键盘聚焦才现环。
      onShowFocusHighlight: (f) {
        if (f != _focused && mounted) setState(() => _focused = f);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.tappable ? widget.onActivate : null,
        child: visual,
      ),
    );
    final hover = widget.hoverBuilder;
    if (hover != null) {
      cell = AnHoverCard(cardBuilder: hover, child: cell);
    }
    return cell;
  }
}
