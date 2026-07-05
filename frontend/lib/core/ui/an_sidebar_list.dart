import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/sidebar_flatten.dart';
import '../model/sidebar_model.dart';
import 'an_button.dart';
import 'an_inline_edit.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'an_menu.dart';
import 'an_row.dart';
import 'an_scroll_behavior.dart';
import 'an_status_dot.dart';
import 'icons.dart';

/// Where a dragged row lands relative to the row under the pointer — the row divides into a top-quarter
/// (insert BEFORE, as a sibling), a bottom-quarter (insert AFTER), and the middle half (nest INSIDE as a
/// child) — the Notion tree-drop model. 拖拽落点:行分上¼(前插兄弟)/下¼(后插)/中½(嵌入为子)——Notion 树落点模型。
enum AnRowDropZone { above, below, inside }

/// C5 — the left-rail sidebar list. A fixed New row + in-domain filter (with a sliders menu) sit above a
/// VIRTUALIZED body: [flattenSidebar] flattens the groups→types→rows tree by the current fold + filter
/// state into one flat list, rendered by a fixed-extent [SliverList] (only visible rows build — 5000-row
/// sections stay smooth). A Stack overlay pins the DYNAMIC ANCESTOR CHAIN of the top-most visible row
/// (VS Code sticky-scroll): a flat section pins one head, a deep tree pins the whole branch chain, capped.
/// Fold state keys on the flat node's STABLE SEMANTIC key (id/pageKey/label — never positional, so a
/// conditionally-emitted section can't fuse fold state with a sibling). Rows ride [AnRow]; the edited row
/// swaps to the reused [AnInlineEdit]; a paginated section drives [onLoadMore] via a tail footer.
///
/// **Tree drag-reorder (opt-in via [onRowDropped])**: rows become [Draggable]s (pointer-anchored so the
/// drop-zone math is exact) + [DragTarget]s. The hovered row paints an accent INSERTION LINE (above/below)
/// or a rounded accentSoft NEST highlight (inside); hovering a collapsed branch's middle auto-expands it
/// after a beat (Notion). The primitive guards the visually-obvious invalids — self, the dragged row's own
/// subtree (a cycle), rows [canDragRow] excludes — and NORMALIZES "below an open branch" to "above its
/// first child" (that's where the line visually sits), so the host's position math needs no fold state.
/// The HOST owns the real move (validation + `:move` + refetch). Drag is desktop-mouse only by design —
/// wheel/trackpad scrolling is untouched (no touch-scroll conflict on this target).
///
/// C5——左岛侧栏。固定 New 行 + 域内过滤 在上;下方 VIRTUALIZED 主体:flattenSidebar 把 groups→types→rows 树按当前折叠
/// +过滤态展平成一维,定高 SliverList 渲染(只建可见行,5000 行段不卡)。Stack overlay 吸顶「顶部行的动态祖先链」
/// (VS Code sticky-scroll):扁平段吸一层头、深树吸整条分支链(封顶)。折叠键按稳定语义键(id/pageKey/label、非位置)。
/// 行搭 AnRow;编辑行换 AnInlineEdit;分页段经尾 footer 驱动 onLoadMore。
/// **树内拖拽重排(经 [onRowDropped] 可选启用)**:行成 Draggable(指针锚定、落区判定精确)+ DragTarget;悬停行画
/// accent 插入线(上/下)或圆角 accentSoft 嵌入高亮(中);悬停折叠枝中段片刻自动展开(Notion)。原语守视觉级非法
/// (自身/自子树成环/canDragRow 排除),并把「开枝之下」归一成「其首子之上」(线就画在那)——宿主算位置无需折叠态;
/// 真移动(校验 + `:move` + 重取)归宿主。拖拽仅桌面鼠标——滚轮/触控板滚动不受影响。
class AnSidebarList extends StatefulWidget {
  const AnSidebarList({
    required this.model,
    this.selectedId,
    this.onSelect,
    this.onNew,
    this.onFilterChanged,
    this.onLoadMore,
    this.onRetryLoad,
    this.menuEntries = const [],
    this.showNew = true,
    this.rowActionsBuilder,
    this.labelWidgetFor,
    this.editingRowId,
    this.onRenameCommit,
    this.onRenameCancel,
    this.onRowDropped,
    this.canDragRow,
    super.key,
  });

  final SidebarModel model;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onNew;
  final ValueChanged<String>? onFilterChanged;

  /// A paginated section ([SidebarType.pageKey] != null) scrolled to its tail fires this with the pageKey.
  /// 分页段(pageKey 非空)滚到尾时携 pageKey 触发。
  final void Function(String pageKey)? onLoadMore;

  /// The tail footer's retry (after a load error) fires this with the pageKey. 尾 footer 重试携 pageKey 触发。
  final void Function(String pageKey)? onRetryLoad;

  /// Sliders (Sort / Display) menu entries; empty → no sliders anchor. sliders 菜单项,空则不渲。
  final List<AnMenuEntry> menuEntries;
  final bool showNew;

