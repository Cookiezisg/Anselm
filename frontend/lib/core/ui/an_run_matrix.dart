import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_focus_ring.dart';
import 'an_interactive.dart';
import 'an_tooltip.dart';
import 'icons.dart';
import 'tone.dart';

/// AnRunMatrix (WRK-069 §12 + 判决③, S5) — the node×run grid: rows are a workflow's nodes, columns its
/// last N runs (newest LEFT, the same order as every run list), and each cell is one (run, node)
/// outcome. It is the linked pane's third face, and the ONE question it answers that neither the gantt
/// nor the graph can: **is this node ALWAYS the one that breaks, or was it just this once** — a
/// pattern across runs, which a single-run lens is structurally blind to.
///
/// **Sparse by contract**: a run that never reached a node has NO cell — that reads 「未及」 (the
/// caller's word), NOT a failure and NOT a success. The empty square is a real answer.
///
/// **Column-top duration sliver**: each column wears its RUN's wall clock as a relative bar
/// ([AnHeatBar]'s law, inlined here because the bar must sit in the column's exact width). A run still
/// going has NO elapsed — its column head shows the running tint instead of a bar, never a zero-width
/// bar that would read as «instant».
///
/// **Three selection grains** (§12): tap a CELL (this run, this node) · tap a COLUMN head (this run) ·
/// tap a ROW head (this node's history). The caller owns what each means; the grid only reports and
/// highlights [selection]. Selection is the CALLER's pick and is a different axis from the keyboard
/// cursor below — ARIA keeps them apart for a reason: moving the cursor must not select.
///
/// ## Keyboard: ONE tab stop (roving tabindex — the ARIA APG grid pattern, physically)
///
/// A 20×24 grid of individually-focusable squares is 527 Tab stops; a keyboard user who tabs in needs
/// ~500 more presses to get out. That is not «complete», it is broken. So the grid is **one** stop:
///   • Every position owns a [FocusNode] this widget owns outright, and **exactly one** of them —
///     the cursor's — has `skipTraversal: false`. Tab enters the grid once and leaves it once.
///     `skipTraversal` (NOT `canRequestFocus: false`) is the right flag, verbatim per its own doc:
///     it «place[s] nodes in the focus tree that may be focused, but not traversed» — the cell can
///     still be focused EXPLICITLY (which is exactly what an arrow key does), and it still receives
///     key events as part of the focus chain. `canRequestFocus: false` would forbid both.
///   • Flutter never fights us for those flags: [Focus] only writes `skipTraversal`/`canRequestFocus`
///     onto its node `if (!widget._usingExternalFocus)` (focus_scope.dart `_initNode`/`_handleUpdate`)
///     — i.e. a node the CALLER supplies is the caller's alone. That is why these nodes are ours.
///   • Arrow keys **override the Intent, never the key**: [DirectionalFocusIntent] is re-bound to a
///     [DirectionalFocusAction] subclass ([_MatrixDirectionalFocusAction]), exactly as `MenuAnchor`
///     does (`material/menu_anchor.dart` `_SubmenuDirectionalFocusAction`). Handling raw arrows in an
///     `onKeyEvent` instead would be wrong twice over: returning `ignored` lets the event bubble to
///     [WidgetsApp]'s default bindings (`widgets/app.dart` binds every bare arrow to
///     `DirectionalFocusIntent`) and the focus JUMPS OUT of the grid mid-walk; returning `handled`
///     means hand-rolling every edge, wrap and escape and losing `ignoreTextFields` semantics.
///   • **Escape is the framework's job**: a move that runs off the edge calls `super.invoke(intent)`,
///     handing the intent back to the default traversal so the user walks naturally OUT of the grid.
///     Nobody is ever trapped. Tab out is safe too — `_sortAllDescendants` deliberately keeps the
///     current node even when it skips traversal («Current focused node needs to be in the group so
///     that the caller can find the next traversable node from the current focused node»), so Tab
///     from a cell lands on whatever follows the grid, not back at the top of the page.
///   • Enter/Space come free: the default shortcut tables already map them to `ActivateIntent`, and
///     every cell is an [AnInteractive] (= a [FocusableActionDetector]) that answers it.
///
/// The cursor is addressed by **stable ids, never indices** — a grid that refreshes (a new run
/// prepends a column) must not silently slide the cursor onto a different run.
///
/// ## Screen reader: row-level, because the desktop transports no table
///
/// Desktop Flutter can express **no table structure at all** (see design-system.md §2「桌面 a11y 的真实
/// 边界」: role/indexInParent/liveRegion/hint are all no-ops or absent). So 480 flat cell nodes would be
/// 480 unstructured items to walk with nothing to say where any of them sits — the semantics dump
/// measured 1054 nodes for a 20×24 grid. Instead:
///   • each ROW is one container carrying the caller's [rowSummaryLabel] — the summary states the
///     PATTERN in words (「{node}，第 r 行 共 R 行，20 次运行:17 成功 3 失败」), which is the very question
///     this grid exists to answer, and it answers it without walking a single cell;
///   • cells are [ExcludeSemantics] — **except** the two that are worth a node: the keyboard cursor
///     and the caller's [selection] (the selection is what the app shows in the linked pane, so a
///     screen-reader user must be able to find it). The exclusion wraps the WHOLE cell, not just its
///     box: [AnInteractive] and [AnTooltip] annotate semantics of their own, and excluding only the
///     inside leaves one unlabelled BUTTON node per square — a wall of 480 anonymous buttons;
///   • the cursor's sentence carries its COORDINATE ([coordinateLabel]) inside the label string,
///     because the desktop has no other place to put it;
///   • the cursor's node is the mechanism that speaks on Windows/Linux (both fire a focus
///     notification), and [_announce] is the macOS repair for the hole where that mechanism is
///     missing — «a focused node is always read» is NOT true on macOS.
/// `explicitChildNodes: true` on the row container is load-bearing, not decoration: without it a
/// labelled container ABSORBS its descendants' labels and the cursor stops being an addressable node
/// (caught by the semantics-tree dump, never by looking). Measured: 1054 semantics nodes for a 20×24
/// grid before this shape, 95 after.
///
/// **No virtualization, deliberately**: `recentN` is capped at 20 by the backend (its default IS its
/// max), and rows are a graph's nodes — tens, not thousands. A 20×N grid of small squares is a few
/// hundred widgets; a virtualized 2-D viewport here would be machinery guarding an impossible case
/// (§12 said «虚拟化列窗» when the cap was still open — recorded as a deviation). The whole grid fits
/// the full-bleed pane without horizontal scroll, which is why 判决③ bought the width exemption at all.
///
/// AnRunMatrix 节点×run 格阵:行=节点、列=近 N 次 run(新在**左**,与所有 run 列表同序),格=一次 (run,节点)
/// 的结局。它是联动格第三脸,回答甘特与图**结构上看不见**的那个问题:**这个节点是老是坏,还是就坏了这一次**
/// ——跨 run 的模式。**契约级稀疏**:没跑到即无格,读作「未及」(调用方的词),既非失败也非成功,空格本身是
/// 真答案。**列顶时长微条**:每列穿它那次 **run** 的墙钟(相对条);仍在跑的 run 无时长——列头改渲在跑色,
/// 绝不画会被读成「瞬时」的零宽条。**三粒度选区**:点格/点列头/点行头,含义归调用方;选区是调用方的**选中**,
/// 与下面的键盘**光标**是两条轴(ARIA 分开它们自有道理:移动光标绝不等于选中)。
///
/// **键盘=唯一一个 Tab 停靠**(roving tabindex,ARIA APG 网格模式的物理实现):20×24 个各自可聚焦的方块
/// =527 个停靠,进去要再按 500 次才出得来——那不是「完整」,是坏的。故:每个位置的 [FocusNode] 由本件**自持**,
/// **恰好一个**(光标那个)`skipTraversal: false`;用 skipTraversal 而非 `canRequestFocus: false`——照其文档
/// 逐字:它让节点「可被聚焦但不被遍历」(方向键做的正是**显式**聚焦),且**仍在 focus chain 上收键**,而
/// canRequestFocus:false 会把两者一起禁掉。框架不会来抢这些旗标:[Focus] 仅在 `!_usingExternalFocus` 时才
/// 往节点上写(focus_scope.dart)——调用方给的节点归调用方,这正是我们自持的理由。**方向键覆盖 Intent、绝不
/// 抢键**:把 DirectionalFocusIntent 重绑到 DirectionalFocusAction 子类(MenuAnchor 同款先例);用
/// onKeyEvent 收裸方向键两条路都错——返 ignored 会冒泡到 WidgetsApp 的默认绑定(它把每个裸方向键都绑到
/// DirectionalFocusIntent)、焦点**跳出**格阵;返 handled 则要自己手搓全部边界/换行/逃逸并丢掉
/// ignoreTextFields 语义。**越界=还给框架**:出边时 `super.invoke(intent)` 把 intent 交还默认遍历,用户自然
/// 走出格阵,永不被困;Tab 出去也安全——`_sortAllDescendants` 刻意保留当前节点(即便它 skipTraversal),故从
/// 格 Tab 出去落在格阵**之后**那个控件,而不是弹回页首。Enter/Space 白送(默认表已绑 ActivateIntent)。
/// 光标用**稳定 id 定址、绝不用下标**——刷新(新 run 前插一列)绝不能让光标悄悄滑到另一次 run 上。
///
/// **读屏=行级**(因为桌面根本运不动表格结构,见 design-system §2「桌面 a11y 的真实边界」):480 个扁平格
/// 节点=480 条无结构的条目、且没有任何地方说得出它们在哪(语义树 dump 实测 20×24=**1054** 节点,行级后
/// **95**)。故:**每行一个容器**,穿调用方的 [rowSummaryLabel]——摘要用**词**说出**模式**(「{node}，第 r 行
/// 共 R 行,20 次运行:17 成功 3 失败」),那正是本格阵存在要答的问题,且一格都不用走就答了;**格
/// ExcludeSemantics**——**除了**值得一个节点的那两个:键盘**光标**与调用方的**选区**(选区=联动格正在展示的
/// 那个,读屏用户必须找得到它);**排除要包住整格而不只是盒**(AnInteractive 与 AnTooltip 各自也标语义,
/// 只排里面会留下每格一个**无 label 的按钮**节点=480 个无名按钮的墙);光标的句子把**坐标**
/// ([coordinateLabel])编进 label 字符串——桌面没有第二个地方放它;**光标节点**是 Windows/Linux 上说话的机制
/// (两者都发焦点通知),而 [_announce] 是给 **macOS** 补的洞——「被聚焦的节点总会被念」这句话**在 macOS 不
/// 成立**。行容器的 `explicitChildNodes: true` 是**承重的、非装饰**:没有它,带 label 的容器会**吸收**后代
/// label、光标不再是可寻址节点(靠语义树 dump 抓到,肉眼看不出)。
///
/// **刻意不虚拟化**:recentN 被后端钳在 20(默认即上限),行是图的节点——几十不是几千;20×N 个小方块是几百
/// 个 widget,在此上二维虚拟视口是为不可能的情况造机器(§12 写「虚拟化列窗」时上限尚未定,记偏差)。整个
/// 格阵在全宽格里免横滚——这正是判决③ 当初买下宽度豁免的理由。

