import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/sidebar_model.dart';
import 'an_button.dart';
import 'an_expand_reveal.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'an_menu.dart';
import 'an_row.dart';
import 'an_scroll_behavior.dart';
import 'icons.dart';

/// C5 — the left-rail sidebar list: a New row + an in-domain filter (with a sliders menu) + a recursive
/// groups → types → rows tree. The New / filter heads share the same lead column as the entity rows so the
/// `+` / search glyph aligns with the row icons. Built on [AnRow] (the New row + collapsible type heads +
/// entity rows all ride it — only the chat-style collapsible GROUP head is bespoke, its right-anchored
/// chevron disclosure diverging from AnRow's lead chevron), [AnInput] (seamless filter), [AnMenu] (sliders),
/// with the pure [SidebarModel] filter driving hide + ancestor-reveal. Selection is controlled ([selectedId]
/// + [onSelect]); fold state is internal (all open by default). The keyboard expand/collapse for the tree
/// rides here (the consumer of AnRow.expanded).
///
/// C5——左岛侧栏:New 行 + 域内过滤(带 sliders 菜单)+ 递归 groups→types→rows 树。New/过滤头与实体行共用行首列,故
/// +/🔍 与行图标对齐。搭 AnRow(实体行 + 可折叠类型头)+ AnInput(seamless 过滤)+ AnMenu(sliders),纯 SidebarModel
/// 过滤驱动隐藏 + 祖先回填。选中受控(selectedId+onSelect);折叠态内部(默认全开)。
///
/// Fold + filter state are TRANSIENT widget state (the widget owns them): branch fold keys on row id, but
/// group/type fold keys on POSITION (g$gi / g$gi/t$ti) — so the model should be positionally stable; a
/// reorder/insert can carry stale fold to a new slot, and a model swap keeps the active filter query. Keep
/// the model identity stable (memoize) across rebuilds. 折叠/过滤是瞬时态:树枝按 id、group/type 按位置键,故模型须位置稳定。
class AnSidebarList extends StatefulWidget {
  const AnSidebarList({
    required this.model,
    this.selectedId,
    this.onSelect,
    this.onNew,
    this.onFilterChanged,
    this.menuEntries = const [],
    this.showNew = true,
    this.rowActionsBuilder,
    super.key,
  });

  final SidebarModel model;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onNew;
  final ValueChanged<String>? onFilterChanged;

  /// Sliders (Sort / Display) menu entries; empty → no sliders anchor. sliders 菜单项,空则不渲。
  final List<AnMenuEntry> menuEntries;
  final bool showNew;

  /// Optional trailing actions per row (e.g. add / more), keyed by row id. 行尾动作(add/more)。
  final List<Widget> Function(String rowId)? rowActionsBuilder;

  @override
  State<AnSidebarList> createState() => _AnSidebarListState();
}