  /// Optional trailing actions per row (e.g. a ⋯ menu), keyed by row id. 行尾动作(⋯ 菜单),按 id。
  final List<Widget> Function(String rowId)? rowActionsBuilder;

  /// Optional per-row label OVERRIDE widget (e.g. a one-shot typewriter while a fresh auto-title lands);
  /// null → the row's static label. The MODEL stays pure (no widgets in SidebarRow) — overrides live at
  /// the render layer, keyed by row id. 行 label 覆盖件(如自动命名首落的打字机);null=静态 label。模型保持纯
  /// (SidebarRow 不进 Widget)——覆盖在渲染层按 id 查。
  final Widget? Function(String rowId)? labelWidgetFor;

  /// In-place rename: the row with this id renders an [AnInlineEdit] in its label slot instead of the
  /// static [AnRow]. The host owns this id + clears it on commit/cancel. 就地改名:此 id 行渲 AnInlineEdit。
  final String? editingRowId;
  final void Function(String id, String value)? onRenameCommit;
  final VoidCallback? onRenameCancel;

  /// Non-null ENABLES tree drag-reorder. Fired on a valid drop with the dragged row id, the target row id
  /// and the [AnRowDropZone] ("below an open branch" arrives normalized to "above its first child"). The
  /// host validates + performs the actual move. null → rows aren't draggable (zero overhead).
  /// 非空即启用树内拖拽。落下时携(拖行 id, 目标行 id, 落区)——「开枝之下」已归一成「首子之上」;真移动归宿主。
  final void Function(String draggedId, String targetId, AnRowDropZone zone)? onRowDropped;

  /// Which rows participate (as drag SOURCE and drop TARGET). null → all rows, when drag is enabled.
  /// 哪些行参与(既是拖源也是落点);null=全部(启用时)。
  final bool Function(String rowId)? canDragRow;

  @override
  State<AnSidebarList> createState() => _AnSidebarListState();
}

/// How many ancestor heads may stack in the sticky overlay before a deep tree would eat the viewport
/// (VS Code's maxLineCount). 吸顶祖先最多堆几层(仿 VS Code maxLineCount)。
const int _maxSticky = 4;

class _AnSidebarListState extends State<AnSidebarList> {
  final TextEditingController _filter = TextEditingController();
  final Set<String> _collapsed = {}; // collapsed fold keys (default: all open) 折叠键(默认全开)
  final ScrollController _scroll = ScrollController();
  String _query = '';

  // ── tree drag-reorder state 树内拖拽态 ──
  String? _dragId; // the row being dragged 拖动中的行
  Set<String> _dragSubtree = const {}; // its descendant ids (cycle guard) 其子孙 id(防环)
  String? _dropRowId; // the hovered valid target 悬停中的合法落点行
  AnRowDropZone? _dropZone;
  Timer? _hoverExpand; // dwell-to-expand a collapsed branch 悬停片刻自动展开折叠枝
  EdgeDraggingAutoScroller? _autoScroller; // edge auto-scroll while dragging 拖拽近缘自动滚

  // The flattened list is HELD (not recomputed inline) so its indices stay in lock-step with the
  // SliverAnimatedList's: a user toggle animates a precise sub-range; a model/query change rebuilds it
  // fresh under a new key. 展平列表被持有(非内联重算),使 index 与 SliverAnimatedList 锁步:toggle 动画精确子区间;
  // model/query 变则换 key 重建。
  late List<SidebarFlatNode> _flat;
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();

  // Branch END index per head key (exclusive: the first row that LEAVES the branch) — precomputed
  // O(n) whenever _flat rebuilds, so the sticky push is an O(1) lookup per frame. Depth CANNOT delimit
  // a branch (a section head's rows share its depth — the old per-frame depth scan made every in-section
  // row a pusher, so the pinned head "tumbled" one slot per row scrolled).
  // 每头的分支结束 index(排他:第一个离开分支的行)——_flat 重建时 O(n) 预计算,吸顶推头每帧 O(1) 查表。
  // depth 界定不了分支(段头的行与其同深——旧的逐帧 depth 扫描把段内每行都当推头者,头每滚一行翻滚一次)。
  Map<String, ({int start, int end})> _branchSpan = const {};

  Map<String, ({int start, int end})> _computeBranchSpans(List<SidebarFlatNode> flat) {
    final spans = <String, ({int start, int end})>{};
    final stack = <(SidebarFlatNode, int)>[]; // open branch heads + their index 开着的分支头及其 index
    for (var i = 0; i < flat.length; i++) {
      final anc = flat[i].ancestors;
      while (stack.isNotEmpty && !anc.contains(stack.last.$1)) {
        final (h, at) = stack.removeLast();
        spans[h.key] = (start: at, end: i);
      }
      if (flat[i].isBranch) stack.add((flat[i], i));
    }
    for (final (h, at) in stack) {
      spans[h.key] = (start: at, end: flat.length); // runs to the end — never pushed 到底,永不被推
    }
    return spans;
  }