/// One column = one run. [elapsedMs] is the RUN's wall clock; null = still going (never a zero).
/// 一列=一次 run;elapsedMs=run 墙钟,null=还在跑(绝不是 0)。
class RunColumn {
  const RunColumn({required this.id, required this.status, this.elapsedMs, this.label = ''});

  final String id;
  final String status;

  /// Null while the run is in flight — judge NULL, never reverse-derive from [status].
  /// 在跑期间为 null——直接判 null,别拿 status 反推。
  final int? elapsedMs;

  /// The caller's already-localized column tooltip (core holds no copy). 调用方已本地化的列 tooltip。
  final String label;
}

/// One row = one node. 一行=一个节点。
class MatrixRowHead {
  const MatrixRowHead({required this.nodeId, this.kind = ''});

  final String nodeId;
  final String kind;
}

/// One cell's outcome. [iterations] > 1 renders «×N» (the run ledger's fold law). [status] is already
/// the WORST disposition across the run's iterations — the grid does not re-derive it.
/// 一格的结局;iterations>1 渲「×N」(同台账折叠律);status 已是该 run 各轮的**最坏**处置,格阵不再自行推导。
class MatrixCellState {
  const MatrixCellState({required this.status, this.iterations = 1, this.label = ''});

  final String status;
  final int iterations;
  final String label;
}

