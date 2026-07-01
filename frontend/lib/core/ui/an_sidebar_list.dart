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

/// C5 — the left-rail sidebar list. A fixed New row + in-domain filter (with a sliders menu) sit above a
/// VIRTUALIZED body: [flattenSidebar] flattens the groups→types→rows tree by the current fold + filter
/// state into one flat list, rendered by a fixed-extent [SliverList] (only visible rows build — 5000-row
/// sections stay smooth). A Stack overlay pins the DYNAMIC ANCESTOR CHAIN of the top-most visible row
/// (VS Code sticky-scroll): a flat section pins one head, a deep tree pins the whole branch chain, capped.
/// Fold state keys on the flat node's STABLE SEMANTIC key (id/pageKey/label — never positional, so a
/// conditionally-emitted section can't fuse fold state with a sibling). Rows ride [AnRow]; the edited row
/// swaps to the reused [AnInlineEdit]; a paginated section drives [onLoadMore] via a tail footer.
///
/// C5——左岛侧栏。固定 New 行 + 域内过滤 在上;下方 VIRTUALIZED 主体:flattenSidebar 把 groups→types→rows 树按当前折叠
/// +过滤态展平成一维,定高 SliverList 渲染(只建可见行,5000 行段不卡)。Stack overlay 吸顶「顶部行的动态祖先链」
/// (VS Code sticky-scroll):扁平段吸一层头、深树吸整条分支链(封顶)。折叠键按稳定语义键(id/pageKey/label、非位置)。
/// 行搭 AnRow;编辑行换 AnInlineEdit;分页段经尾 footer 驱动 onLoadMore。
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
    this.editingRowId,
    this.onRenameCommit,
    this.onRenameCancel,
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

  /// In-place rename: the row with this id renders an [AnInlineEdit] in its label slot instead of the
  /// static [AnRow]. The host owns this id + clears it on commit/cancel. 就地改名:此 id 行渲 AnInlineEdit。
  final String? editingRowId;
  final void Function(String id, String value)? onRenameCommit;
  final VoidCallback? onRenameCancel;

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

  // The flattened list is HELD (not recomputed inline) so its indices stay in lock-step with the
  // SliverAnimatedList's: a user toggle animates a precise sub-range; a model/query change rebuilds it
  // fresh under a new key. 展平列表被持有(非内联重算),使 index 与 SliverAnimatedList 锁步:toggle 动画精确子区间;
  // model/query 变则换 key 重建。
  late List<SidebarFlatNode> _flat;
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _flat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
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
    _listKey = GlobalKey(); // a new key drops any stale animated-list index state → fresh initialItemCount
  }

  @override
  void dispose() {
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
      for (var i = headIdx + removedCount; i > headIdx; i--) {
        final node = removed[i - headIdx - 1];
        state?.removeItem(i, (context, animation) => _animatedRow(context, node, animation), duration: dur);
      }
    } else {
      _collapsed.remove(key);
      final newFlat = flattenSidebar(widget.model, collapsed: _collapsed, query: _query);
      final insertCount = newFlat.length - _flat.length;
      _flat = newFlat;
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
              // sibling-level row — without rebuilding the virtualized list. 吸顶 overlay 每帧跟滚动重建(跟手推走),不重建列表。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, _) => _stickyOverlay(context, _flat),
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
    final sticky = flat[top].ancestors.take(_maxSticky).toList();
    if (sticky.isEmpty) return const SizedBox.shrink();

    final stackBottom = sticky.length * AnSize.row;
    // Per-layer push (VS Code cascade): each ancestor head is pushed up once the first row that LEAVES
    // its branch (depth ≤ its own) scrolls up to meet the bottom of ITS slot — so the deepest head goes
    // first, then the next up. 每层各自推:某祖先头在离开其分支(depth ≤ 其深)的行顶到其槽底时被推,故最深先走、再上一层。
    final pushUps = List<double>.filled(sticky.length, 0.0);
    for (var i = 0; i < sticky.length; i++) {
      final d = sticky[i].depth;
      final slot = (i + 1) * AnSize.row;
      for (var j = top + 1; j < flat.length; j++) {
        if (flat[j].depth <= d) {
          final rowTop = j * AnSize.row - off;
          if (rowTop < slot) pushUps[i] = rowTop - slot;
          break;
        }
      }
    }

    return SizedBox(
      height: stackBottom,
      child: Stack(
        children: [
          // A continuous opaque backing so a pushed-out head reveals surface, not the list rows under it.
          // 连续 opaque 底:被推出的头露出的是 surface、不是其下的列表行。
          Positioned.fill(child: Container(color: context.colors.surface)),
          for (var i = 0; i < sticky.length; i++)
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
  // branch ancestor) → wrapped opaque. 实体行(叶/树枝);编辑行换改名件;sticky(树枝祖先)→opaque。
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
      hint: r.hint,
      meta: r.meta,
      selected: r.id == widget.selectedId,
      collapsible: branch,
      open: open,
      onSelect: () => widget.onSelect?.call(r.id),
      onToggle: branch ? () => _toggle(n.key) : null,
      actions: widget.rowActionsBuilder?.call(r.id) ?? const [],
    );
    return sticky ? _opaque(context, row) : row;
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