  @override
  void initState() {
    super.initState();
    _flat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
    _branchSpan = _computeBranchSpans(_flat);
  }

  @override
  void didUpdateWidget(AnSidebarList old) {
    super.didUpdateWidget(old);
    // A model change (loadMore append / SSE patch / sort) rebuilds instantly — the fold TWEEN is only for
    // user toggles, not data churn. model 变(loadMore/SSE/sort)瞬时重建——折叠补间只给用户 toggle。
    if (!identical(old.model, widget.model)) _rebuildFlat();
  }

  void _rebuildFlat() {
    _flat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
    _branchSpan = _computeBranchSpans(_flat);
    _listKey = GlobalKey(); // a new key drops any stale animated-list index state → fresh initialItemCount
    // A mid-drag model rebuild: the hover indicator is stale (rows re-keyed) and the dragged row's subtree
    // may have changed — drop the indicator, recompute the cycle guard against the NEW model. The drag
    // itself survives (the SDK keeps the recognizer alive across the source row's unmount).
    // 拖拽中模型重建:悬停指示已陈旧(行换键)、被拖行子树可能已变——撤指示、按新 model 重算防环;拖拽本身存活
    // (SDK 让识别器跨源行 unmount 存续)。
    if (_dragId != null) {
      _hoverExpand?.cancel();
      _dropRowId = null;
      _dropZone = null;
      _dragSubtree = _subtreeIds(_dragId!);
    }
  }