/// The grid's three selection grains — what the caller last picked. 三粒度选区:调用方最后点了什么。
class MatrixSelection {
  const MatrixSelection({this.flowrunId, this.nodeId});

  final String? flowrunId;
  final String? nodeId;

  bool get isEmpty => flowrunId == null && nodeId == null;
}

/// Everything a row's screen-reader summary needs — the row, where it sits, and its whole run of
/// outcomes ([cells] is aligned with `cols`; a null entry is 「未及」). The caller counts and words it:
/// core holds no copy, and only the caller knows how to say «17 成功 3 失败».
/// 行摘要要用的一切:行、它在第几行、以及它整条的结局(cells 与 cols 对齐,null=未及)。计数与措辞归调用方
/// ——core 不含文案,且只有调用方知道「17 成功 3 失败」该怎么说。
class MatrixRowSummary {
  const MatrixRowSummary({
    required this.row,
    required this.index,
    required this.total,
    required this.cells,
  });

  final MatrixRowHead row;

  /// 0-based — the caller adds one if its wording counts from 1. 0 起;要从 1 数由调用方加。
  final int index;
  final int total;

  /// This row's outcome per column, in column order; null = 未及. 逐列结局,列序;null=未及。
  final List<MatrixCellState?> cells;
}

class AnRunMatrix extends StatefulWidget {
  const AnRunMatrix({
    required this.rows,
    required this.cols,
    required this.cellStatus,
    this.selection = const MatrixSelection(),
    this.onCell,
    this.onCol,
    this.onRow,
    this.notReachedLabel = '',
    this.runningLabel = '',
    this.cellSemanticLabel,
    this.colSemanticLabel,
    this.rowSemanticLabel,
    this.rowSummaryLabel,
    this.coordinateLabel,
    super.key,
  });

  final List<MatrixRowHead> rows;
  final List<RunColumn> cols;

  /// The SPARSE lookup: null = this run never reached this node → 「未及」. 稀疏查询:null=未及。
  final MatrixCellState? Function(String flowrunId, String nodeId) cellStatus;

  final MatrixSelection selection;
  final void Function(String flowrunId, String nodeId)? onCell;
  final void Function(String flowrunId)? onCol;
  final void Function(String nodeId)? onRow;

  /// Caller i18n (core stays string-free). 调用方 i18n(core 不含文案)。
  final String notReachedLabel;
  final String runningLabel;

  /// One cell's identity sentence — spoken when that cell is the keyboard cursor or the [selection].
  /// 一格的身份句:该格是键盘光标或选区时被念出。
  final String Function(RunColumn col, MatrixRowHead row, MatrixCellState? cell)? cellSemanticLabel;

  /// The column-head button's own label. 列头按钮自己的 label。
  final String Function(RunColumn col)? colSemanticLabel;

  /// The row-head button's own label. 行头按钮自己的 label。
  final String Function(MatrixRowHead row)? rowSemanticLabel;

  /// The ROW CONTAINER's summary — a different node and a different job from [rowSemanticLabel] (which
  /// labels the head BUTTON): this one states the row's whole pattern so a screen reader answers
  /// 「老是坏还是就这一次」 without walking 20 cells. Absent → the row groups without a summary.
  /// 行**容器**的摘要——与 rowSemanticLabel(那是行头**按钮**的 label)是不同节点、不同职责:这一句说出整行的
  /// 模式,让读屏不走 20 个格就答出「老是坏还是就这一次」。缺省=行不带摘要地成组。
  final String Function(MatrixRowSummary summary)? rowSummaryLabel;