class _AnSidebarListState extends State<AnSidebarList> {
  final TextEditingController _filter = TextEditingController();
  final Set<String> _collapsed = {}; // keys of collapsed group/type/branch (default: all open) 折叠集(默认全开)
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _toggle(String key) => setState(() => _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key));

  bool _open(String key) => !_collapsed.contains(key);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _query.trim().isNotEmpty;
    final visible = active ? sidebarVisibleIds(widget.model, _query) : const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showNew) _newRow(),
        _filterRow(c),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var gi = 0; gi < widget.model.groups.length; gi++) _group(c, gi, active, visible),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // New: rides AnRow (lead = +, label) so it shares the entity rows' geometry / hover / radius — no
  // bespoke row scaffolding (the only hand-rolled row left is the chat-style collapsible group head,
  // whose right-anchored chevron disclosure genuinely diverges from AnRow's lead chevron). New 行复用 AnRow。
  Widget _newRow() => AnRow(icon: AnIcons.plus, label: widget.model.newLabel, onSelect: widget.onNew);

  // Filter: lead = search, an inline seamless input, a trailing sliders menu. 过滤行。
  Widget _filterRow(AnColors c) {
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
                setState(() => _query = v);
                widget.onFilterChanged?.call(v);
              },
            ),
          ),
          if (widget.menuEntries.isNotEmpty)
            AnMenu(
              entries: widget.menuEntries,
              anchorBuilder: (context, toggle, isOpen) =>
                  AnButton.iconOnly(AnIcons.sliders, size: AnButtonSize.sm, semanticLabel: context.t.a11y.displayOptions, onPressed: toggle),
            ),
        ],
      ),
    );
  }

  Widget _group(AnColors c, int gi, bool active, Set<String> visible) {
    final g = widget.model.groups[gi];
    final shown = !active || g.types.any((t) => t.rows.any((r) => _rowVisible(r, active, visible)));
    if (!shown) return const SizedBox.shrink();

    final types = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var ti = 0; ti < g.types.length; ti++) _type(c, gi, ti, active, visible)],
    );
    if (!g.collapsible) return types;

    // collapsible big group: a light chat-style head (gray w600 label + count + rotating chevron). 可折叠大组。
    // Key by POSITION (not label) — two groups may share a label, which would fuse their fold state. 按位置键(非标签,避免同名组折叠态串)。
    final key = 'g$gi';
    final open = active || _open(key); // a query forces groups open to reveal matches 过滤强制展开
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInteractive(
          onTap: () => _toggle(key),
          expanded: open,
          builder: (context, states) => Container(
            height: AnSize.control,
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
            decoration: BoxDecoration(color: c.surfaceHover.whenActive(states.isActive), borderRadius: BorderRadius.circular(AnRadius.button)),
            child: Row(
              children: [
                Flexible(child: Text(g.label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint))),
                const SizedBox(width: AnSpace.s6),
                Text('${g.totalRows}', style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
                const Spacer(),
                AnimatedRotation(
                  // snap (not spin) when a filter forces the group open, so chevron + content stay in lockstep. 过滤强制展开时即时。
                  duration: (active || AnMotionPref.reduced(context)) ? Duration.zero : AnMotion.mid,
                  curve: AnMotion.spring,
                  turns: open ? 0.25 : 0,
                  child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
                ),
              ],
            ),
          ),
        ),
        // animated reveal; a filter-forced open snaps (no per-keystroke height tween). 揭示动效;过滤强制展开即时。
        AnExpandReveal(open: open, duration: active ? Duration.zero : null, child: types),
      ],
    );
  }

  Widget _type(AnColors c, int gi, int ti, bool active, Set<String> visible) {
    final t = widget.model.groups[gi].types[ti];
    final shown = !active || t.rows.any((r) => _rowVisible(r, active, visible));
    if (!shown) return const SizedBox.shrink();

    if (t.headless) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final r in t.rows) _row(c, r, 0, active, visible)],
      );
    }
    final key = 'g$gi/t$ti';
    final open = active || _open(key);
    // An icon'd type head rides AnRow (lead icon↔chevron on hover, rows indented one level). An
    // icon-LESS head (e.g. chat's time buckets — there is no per-bucket glyph) is FLUSH: the label leads
    // (no empty reserved lead), the count + a hover-revealed disclosure chevron sit at the far right, and
    // the rows are NOT extra-indented (their own lead column already aligns them). Both heads are a
    // disclosure BUTTON: the whole head toggles (keyboard-operable, not a mouse-only lead chevron).
    //
    // 带 icon 的类型头走 AnRow(lead 图标↔chevron hover、行缩进一级)。无 icon 头(如 chat 时间桶——无 per-bucket 字形)**打头**:
    // 标签贴左(不留空 lead)、计数 + hover 显的折叠 chevron 在最右、行不额外缩进(行自身 lead 列已对齐)。两种头都是披露按钮(整头可点、键盘可达)。
    final flush = t.icon == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flush)
          _flushTypeHead(c, t, key, open)
        else
          AnRow(
            icon: t.icon,
            label: t.label ?? '',
            meta: t.count != null ? '${t.count}' : null,
            collapsible: true,
            open: open,
            onSelect: () => _toggle(key),
            onToggle: () => _toggle(key),
          ),
        AnExpandReveal(
          open: open,
          duration: active ? Duration.zero : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final r in t.rows) _row(c, r, flush ? 0 : 1, active, visible)],
          ),
        ),
      ],
    );
  }

  // An icon-less collapsible section head: flush label + far-right count + a hover-revealed disclosure
  // chevron, no reserved lead. Space for the chevron is always held (opacity toggle) so revealing it on
  // hover never shifts the count. The whole head toggles (AnInteractive — keyboard + click).
  //
  // 无 icon 可折叠分节头:标签打头 + 计数最右 + hover 显折叠 chevron,无预留 lead。chevron 槽恒占位(只切 opacity),故 hover
  // 显示不挪动计数。整头可点(AnInteractive,键盘 + 点击)。
  Widget _flushTypeHead(AnColors c, SidebarType t, String key, bool open) {
    final style = AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint);
    return AnInteractive(
      onTap: () => _toggle(key),
      expanded: open,
      builder: (context, states) => Container(
        height: AnSize.row,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        decoration: BoxDecoration(
          color: c.surfaceHover.whenActive(states.isActive),
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        child: Row(
          children: [
            Flexible(child: Text(t.label ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
            const Spacer(),
            if (t.count != null) Text('${t.count}', style: style),
            AnimatedOpacity(
              opacity: states.isActive ? 1 : 0,
              duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.fast,
              child: Padding(
                padding: const EdgeInsets.only(left: AnSpace.s6),
                child: AnimatedRotation(
                  duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
                  curve: AnMotion.spring,
                  turns: open ? 0.25 : 0,
                  child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // recursive entity row (+ branch children). 递归实体行(+ 树枝子)。
  Widget _row(AnColors c, SidebarRow r, int depth, bool active, Set<String> visible) {
    if (active && !visible.contains(r.id)) return const SizedBox.shrink();
    final branch = r.hasChildren;
    final open = active || _open('r:${r.id}'); // a query forces branches open to reveal matches 过滤强制展开
    final row = AnRow(
      depth: depth,
      icon: r.dot == null ? r.icon : null,
      dot: r.dot,
      label: r.label,
      hint: r.hint,
      meta: r.meta,
      selected: r.id == widget.selectedId,
      collapsible: branch,
      open: open,
      onSelect: () => widget.onSelect?.call(r.id),
      onToggle: branch ? () => _toggle('r:${r.id}') : null,
      actions: widget.rowActionsBuilder?.call(r.id) ?? const [],
    );
    if (!branch) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnExpandReveal(
          open: open,
          duration: active ? Duration.zero : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final child in r.children) _row(c, child, depth + 1, active, visible)],
          ),
        ),
      ],
    );
  }

  bool _rowVisible(SidebarRow r, bool active, Set<String> visible) => !active || visible.contains(r.id);
}