  @override
  void dispose() {
    _hoverExpand?.cancel();
    _filter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Fold/unfold a branch. The head + descendants are a contiguous range in _flat; a collapse removes that
  // range with a size tween (reverse order so indices stay valid), an expand re-flattens + inserts the new
  // descendants — keeping _flat and the SliverAnimatedList in lock-step.
  // 折叠/展开分支。头+子孙在 _flat 是连续区间;折叠倒序移除该区间(index 保持有效)、展开重展平+插入,使二者锁步。
  void _toggle(String key) {
    final headIdx = _flat.indexWhere((n) => n.key == key);
    if (headIdx < 0) return;
    final state = _listKey.currentState;
    final dur = AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid;

    // The head's descendants are the CONTIGUOUS range that appears/disappears when the key flips — a
    // re-flatten differs from the current list ONLY by that range's length (depth alone can't delimit it,
    // since a section head's rows share its depth). 头的子孙是 key 翻转时增删的连续区间:重展平与当前只差该区间长度
    // (depth 无法界定——段头的行与其同深)。
    if (!_collapsed.contains(key)) {
      _collapsed.add(key);
      final newFlat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
      final removedCount = _flat.length - newFlat.length;
      final removed = _flat.sublist(headIdx + 1, headIdx + 1 + removedCount);
      _flat = newFlat;
      _branchSpan = _computeBranchSpans(_flat);
      for (var i = headIdx + removedCount; i > headIdx; i--) {
        final node = removed[i - headIdx - 1];
        state?.removeItem(i, (context, animation) => _animatedRow(context, node, animation), duration: dur);
      }
    } else {
      _collapsed.remove(key);
      final newFlat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
      final insertCount = newFlat.length - _flat.length;
      _flat = newFlat;
      _branchSpan = _computeBranchSpans(_flat);
      for (var i = headIdx + 1; i <= headIdx + insertCount; i++) {
        state?.insertItem(i, duration: dur);
      }
    }
    setState(() {}); // refresh the toggled head's chevron
  }

  bool _open(String key) => _query.trim().isNotEmpty || !_collapsed.contains(key); // a query force-opens

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showNew) _newRow(),
        _filterRow(context),
        Expanded(
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: const AnScrollBehavior(),
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverAnimatedList(
                      key: _listKey,
                      initialItemCount: _flat.length,
                      itemBuilder: (context, index, animation) =>
                          _animatedRow(context, _flat[index], animation),
                    ),
                  ],
                ),
              ),
              // The sticky ancestor overlay rebuilds EACH FRAME off the scroll position (AnimatedBuilder on
              // the controller), so the nearest head follows the finger + is pushed out by the next
              // sibling-level row — without rebuilding the virtualized list. During a DRAG it goes
              // pointer-transparent: its opaque copies aren't drop targets, so they'd swallow drops (and
              // hide indicators) near the top — hits must fall through to the real rows underneath.
              // 吸顶 overlay 每帧跟滚动重建(跟手推走),不重建列表。拖拽中变指针透明:opaque 副本不是落点,
              // 会吞掉顶部落下(并遮指示)——命中须穿透到其下真行。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: _dragId != null,
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) => _stickyOverlay(context, _flat),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // The dynamic ancestor sticky overlay: the ancestor chain of the top-most visible row, pinned at the top
  // (fixed row height → offset ÷ rowH = the top index, exactly). The NEAREST head follows the finger +
  // is pushed out by the first row after it that leaves its branch (depth ≤ the head's) scrolling up into
  // the stack's bottom — VS Code sticky-scroll. Computed each frame off the scroll offset.
  //
  // 动态祖先吸顶:顶部行的祖先链吸顶(定高→offset÷行高=顶部 index 精确)。最近头跟手 + 被其后第一个离开本分支
  // (depth ≤ 头深)的行顶到栈底时推出——VS Code sticky-scroll。每帧按 offset 算。
  Widget _stickyOverlay(BuildContext context, List<SidebarFlatNode> flat) {
    if (flat.isEmpty || !_scroll.hasClients) return const SizedBox.shrink();
    final off = _scroll.offset;
    final top = (off / AnSize.row).floor().clamp(0, flat.length - 1);
    // The chain pins the top row's ancestors AND the top row itself when it IS a head: the head
    // pins the moment it reaches the top (content dives under it) instead of scrolling out one row
    // and popping back as a sticky — the VS Code / iOS-sections behaviour.
    // 链=顶行祖先 + 顶行自身(若是头):头一到顶即钉住(内容从其下钻过),而非滚出一行再跳回。
    final node = flat[top];
    final chain = [...node.ancestors, if (node.isBranch) node].take(_maxSticky).toList();
    // A head needs a sticky COPY only once its OWN row has scrolled past its pin slot — before that
    // the in-list row IS at (or below) the slot, and a copy would double it (semantics + paint).
    // Because (index − slot) is non-decreasing down the chain, the skipped layers are always a
    // SUFFIX — the rendered prefix keeps the slot stack hole-free.
    // 头只在**本体滚过其钉住槽位**后才需要副本——此前本体就在槽位(或其下),副本=双份(语义+绘制)。
    // (index − 槽号)沿链非降 ⇒ 被跳过的层恒为后缀,渲染前缀的槽栈无洞。
    final sticky = <SidebarFlatNode>[];
    for (var i = 0; i < chain.length; i++) {
      final span = _branchSpan[chain[i].key];
      if (span == null || span.start * AnSize.row - off >= i * AnSize.row) break;
      sticky.add(chain[i]);
    }
    if (sticky.isEmpty) return const SizedBox.shrink();

    final stackBottom = sticky.length * AnSize.row;
    // Per-layer push (VS Code cascade): a head is pushed up ONLY when the first row that leaves its
    // branch (the precomputed branch END — depth can't delimit it, in-section rows share the head's
    // depth) scrolls up to meet the bottom of ITS slot; the deepest head goes first.
    // 每层各自推:仅当**预计算的分支结束行**(depth 界定不了——段内行与头同深)顶到其槽底时才推;最深先走。
    final pushUps = List<double>.filled(sticky.length, 0.0);
    for (var i = 0; i < sticky.length; i++) {
      final end = _branchSpan[sticky[i].key]?.end ?? flat.length;
      if (end >= flat.length) continue; // branch runs to the list end — never pushed 到底不推
      final slot = (i + 1) * AnSize.row;
      final rowTop = end * AnSize.row - off;
      if (rowTop < slot) pushUps[i] = rowTop - slot;
    }

    return SizedBox(
      height: stackBottom,
      child: Stack(
        children: [
          // NO full-slot backing: each sticky row carries its OWN opaque surface and moves with its
          // push — a pushed-out head must reveal the list row rising underneath (that row IS the
          // successor doing the pushing; a static slot-wide backing hid it, so the handover read as
          // "slide out, blank, pop in" instead of one head shoving the other).
          // **不要整槽静态白底**:每个吸顶行自带 opaque 面、随各自 push 移动——被推出的头必须露出
          // 其下正在升起的列表行(那正是来顶它的接替头;静态整槽底把它盖住,交接就成了
          // 「滑出→空白→突现」而非「一个把另一个顶走」)。
          // Deep-to-shallow paint order (VS Code's z-index semantics): the DEEPEST layer is pushed
          // first, and it must slide out UNDER the shallower heads above it — so shallower layers
          // paint later (on top). The Stack's hardEdge clip crops the slid-out part (VS Code's
          // overflow:hidden). 深→浅绘制(VS Code z 序):最深层先被推,须从浅层**底下**滑出——浅层后画
          // (在上)。Stack hardEdge 裁掉滑出部分(同 overflow:hidden)。
          for (var i = sticky.length - 1; i >= 0; i--)
            Positioned(
              top: i * AnSize.row + pushUps[i],
              left: 0,
              right: 0,
              child: _flatRow(context, sticky[i], sticky: true),
            ),
        ],
      ),
    );
  }

  // New: rides AnRow (lead = +, label) so it shares the entity rows' geometry / hover / radius. New 行复用 AnRow。
  Widget _newRow() => AnRow(icon: AnIcons.plus, label: widget.model.newLabel, onSelect: widget.onNew);

  // Filter: lead = search, an inline seamless input, a trailing sliders menu. 过滤行。
  Widget _filterRow(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AnSize.row,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
      child: Row(
        children: [
          Icon(AnIcons.search, size: AnSize.icon, color: c.inkFaint),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: AnInput(
              controller: _filter,
              seamless: true,
              placeholder: widget.model.filterPlaceholder,
              onChanged: (v) {
                setState(() {
                  _query = v;
                  _rebuildFlat();
                });
                widget.onFilterChanged?.call(v);
              },
            ),
          ),
          if (widget.menuEntries.isNotEmpty)
            AnMenu(
              entries: widget.menuEntries,
              anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(AnIcons.sliders,
                  size: AnButtonSize.sm, semanticLabel: context.t.a11y.displayOptions, onPressed: toggle),
            ),
        ],
      ),
    );
  }

  // Wraps a row in the SliverAnimatedList's size tween so a collapse/expand slides the row's height (the
  // children slide up under their head; axisAlignment -1 anchors to the top). 折叠补间:行高滑动(-1 顶锚)。
  Widget _animatedRow(BuildContext context, SidebarFlatNode n, Animation<double> animation) =>
      SizeTransition(sizeFactor: animation, axisAlignment: -1, child: _flatRow(context, n));

  Widget _flatRow(BuildContext context, SidebarFlatNode n, {bool sticky = false}) {
    switch (n.kind) {
      case SidebarNodeKind.groupHead:
        return _groupHead(context, n, sticky: sticky);
      case SidebarNodeKind.typeHead:
        return _typeHead(context, n, sticky: sticky);
      case SidebarNodeKind.row:
        return _entityRow(context, n, sticky: sticky);
      case SidebarNodeKind.footer:
        return _footer(context, n);
    }
  }

  // A collapsible chat-style big-group head: gray emphasis label + total count + rotating chevron. Sticky
  // → opaque surface so list rows scroll under it. 可折叠大组头:灰加粗 label + 总计数 + 转 chevron;sticky→opaque。
  Widget _groupHead(BuildContext context, SidebarFlatNode n, {bool sticky = false}) {
    final c = context.colors;
    final g = n.group!;
    final open = _open(n.key);
    return AnInteractive(
      onTap: () => _toggle(n.key),
      expanded: open,
      builder: (ctx, states) => Container(
        height: AnSize.row,
        color: sticky ? c.surface : c.surfaceHover.whenActive(states.isActive),
        padding: EdgeInsets.only(left: AnSpace.s8 + n.depth * AnSize.iconLg, right: AnSpace.s12),
        child: Row(
          children: [
            Flexible(
              child: Text(g.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
            ),
            const SizedBox(width: AnSpace.s6),
            Text('${g.totalRows}',
                style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
            const Spacer(),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
              curve: AnMotion.spring,
              child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  // A section head (icon + label + count) — the entities kind sections, chat pinned/recents. It's a
  // disclosure button: the whole head toggles (keyboard-operable, not a mouse-only lead chevron). Rides
  // AnRow; sticky → wrapped opaque. 段头(icon+label+count):整头折叠(键盘可达);搭 AnRow;sticky→opaque 包裹。
  Widget _typeHead(BuildContext context, SidebarFlatNode n, {bool sticky = false}) {
    final t = n.type!;
    final open = _open(n.key);
    final row = AnRow(
      depth: n.depth,
      icon: t.icon,
      label: t.label ?? '',
      meta: t.count != null ? '${t.count}' : null,
      collapsible: true,
      open: open,
      onSelect: () => _toggle(n.key),
      onToggle: () => _toggle(n.key),
    );
    return sticky ? _opaque(context, row) : row;
  }

  // A recursive entity row (leaf or branch). The edited row swaps to the rename primitive. Sticky (a
  // branch ancestor) → wrapped opaque. A drag-enabled row wraps in the Draggable + DragTarget pair.
  // 实体行(叶/树枝);编辑行换改名件;sticky(树枝祖先)→opaque;启用拖拽的行包 Draggable+DragTarget。
  Widget _entityRow(BuildContext context, SidebarFlatNode n, {bool sticky = false}) {
    final r = n.row!;
    if (!sticky && r.id == widget.editingRowId) return _editingRow(context, n);
    final branch = r.hasChildren;
    final open = _open(n.key);
    final row = AnRow(
      depth: n.depth,
      icon: r.dot == null ? r.icon : null,
      dot: r.dot,
      label: r.label,
      labelWidget: widget.labelWidgetFor?.call(r.id),
      hint: r.hint,
      meta: r.meta,
      selected: r.id == widget.selectedId,
      collapsible: branch,
      open: open,
      onSelect: () => widget.onSelect?.call(r.id),
      onToggle: branch ? () => _toggle(n.key) : null,
      actions: widget.rowActionsBuilder?.call(r.id) ?? const [],
    );
    if (sticky) return _opaque(context, row);
    // Rows inside the subtree being dragged ride along: dimmed + inert (they move as one unit with their
    // head — hover tints / row actions there would lie). 被拖子树内的行随行:变暗+惰性(与头一体,悬停/动作会撒谎)。
    if (_dragId != null && _dragSubtree.contains(r.id)) {
      return IgnorePointer(child: Opacity(opacity: 0.35, child: row));
    }
    if (!_rowDraggable(r.id)) return row;
    return _draggableRow(context, n, row);
  }

  // ── tree drag-reorder 树内拖拽 ──

  /// Drag is OFF while the filter query is active: the query force-expands branches and HIDES non-matching
  /// rows, so both the drop indicators and the host's position math would lie about where things land
  /// (Notion also disables tree reorder in filtered views). 过滤时禁拖:query 强展开+藏行,指示与位置计算都会撒谎。
  bool get _dragEnabled => widget.onRowDropped != null && _query.trim().isEmpty;
  bool _rowDraggable(String id) => _dragEnabled && (widget.canDragRow?.call(id) ?? true);

  /// A valid drop target: not the dragged row itself, not inside its own subtree (a cycle), and a
  /// participating row. 合法落点:非自身、非自子树(成环)、且是参与行。
  bool _validTarget(String targetId) =>
      _dragId != null && targetId != _dragId && !_dragSubtree.contains(targetId) && _rowDraggable(targetId);

  /// The dragged row's descendant ids, from the MODEL (collapsed children aren't in [_flat]). 子孙 id 取自 model。
  Set<String> _subtreeIds(String id) {
    SidebarRow? found;
    void findIn(List<SidebarRow> rows) {
      for (final r in rows) {
        if (found != null) return;
        if (r.id == id) {
          found = r;
          return;
        }
        findIn(r.children);
      }
    }

    for (final g in widget.model.groups) {
      for (final t in g.types) {
        findIn(t.rows);
        if (found != null) break;
      }
      if (found != null) break;
    }
    final out = <String>{};
    void collect(SidebarRow r) {
      for (final c in r.children) {
        out.add(c.id);
        collect(c);
      }
    }

    if (found != null) collect(found!);
    return out;
  }

  /// Pointer position → the zone within the hovered row, from the ROW'S OWN RenderBox (exact even while a
  /// fold SizeTransition is tweening heights above — a fixed-grid modulo would misclassify then). The drag
  /// is pointer-anchored ([pointerDragAnchorStrategy]) so [globalPointer] IS the pointer, exactly.
  /// 指针→行内落区:用**行自身** RenderBox(上方折叠补间进行中也精确——网格取模那时会判错);拖拽指针锚定,全局点即指针。
  AnRowDropZone _zoneAt(BuildContext rowContext, Offset globalPointer) {
    final box = rowContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.height <= 0) return AnRowDropZone.inside;
    final within = box.globalToLocal(globalPointer).dy;
    if (within < box.size.height / 4) return AnRowDropZone.above;
    if (within > box.size.height * 3 / 4) return AnRowDropZone.below;
    return AnRowDropZone.inside;
  }

  void _updateDrop(SidebarFlatNode n, BuildContext rowContext, Offset globalPointer) {
    // Edge auto-scroll: nudge the list when the pointer nears the viewport's top/bottom so off-screen
    // targets are reachable (Flutter's own reorderable-list helper). 近缘自动滚,屏外落点可达(官方 helper)。
    final scrollable = Scrollable.maybeOf(rowContext);
    if (scrollable != null) {
      // velocityScalar 50 = ReorderableList's own default. 50=官方 ReorderableList 默认。
      (_autoScroller ??= EdgeDraggingAutoScroller(scrollable, velocityScalar: 50)).startAutoScrollIfNecessary(
        Rect.fromCenter(center: globalPointer, width: 1, height: AnSize.row * 2),
      );
    }
    final zone = _zoneAt(rowContext, globalPointer);
    final id = n.row!.id;
    if (_dropRowId == id && _dropZone == zone) return;
    setState(() {
      _dropRowId = id;
      _dropZone = zone;
    });
    // Dwelling on a collapsed branch's middle auto-expands it so its children become targets (Notion).
    // 悬停折叠枝中段片刻自动展开,让其子成为落点(Notion)。
    _hoverExpand?.cancel();
    if (zone == AnRowDropZone.inside && n.isBranch && !_open(n.key)) {
      _hoverExpand = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _dropRowId == id && !_open(n.key)) _toggle(n.key);
      });
    }
  }

  void _clearDrop(String rowId) {
    _hoverExpand?.cancel();
    if (_dropRowId == rowId) {
      setState(() {
        _dropRowId = null;
        _dropZone = null;
      });
    }
  }

  /// End-of-drag cleanup, shared + idempotent. Wired to onDragCompleted AND onDraggableCanceled — the SDK
  /// calls those even when the source row's State was unmounted mid-drag (a model rebuild re-keys the list;
  /// scrolling can recycle the row), whereas onDragEnd is mounted-guarded and gets SKIPPED then, which
  /// would leak a stuck indicator + a live dwell timer. The closure's `this` is the LIST state, which
  /// outlives any row. 拖拽收尾(共享、幂等):挂 onDragCompleted+onDraggableCanceled——源行 State 中途被 unmount
  /// (模型重建换键/滚动回收)时 SDK 仍会调它们,而 onDragEnd 有 mounted 守卫会被跳过→泄漏卡死指示+活定时器。
  /// 闭包的 this 是列表 State,比任何行都长寿。
  void _endDrag() {
    _hoverExpand?.cancel();
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    if (!mounted) return;
    if (_dragId == null && _dropRowId == null) return;
    setState(() {
      _dragId = null;
      _dragSubtree = const {};
      _dropRowId = null;
      _dropZone = null;
    });
  }

  /// Whether a below-zone drop on [n] lands as its FIRST CHILD (the branch is open, so the line below its
  /// head visually sits above its first child). Shared by the indicator painter and [_emitDrop] so the
  /// pixels and the emitted intent can never drift. 「下落区是否落为其首子」:开枝头的下缘线视觉上就在首子之上;
  /// 指示绘制与派发共用此判定,像素与意图不漂移。
  bool _belowNestsAsFirstChild(SidebarFlatNode n) => n.row!.hasChildren && _open(n.key);

  /// Resolve + emit a drop. "Below an OPEN branch" is normalized to "above its first child" — and if that
  /// normalization lands on the dragged row itself (dragging a branch's first child onto its parent's
  /// bottom edge), the drop is an identity move: emit nothing. 解析并派发:「开枝之下」归一成「首子之上」;
  /// 归一后若正是被拖行自身(拖首子到父行下缘),是恒等移动——不派发。
  void _emitDrop(SidebarFlatNode n, String draggedId) {
    var targetId = n.row!.id;
    var zone = _dropZone ?? AnRowDropZone.inside;
    if (zone == AnRowDropZone.below && _belowNestsAsFirstChild(n)) {
      targetId = n.row!.children.first.id;
      zone = AnRowDropZone.above;
    }
    if (targetId == draggedId) return;
    widget.onRowDropped!(draggedId, targetId, zone);
  }

  /// The Draggable + DragTarget wrap around a row: pointer-anchored drag (exact zone math off the row's
  /// own box, via the Builder-captured context), a floating name-chip feedback, the origin row dimmed in
  /// place (no mid-drag reflow in the virtualized list), and the drop indicators — an accent insertion
  /// line straddling the row edge, or a rounded accentSoft nest veil painted OVER the row (the row's own
  /// hover/selection fill is opaque; painted under, the veil would vanish exactly on the selected row).
  /// A below-line that will NEST (open branch → first child) draws at the CHILD indent, exactly where the
  /// drop lands. 行的拖拽包裹:指针锚定 + Builder 捕获行自身盒做落区判定 + 名签浮标 + 原行原位变暗 + 落点指示
  /// (贴缘 accent 插入线 / 盖在行上的 accentSoft 嵌入纱——行自身悬停/选中底不透明,垫底会在选中行上消失)。
  /// 会归一成嵌入的下缘线按**子层缩进**画——线在哪、落哪。
  Widget _draggableRow(BuildContext context, SidebarFlatNode n, Widget row) {
    final r = n.row!;
    final c = context.colors;
    final zone = (_dragId != null && _dropRowId == r.id) ? _dropZone : null;
    final indent = AnSpace.s8 + n.depth * AnSize.iconLg;
    // The below-line indents one level deeper when the drop will land as the branch's first child —
    // the shared predicate keeps the pixels and _emitDrop in lock-step. 下缘线在将嵌入时深一层缩进(共享判定)。
    final belowIndent =
        _belowNestsAsFirstChild(n) ? AnSpace.s8 + (n.depth + 1) * AnSize.iconLg : indent;

    final target = Builder(
      builder: (rowContext) => DragTarget<String>(
        onWillAcceptWithDetails: (d) => _validTarget(r.id),
        onMove: (d) {
          if (_validTarget(r.id)) _updateDrop(n, rowContext, d.offset);
        },
        onLeave: (_) => _clearDrop(r.id),
        onAcceptWithDetails: (d) => _emitDrop(n, d.data),
        builder: (context, candidates, rejected) => Stack(
          clipBehavior: Clip.none,
          children: [
            row,
            if (zone == AnRowDropZone.inside)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(AnRadius.button),
                    ),
                  ),
                ),
              ),
            if (zone == AnRowDropZone.above)
              PositionedDirectional(top: -1, start: indent, end: AnSpace.s8, child: _insertLine(c)),
            if (zone == AnRowDropZone.below)
              PositionedDirectional(bottom: -1, start: belowIndent, end: AnSpace.s8, child: _insertLine(c)),
          ],
        ),
      ),
    );

    return Draggable<String>(
      data: r.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      maxSimultaneousDrags: 1,
      onDragStarted: () => setState(() {
        _dragId = r.id;
        _dragSubtree = _subtreeIds(r.id);
      }),
      // Cleanup rides onDragCompleted + onDraggableCanceled: unlike onDragEnd they fire even when this
      // row's State was unmounted mid-drag (model rebuild / scroll recycling) — see [_endDrag].
      // 收尾挂 completed+canceled:源行中途被 unmount 时它们仍会被调(onDragEnd 会被跳过)——见 _endDrag。
      onDragCompleted: _endDrag,
      onDraggableCanceled: (_, _) => _endDrag(),
      feedback: _dragFeedback(context, r),
      childWhenDragging: Opacity(opacity: 0.35, child: SizedBox(height: AnSize.row, child: row)),
      child: target,
    );
  }

  Widget _insertLine(AnColors c) => IgnorePointer(
        child: Container(
          height: 2,
          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(1)),
        ),
      );

  /// The floating chip that follows the pointer: the row's icon + name on a raised surface. Pointer-anchored
  /// drags put the feedback's origin AT the pointer, so it's nudged down-right for cursor clearance. The
  /// feedback mounts in the ROOT overlay — outside any Material/DefaultTextStyle scope — so it carries its
  /// own text style with an explicit no-decoration (else the "missing ancestor" yellow underline shows).
  /// 跟随指针的名签:行图标+名、浮起面;指针锚定使原点即指针,右下偏移让开光标。feedback 挂根 overlay、脱离
  /// Material/DefaultTextStyle 作用域,故自带文字样式 + 显式无装饰(否则渲出「缺祖先」黄下划线)。
  Widget _dragFeedback(BuildContext context, SidebarRow r) {
    final c = context.colors;
    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(12, 8),
        child: DefaultTextStyle(
          style: AnText.body.copyWith(color: c.ink, decoration: TextDecoration.none),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s6),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AnRadius.button),
              // The float tier — a pop shadow's 32-blur second layer reads as a detached smudge under a
              // 32px chip. float 档——pop 影的 32 模糊第二层在 32px 小签下渲成分离残影。
              boxShadow: c.shadowFloat,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.icon != null) ...[
                  Icon(r.icon, size: AnSize.icon, color: c.inkMuted),
                  const SizedBox(width: AnSpace.s8),
                ],
                Text(r.label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Opaque backing for a sticky ancestor head so list rows scroll UNDER it (AnRow is transparent). 吸顶头 opaque 底。
  Widget _opaque(BuildContext context, Widget child) =>
      Container(height: AnSize.row, color: context.colors.surface, child: child);

  // The rename variant of a row: the SAME lead column (status dot or empty) + indent as AnRow, with the
  // label slot replaced by the reused AnInlineEdit (opened + select-all). 改名态行:同 lead/缩进,label 换 AnInlineEdit。
  Widget _editingRow(BuildContext context, SidebarFlatNode n) {
    final r = n.row!;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AnSpace.s8 + n.depth * AnSize.iconLg,
        end: AnSpace.s8,
      ),
      child: SizedBox(
        height: AnSize.row,
        child: Row(
          children: [
            SizedBox(
              width: AnSize.icon,
              height: AnSize.icon,
              child: Center(
                child: r.dot != null ? ExcludeSemantics(child: AnStatusDot(r.dot!)) : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            Expanded(
              child: AnInlineEdit(
                value: r.label,
                startEditing: true,
                minHeight: AnSize.row,
                onCommit: (v) => widget.onRenameCommit?.call(r.id, v),
                onAbort: widget.onRenameCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A pagination tail slot at a section's end: fire onLoadMore when built near (the virtualized list only
  // builds it at the tail), show a spinner while loading, a retry row on error. 分页尾槽:近尾即触发 onLoadMore。
  Widget _footer(BuildContext context, SidebarFlatNode n) {
    final c = context.colors;
    final t = n.type!;
    final pageKey = t.pageKey!;
    if (t.loadError) {
      // Stage-C polishes the tail states (i18n label, look); B1 = a tappable retry glyph. 阶段 C 完善尾态。
      return AnInteractive(
        onTap: () => widget.onRetryLoad?.call(pageKey),
        builder: (ctx, states) => Container(
          height: AnSize.row,
          alignment: Alignment.center,
          color: c.surfaceHover.whenActive(states.isActive),
          child: Icon(AnIcons.stop, size: AnSize.iconSm, color: c.danger),
        ),
      );
    }
    // hasMore (idle or loading): a sentinel that fires loadMore on build; a dim spinner slot while loading.
    return _LoadMoreSentinel(
      onEnter: () => widget.onLoadMore?.call(pageKey),
      child: SizedBox(
        height: AnSize.row,
        child: t.loadingMore
            ? Center(
                child: SizedBox(
                  width: AnSize.iconSm,
                  height: AnSize.iconSm,
                  child: Icon(AnIcons.run, size: AnSize.iconSm, color: c.inkFaint),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// A tail sentinel that fires [onEnter] once when first built — in a virtualized list this only happens
/// when it's scrolled into the cacheExtent (near the tail), so first-build ≈ reached-the-tail. Dedup +
/// loading-lock live in the consumer's loadMore. 尾哨兵:虚拟列表仅在近尾时 build 它,首建≈触底;去重/锁在 loadMore。
class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({required this.onEnter, required this.child});
  final VoidCallback onEnter;
  final Widget child;

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onEnter();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