  /// The cursor's coordinate clause, e.g. 「第 3 行 共 24 行，第 5 列 共 20 列」 — appended to the cell's
  /// sentence because the desktop transports NO table structure to put it in (design-system §2). Both
  /// indices are 0-based. Absent → the cursor speaks its identity without a position, which on a
  /// desktop screen reader means it has none at all.
  /// 光标的坐标从句——拼进格的句子里,因为桌面**运不动**任何表格结构来放它(design-system §2)。两个下标皆
  /// 0 起。缺省=光标只报身份不报位置,而在桌面读屏上那等于**没有**位置。
  final String Function(int rowIndex, int rowCount, int colIndex, int colCount)? coordinateLabel;

  @override
  State<AnRunMatrix> createState() => _AnRunMatrixState();
}

/// The roving cursor's address. A null [rowId] addresses the COLUMN-head row, a null [colId] the
/// ROW-head column; both null is the dead corner and is never a cursor. Ids, not indices — see the
/// class doc. 光标地址:rowId=null 指列头行、colId=null 指行头列,两者皆 null=死角(永不是光标)。用 id 不用
/// 下标,理由见类文档。
typedef _Cursor = (String? rowId, String? colId);

class _AnRunMatrixState extends State<AnRunMatrix> {
  /// Null until the user (or [MatrixSelection]) puts it somewhere — resolved at build. null=尚未落位。
  _Cursor? _cursor;

  /// One node per addressable position. They exist anyway (every [AnInteractive] builds a
  /// [FocusableActionDetector] which would allocate its own) — owning them is what buys the roving
  /// flag, not extra cost. 每个可寻址位置一个节点。它们本来就存在(每个 AnInteractive 都是 FAD、自己也会
  /// 造一个)——自持换来的是那面 roving 旗标,不是额外开销。
  final Map<_Cursor, FocusNode> _nodes = {};

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AnRunMatrix old) {
    super.didUpdateWidget(old);
    // A vanished run/node must not leave its node behind — prune when the axes actually change.
    // 消失的 run/节点不得留下节点残骸——轴真的变了才剪枝。
    if (old.rows != widget.rows || old.cols != widget.cols) {
      final live = _liveKeys();
      _nodes.removeWhere((k, n) {
        if (live.contains(k)) return false;
        n.dispose();
        return true;
      });
    }
  }

  Set<_Cursor> _liveKeys() => {
        for (final r in widget.rows) ...[
          (r.nodeId, null),
          for (final c in widget.cols) (r.nodeId, c.id),
        ],
        for (final c in widget.cols) (null, c.id),
      };

  /// A position is navigable exactly when the caller made it actionable — an inert head or an inert
  /// cell is a picture, and a picture is not a keyboard stop.
  /// 位置可导航 ⟺ 调用方让它可动作——惰性的头/格是画,画不是键盘停靠。
  bool _navigable(int r, int c) {
    if (r < -1 || c < -1 || r >= widget.rows.length || c >= widget.cols.length) return false;
    if (r == -1 && c == -1) return false; // the dead corner 死角
    if (r == -1) return widget.onCol != null;
    if (c == -1) return widget.onRow != null;
    return widget.onCell != null;
  }

  (int, int)? _indexOf(_Cursor cur) {
    final r = cur.$1 == null ? -1 : widget.rows.indexWhere((e) => e.nodeId == cur.$1);
    final c = cur.$2 == null ? -1 : widget.cols.indexWhere((e) => e.id == cur.$2);
    // indexWhere's «-1 = not found» collides with «-1 = the head axis» — so a named-but-missing id is
    // a STALE cursor (its run/node left the grid), not a head.
    // indexWhere 的「-1=没找到」与「-1=头轴」撞名——故「给了名却找不到」是**过期**光标(它那次 run/节点已离场),
    // 不是头。
    if ((cur.$1 != null && r < 0) || (cur.$2 != null && c < 0)) return null;
    return (r, c);
  }

  _Cursor _cursorAt(int r, int c) =>
      (r < 0 ? null : widget.rows[r].nodeId, c < 0 ? null : widget.cols[c].id);

  /// Where the cursor IS — derived, never stored stale: a cursor whose row/run left the grid falls
  /// back to the default rather than pointing at a ghost.
  /// 光标**当前**在哪:派生而非存旧——行/run 离场的光标回落默认值,绝不指着幽灵。
  (int, int)? get _resolved {
    final cur = _cursor;
    if (cur != null) {
      final at = _indexOf(cur);
      if (at != null && _navigable(at.$1, at.$2)) return at;
    }
    // The caller's pick is where the user last was — start there, not at a corner they never touched.
    // 调用方的选区=用户上次所在——从那里起,而不是从他们没碰过的角落。
    final s = widget.selection;
    if (s.flowrunId != null && s.nodeId != null) {
      final at = _indexOf((s.nodeId, s.flowrunId));
      if (at != null && _navigable(at.$1, at.$2)) return at;
    }
    for (final at in [(0, 0), (0, -1), (-1, 0)]) {
      if (_navigable(at.$1, at.$2)) return at;
    }
    return null;
  }

  FocusNode _nodeFor(_Cursor key, {required bool cursor}) {
    final n = _nodes.putIfAbsent(key, () => FocusNode(debugLabel: 'AnRunMatrix $key'));
    // The roving flag itself: exactly one node in the grid answers Tab. Safe to set here — Flutter
    // leaves an externally-supplied node's flags alone (see the class doc).
    // roving 旗标本体:全格阵恰好一个节点应 Tab。在此设置是安全的——外供节点的旗标框架不碰(见类文档)。
    n.skipTraversal = !cursor;
    return n;
  }

  /// Move the cursor one step, stepping OVER positions the caller left inert. Returns false when the
  /// walk runs off the grid — the caller ([_MatrixDirectionalFocusAction]) then hands the intent back
  /// to the framework so the user escapes instead of being trapped.
  /// 走一步,**跨过**调用方留成惰性的位置。走出格阵返 false——调用方随即把 intent 交还框架,用户逃出而非被困。
  bool _move(TraversalDirection dir) {
    final at = _resolved;
    if (at == null) return false;
    // Arrow keys are VISUAL (APG: «Right Arrow moves focus one cell to the right»), and a Row mirrors
    // under RTL — so the visual direction maps onto the column index through directionality.
    // 方向键是**视觉**的(APG:右箭头=视觉右移一格),而 Row 在 RTL 下会镜像——故视觉方向经文字方向映射到列下标。
    final step = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final dr = switch (dir) { TraversalDirection.up => -1, TraversalDirection.down => 1, _ => 0 };
    final dc = switch (dir) {
      TraversalDirection.left => -step,
      TraversalDirection.right => step,
      _ => 0,
    };
    var (r, c) = at;
    while (true) {
      r += dr;
      c += dc;
      if (r < -1 || c < -1 || r >= widget.rows.length || c >= widget.cols.length) return false;
      if (_navigable(r, c)) {
        final next = _cursorAt(r, c);
        setState(() => _cursor = next);
        // Focus the node EXPLICITLY — the thing skipTraversal exists to still allow. The focused node
        // carries the cell's sentence, which is what a screen reader reads on Windows/Linux; macOS
        // gets the announcement instead (see [_announce]).
        // **显式**聚焦——skipTraversal 保留的正是这一手。被聚焦的节点带着格的句子,Windows/Linux 读屏读的
        // 就是它;macOS 改由播报补上(见 _announce)。
        _nodeFor(next, cursor: true).requestFocus();
        _announce(_sentence(r, c));
        return true;
      }
    }
  }

  /// A click moves the cursor too (APG: the tab stop follows the last cell the user touched) — else
  /// tabbing back in would land somewhere the user never chose.
  /// 点击也挪光标(APG:tab 停靠跟着用户最后碰过的格)——否则 Tab 回来会落在用户从没选过的地方。
  void _cursorTo(_Cursor key) {
    if (_cursor == key) return;
    setState(() => _cursor = key);
  }

  /// What a position SAYS — one source for both the spoken node and the announcement, so the two can
  /// never drift apart. A cell's sentence carries its coordinate; a head's own label already says
  /// which run/node it is.
  /// 一个位置**说什么**:被念的节点与播报共用这一处,两者永不走散。格的句子带坐标;头的 label 本就说了它是
  /// 哪次 run / 哪个节点。
  String _sentence(int r, int c) {
    if (r < 0 && c < 0) return '';
    if (r < 0) return widget.colSemanticLabel?.call(widget.cols[c]) ?? '';
    if (c < 0) return widget.rowSemanticLabel?.call(widget.rows[r]) ?? '';
    final col = widget.cols[c];
    final row = widget.rows[r];
    return [
      widget.cellSemanticLabel?.call(col, row, widget.cellStatus(col.id, row.nodeId)) ?? '',
      widget.coordinateLabel?.call(r, widget.rows.length, c, widget.cols.length) ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
  }

  /// Speak the cursor's new address — **on macOS only, and that is not a preference**. The engine's
  /// mac bridge drops FOCUS_CHANGED into its «notifications that aren't meaningful on Mac» skip group
  /// (`AccessibilityBridgeMac.mm`), so a focused node is SILENT there — while Windows (`kFocus`) and
  /// Linux (`ATK_STATE_FOCUSED`) do fire it, and announcing on top of that would make the screen
  /// reader say everything twice (flutter#153020). So: the focused node is the mechanism, and this
  /// announcement is the macOS repair for it — not a second channel, a patch over a platform hole.
  /// `liveRegion` is NOT the fallback: it is a verified no-op on all three desktops (flutter#167318,
  /// still open). Nor is [MediaQuery.supportsAnnounceOf] the gate: that bit is inverted and only
  /// Android ever sets it, so it reports «supported» exactly where it cannot prove it.
  /// 念出光标的新地址——**只在 macOS,且这不是偏好**:引擎的 mac bridge 把 FOCUS_CHANGED 归进「在 Mac 上没有
  /// 意义、跳过即可」那组,故被聚焦的节点在那里**是哑的**;而 Windows/Linux 会发焦点通知,再叠一发播报会让
  /// 读屏把每样东西念两遍(flutter#153020)。所以:机制是**被聚焦的节点**,这一发播报是给 macOS 补的洞——
  /// 不是第二条通道,是一块平台补丁。**liveRegion 不是退路**:它在三个桌面上都实证是 no-op(flutter#167318
  /// 至今 OPEN)。**supportsAnnounceOf 也不是闸**:那个位是反向的、只有 Android 会设,故它恰恰在自己证明不了
  /// 的地方报「支持」。
  void _announce(String sentence) {
    if (sentence.isEmpty || defaultTargetPlatform != TargetPlatform.macOS) return;
    SemanticsService.sendAnnouncement(View.of(context), sentence, Directionality.of(context));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty || widget.cols.isEmpty) return const SizedBox.shrink();
    final at = _resolved;
    // Size-to-content, and scroll HORIZONTALLY only when the host is narrower than the grid. At the
    // full-bleed pane's real width (判决③ bought exactly this) 20 columns fit and this never scrolls;
    // a squeezed host (a narrow ocean, a gallery cell) degrades to a sideways scroll instead of a
    // RenderFlex overflow. The VERTICAL axis is deliberately left to the page — nesting a second
    // vertical scroll here would fight AnZonedPage's one true scroller.
    // 按内容定尺寸,**仅**在宿主比格阵窄时横向滚。全宽格的真实宽度下(判决③ 买的正是这个)20 列放得下、
    // 永不滚;被挤窄的宿主(窄海洋/画廊格)降级为横滚,而不是 RenderFlex 溢出。**纵轴刻意留给页面**——在此
    // 嵌第二个纵向滚动会与 AnZonedPage 唯一的滚动器打架。
    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _MatrixDirectionalFocusAction(this),
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _colHeads(context, at),
            for (var i = 0; i < widget.rows.length; i++) _row(context, i, at),
          ],
        ),
      ),
    );
  }

  int get _peakMs => widget.cols.fold<int>(0, (m, c) => (c.elapsedMs ?? 0) > m ? c.elapsedMs! : m);

  Widget _colHeads(BuildContext context, (int, int)? at) {
    final peak = _peakMs;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s4),
      child: Row(children: [
        const SizedBox(width: AnSize.ganttLaneW),
        for (var c = 0; c < widget.cols.length; c++) ...[
          const SizedBox(width: AnSpace.s4),
          _ColHead(
            // Identity, not slot — see the note on the cell's key. 跟身份不跟槽位,见格的 key 注释。
            key: ValueKey(widget.cols[c].id),
            col: widget.cols[c],
            peakMs: peak,
            selected: widget.selection.flowrunId == widget.cols[c].id,
            onTap: widget.onCol == null
                ? null
                : (id) {
                    _cursorTo((null, id));
                    widget.onCol!(id);
                  },
            runningLabel: widget.runningLabel,
            semanticLabel: widget.colSemanticLabel?.call(widget.cols[c]),
            focusNode: widget.onCol == null
                ? null
                : _nodeFor((null, widget.cols[c].id), cursor: at == (-1, c)),
          ),
        ],
      ]),
    );
  }

  Widget _row(BuildContext context, int r, (int, int)? at) {
    final row = widget.rows[r];
    final cells = [for (final col in widget.cols) widget.cellStatus(col.id, row.nodeId)];
    final summary = widget.rowSummaryLabel?.call(MatrixRowSummary(
      row: row,
      index: r,
      total: widget.rows.length,
      cells: cells,
    ));
    final body = Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s4),
      child: Row(children: [
        _RowHead(
          // Identity, not slot — see the note on the cell's key. 跟身份不跟槽位,见格的 key 注释。
          key: ValueKey(row.nodeId),
          row: row,
          selected: widget.selection.nodeId == row.nodeId,
          onTap: widget.onRow == null
              ? null
              : (id) {
                  _cursorTo((id, null));
                  widget.onRow!(id);
                },
          semanticLabel: widget.rowSemanticLabel?.call(row),
          focusNode: widget.onRow == null ? null : _nodeFor((row.nodeId, null), cursor: at == (r, -1)),
        ),
        for (var c = 0; c < widget.cols.length; c++) ...[
          const SizedBox(width: AnSpace.s4),
          () {
            final selected = widget.selection.flowrunId == widget.cols[c].id &&
                widget.selection.nodeId == row.nodeId;
            // Only the two squares worth a node build a sentence — the other 478 are silent, and
            // their coordinate is never computed for nobody. 只有值得节点的两格造句子。
            final speaks = at == (r, c) || selected;
            return _Cell(
              // The element must follow the CELL's identity, not its slot: a newer run prepends a
              // column, every unkeyed child shifts one place, and this cell's [FocusNode] would be
              // torn off its old element and re-attached to a new one — which unfocuses it. A grid
              // that drops the user's cursor whenever a run arrives is not «live», it is broken.
              // 元素必须跟着**格的身份**走而不是跟着槽位:新 run 前插一列,所有无 key 的孩子挪一位,本格的
              // FocusNode 会被从旧元素上撕下再贴到新元素上=**掉焦**。一有新 run 就把用户光标弄丢的格阵不是
              // 「活的」,是坏的。
              key: ValueKey((row.nodeId, widget.cols[c].id)),
              col: widget.cols[c],
              row: row,
              cell: cells[c],
              selected: selected,
              sentence: speaks ? _sentence(r, c) : null,
              onTap: widget.onCell == null
                  ? null
                  : (f, n) {
                      _cursorTo((n, f));
                      widget.onCell!(f, n);
                    },
              notReachedLabel: widget.notReachedLabel,
              focusNode: widget.onCell == null
                  ? null
                  : _nodeFor((row.nodeId, widget.cols[c].id), cursor: at == (r, c)),
            );
          }(),
        ],
      ]),
    );
    // The row's summary node groups the row and states its whole pattern. explicitChildNodes is
    // load-bearing — see the class doc. 行摘要节点为行成组并说出整行模式;explicitChildNodes 承重,见类文档。
    return summary == null || summary.isEmpty
        ? body
        : Semantics(container: true, explicitChildNodes: true, label: summary, child: body);
  }
}

/// Arrows move the CURSOR inside the grid, and hand back to the framework at the edge — the
/// `MenuAnchor` precedent (`material/menu_anchor.dart`'s `_SubmenuDirectionalFocusAction`), which is
/// the framework's own answer to «a widget that wants arrow keys without stealing them».
/// 方向键在格阵内挪**光标**,到边即交还框架——MenuAnchor 同款先例,那是框架对「想要方向键又不抢键」的自答。
class _MatrixDirectionalFocusAction extends DirectionalFocusAction {
  _MatrixDirectionalFocusAction(this.state);

  final _AnRunMatrixState state;

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (state._move(intent.direction)) return;
    // Off the edge: the default traversal takes the user OUT. Never trap. 出边:默认遍历送用户出去,绝不困住。
    super.invoke(intent);
  }
}

/// A column head: the run's duration sliver over its status tint. 列头:状态色底上的时长微条。
class _ColHead extends StatelessWidget {
  const _ColHead({
    required this.col,
    required this.peakMs,
    required this.selected,
    required this.runningLabel,
    this.onTap,
    this.semanticLabel,
    this.focusNode,
    super.key,
  });

  final RunColumn col;
  final int peakMs;
  final bool selected;
  final String runningLabel;
  final void Function(String flowrunId)? onTap;
  final String? semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tap = onTap;
    final ms = col.elapsedMs;
    // A settled run's bar is its share of the longest; an in-flight run has no share to take — it
    // gets the accent tint and the caller's «running» word instead of a fabricated length.
    // 落定 run 的条=它占最长的份额;在跑的 run 没有份额可占——给它 accent 色与调用方的「在跑」词,
    // 而不是一个编出来的长度。
    final fraction = ms == null || peakMs <= 0 ? null : (ms / peakMs).clamp(0.08, 1.0);
    final tip = [col.label, if (ms == null && runningLabel.isNotEmpty) runningLabel]
        .where((s) => s.isNotEmpty)
        .join('\n');

    // NOTE the `final` + separate name below: a builder closure captures the VARIABLE, not its value,
    // so `head = AnInteractive(builder: (..) => ...child: head)` would make the builder read the
    // reassigned `head` — i.e. itself — and recurse forever (a hang, not a crash; the test that taps
    // a head is what surfaced it). Never self-assign a widget that a closure closes over.
    // 注意下面的 final + 换名:builder 闭包捕获的是**变量**不是值,故 `head = AnInteractive(builder:
    // (..) => ...child: head)` 会让 builder 读到被重新赋值后的 head(=它自己)→ 无限递归(是**挂起**不是
    // 崩溃,靠点击列头的测试才现形)。绝不自赋值一个被闭包捕获的 widget。
    // `selected` rides ONE layer only — see the note in [_Cell]: two annotators split the node and
    // strand the label off the focusable one. selected 只由一层标注,理由见 _Cell 注释。
    final Widget bare = Semantics(
      label: semanticLabel,
      selected: onTap == null && selected ? true : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: AnSize.controlSm,
          height: AnSize.controlSm,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (fraction == null)
                Container(
                  height: AnSize.hairline * 3,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AnRadius.tag),
                  ),
                )
              else
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: AnSize.hairline * 3,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(AnRadius.tag),
                    ),
                  ),
                ),
              const SizedBox(height: AnSpace.s4),
              Container(
                height: AnSize.hairline * 2,
                width: AnSize.controlSm,
                decoration: BoxDecoration(
                  color: selected ? c.ink : c.line,
                  borderRadius: BorderRadius.circular(AnRadius.tag),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final Widget head = tap == null
        ? bare
        : AnInteractive(
            onTap: () => tap(col.id),
            focusNode: focusNode,
            selected: selected,
            builder: (context, states) => AnFocusRing(
              active: states.contains(WidgetState.focused),
              radius: AnRadius.tag,
              child: bare,
            ),
          );
    return tip.isEmpty ? head : AnTooltip(message: tip, child: head);
  }
}

/// A row head: the node's name, and the handle for its history. 行头:节点名 + 它历史的把手。
class _RowHead extends StatelessWidget {
  const _RowHead({
    required this.row,
    required this.selected,
    this.onTap,
    this.semanticLabel,
    this.focusNode,
    super.key,
  });

  final MatrixRowHead row;
  final bool selected;
  final void Function(String nodeId)? onTap;
  final String? semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tap = onTap;
    return SizedBox(
      width: AnSize.ganttLaneW,
      child: AnInteractive(
        onTap: tap == null ? null : () => tap(row.nodeId),
        focusNode: focusNode,
        selected: selected,
        builder: (context, states) => Semantics(
          label: semanticLabel,
          // One annotator only — see [_Cell]. 只由一层标注,见 _Cell。
          selected: tap == null && selected ? true : null,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
              height: AnSize.controlSm,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: selected
                    ? c.surfaceActive
                    : (states.isActive ? c.surfaceHover : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(AnRadius.tag),
              ),
              child: Row(children: [
                if (row.kind.isNotEmpty) ...[
                  Icon(AnIcons.node(row.kind), size: AnSize.iconSm, color: c.inkFaint),
                  const SizedBox(width: AnSpace.s6),
                ],
                Flexible(
                  child: Text(row.nodeId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.code.copyWith(color: c.inkMuted)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One (run, node) square. A MISSING cell is 「未及」 — a faint outline, never a filled colour: an
/// empty square must not be able to read as an outcome. 一格;缺席=「未及」淡描边,绝不填色——空格不得
/// 被读成一种结局。
class _Cell extends StatelessWidget {
  const _Cell({
    required this.col,
    required this.row,
    required this.cell,
    required this.selected,
    required this.notReachedLabel,
    this.sentence,
    this.onTap,
    this.focusNode,
    super.key,
  });

  final RunColumn col;
  final MatrixRowHead row;
  final MatrixCellState? cell;
  final bool selected;
  final String notReachedLabel;

  /// What this square says to a screen reader — null = it says NOTHING and carries no node at all
  /// (only the cursor and the selection speak; the row's summary speaks for the rest).
  /// 这个方块对读屏说什么;null=什么都不说、且完全不带节点(只有光标与选区说话,其余由行摘要代言)。
  final String? sentence;
  final void Function(String flowrunId, String nodeId)? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = cell;
    final tap = onTap;
    // Never defaults to done: an unknown status folds to idle (neutral), so a cell can never paint a
    // green success it never had. 绝不默认 done:未知折 idle 中性,格永不画它没有过的绿。
    final tone = s == null ? null : AnStatus.fromRaw(s.status).tone;

    final Widget box = Container(
      width: AnSize.controlSm,
      height: AnSize.controlSm,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone == null ? const Color(0x00000000) : tone.softBg(c),
        borderRadius: BorderRadius.circular(AnRadius.tag),
        border: Border.all(
          color: selected ? c.ink : (tone == null ? c.line : tone.fg(c)),
          width: selected ? AnSize.ring : AnSize.hairline,
        ),
      ),
      // «×N» rides IN the cell — the loop count is part of this outcome, not a separate mark.
      // ×N 就在格里——循环轮数是这个结局的一部分,不是另一个记号。
      child: s != null && s.iterations > 1
          ? Text('${s.iterations}', style: AnText.metaTabular().copyWith(color: tone!.fg(c)))
          : null,
    );

    // Only the two cells worth a node get one: the keyboard cursor and the caller's selection. Every
    // other square is silent — 480 flat nodes with no table structure to sit in is not «accessible»,
    // it is a wall (the row's summary is what speaks for them).
    // 只有值得一个节点的两格拿到节点:键盘光标 + 调用方选区。其余方块沉默——480 个无表格结构可依的扁平
    // 节点不是「可访问」,是一堵墙(替它们说话的是行摘要)。
    final speaks = sentence != null && sentence!.isNotEmpty;
    // `selected` is annotated by exactly ONE layer. Two [Semantics] setting the same flag are
    // INCOMPATIBLE configs, so the framework splits them into parent+child — which would strand the
    // label on a CHILD of the focused node instead of on it (measured in the semantics dump: the
    // label must ride the node that carries `isFocusable`, exactly like a stock button's does). So an
    // actionable cell hands `selected` to [AnInteractive] and annotates only its label here.
    // And `selected: false` is never written: it is not a synonym for «not selected» — the desktop
    // bridge passes the tristate into a bool parameter and kFlutterTristateFalse is 2, i.e. truthy,
    // so an explicit false reads as SELECTED. Absence is the only safe way to say «no».
    // `selected` **只由一层**标注:两个 Semantics 设同一面旗标是**不兼容**配置,框架会把它们拆成父+子——那会
    // 让 label 落在被聚焦节点的**孩子**上而不是它自己身上(语义树 dump 实测:label 必须与 isFocusable 同节点,
    // 一如原装按钮)。故可动作的格把 selected 交给 AnInteractive,这里只标 label。且**绝不写 selected: false**
    // ——它不是「未选中」的同义词:桌面 bridge 把 tristate 塞进 bool 形参而 kFlutterTristateFalse=2 是真值,
    // 显式 false 会被读成**已选中**。说「否」唯一安全的方式是不说。
    final Widget bare = speaks
        ? Semantics(
            label: sentence,
            selected: tap == null && selected ? true : null,
            child: ExcludeSemantics(child: box),
          )
        : ExcludeSemantics(child: box);

    // «未及» belongs to ABSENCE only. A present cell whose caller passed no label says NOTHING —
    // falling back to the not-reached word here would make a completed run claim it never ran (the
    // exact inversion of the truth this grid exists to show).
    // 「未及」只属于**缺席**。有格但调用方没给 label 就什么都不说——在此回落到未及词,会让一次跑完的 run
    // 声称自己从没跑过(恰是本格阵存在意义的反面)。
    final tip = s == null ? notReachedLabel : s.label;
    final Widget square = tap == null
        ? bare
        : AnInteractive(
            onTap: () => tap(col.id, row.nodeId),
            focusNode: focusNode,
            selected: selected,
            builder: (context, states) => AnFocusRing(
              active: states.contains(WidgetState.focused),
              radius: AnRadius.tag,
              child: bare,
            ),
          );
    final Widget out = tip.isEmpty ? square : AnTooltip(message: tip, child: square);
    // The exclusion has to wrap the WHOLE cell, not just its box: [AnInteractive] and [AnTooltip]
    // annotate semantics of their own, so excluding only the inside still leaves one unlabelled
    // BUTTON node per square — a wall of 480 anonymous buttons, which is worse than 480 labelled ones,
    // not better (the dump measured 575 nodes before this line existed, and ~75 after).
    // 排除必须包住**整格**而不只是它的盒:AnInteractive 与 AnTooltip 各自也标语义,只排里面会让每个方块仍留
    // 一个**无 label 的按钮**节点——480 个无名按钮的墙,比 480 个有名的更糟而不是更好(加这行前 dump 实测
    // 575 节点,之后约 75)。
    return ExcludeSemantics(excluding: !speaks, child: out);
  }
}
