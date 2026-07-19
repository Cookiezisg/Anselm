import 'sidebar_model.dart';

/// The kind of a flattened sidebar node — drives how the row builder renders it and whether it can be a
/// sticky ancestor. 展平节点类型——驱动行渲染 + 能否作吸顶祖先。
enum SidebarNodeKind {
  /// A collapsible section head (icon + label + count) — the entities kind sections, chat pinned/recents.
  /// 段头(icon+label+count)——entities kind 段、chat 置顶/最近。
  typeHead,

  /// A leaf or branch entity row. 实体行(叶或树枝)。
  row,

  /// A pagination tail slot at a section's end (sentinel / loading / retry / end). 分页尾槽。
  footer,
}

/// One row in the flattened sidebar — the single source of truth for both rendering (a fixed-height
/// SliverList) and ancestor sticky (VS Code sticky-scroll). The tree (groups→types→rows→branches) is
/// flattened by the current fold + filter state; each node carries its [depth], a STABLE SEMANTIC fold
/// [key] (id/label-based, never positional — so a conditionally-emitted section can't fuse fold state
/// with a sibling), and its [ancestors] chain (outermost→nearest — the sticky head stack for this row).
/// Exactly one of [group]/[type]/[row] is set per [kind] (footer carries its [type] for the pageKey).
///
/// 展平后一行——渲染(定高 SliverList)与祖先吸顶的唯一真相。树按当前折叠+过滤态展平;每节点带 depth、稳定语义折叠
/// key(按 id/label、绝不按位置——故条件发射段不与兄弟串折叠态)、祖先链(最外→最近,本行的吸顶头栈)。
class SidebarFlatNode {
  const SidebarFlatNode({
    required this.kind,
    required this.key,
    required this.depth,
    this.ancestors = const [],
    this.type,
    this.row,
  });

  final SidebarNodeKind kind;
  final String key;
  final int depth;
  final List<SidebarFlatNode> ancestors;

  final SidebarType? type;
  final SidebarRow? row;

  /// A collapsible head that can pin as an ancestor: a type head, or a branch row (has children).
  /// Leaf rows + footers are not branches. 可作吸顶祖先的可折叠头:type 头、或树枝行。
  bool get isBranch =>
      kind == SidebarNodeKind.typeHead ||
      (kind == SidebarNodeKind.row && (row?.hasChildren ?? false));
}

/// Flatten [model] into a linear list under the current [collapsed] fold set + [query] filter — the pure
/// data core of the virtualized sidebar (unit-tested without pumping a widget). Rules:
///   • a collapsed branch contributes its HEAD but none of its descendants
///   • an active [query] keeps only rows on the visible-id set ([sidebarVisibleIds]) and FORCE-EXPANDS
///     every ancestor (so a deep match is revealed), and drops heads with no visible descendant
///   • depth: a group is a transparent container (its types sit at depth 0 — groups no longer carry a
///     collapsible head); a section head's rows sit at the head's depth (the head already groups them — no
///     extra indent), branches nest +1
///   • a paginated type ([SidebarType.pageKey] != null) with hasMore/loadingMore/loadError contributes a
///     trailing [footer] node (the sentinel / loading / retry slot)
///
/// 把 model 按当前 collapsed + query 展平——虚拟化侧栏的纯数据核(脱 widget 单测)。规则:折叠分支只出头;active query
/// 只留可见 id 行 + 强制展开祖先 + 丢无可见子孙的头;depth 见上;分页 type 带 hasMore/loadingMore/loadError 尾随 footer。
List<SidebarFlatNode> flattenSidebar(
  SidebarModel model, {
  Set<String> collapsed = const {},
  String query = '',
}) {
  final active = query.trim().isNotEmpty;
  final visible = active ? sidebarVisibleIds(model, query) : const <String>{};
  final out = <SidebarFlatNode>[];

  // A query force-opens everything so a deep match is revealed. 过滤强制全展开。
  bool open(String key) => active || !collapsed.contains(key);

  void walkRow(SidebarRow r, int depth, List<SidebarFlatNode> anc) {
    if (active && !visible.contains(r.id)) return;
    final key = 'r:${r.id}';
    final node = SidebarFlatNode(kind: SidebarNodeKind.row, key: key, depth: depth, ancestors: anc, row: r);
    out.add(node);
    if (r.hasChildren && open(key)) {
      final childAnc = [...anc, node];
      for (final c in r.children) {
        walkRow(c, depth + 1, childAnc);
      }
    }
  }

  for (final g in model.groups) {
    // A group is a transparent container (0719: no collapsible group head) — its types flatten at depth 0.
    // 组=透明容器(0719 无可折叠组头)——类型直接平铺在 depth 0。
    const groupAnc = <SidebarFlatNode>[];
    const baseDepth = 0;

    for (final t in g.types) {
      if (active && !t.rows.any((r) => _visibleDeep(r, visible))) continue;
      var rowAnc = groupAnc;
      final rowDepth = baseDepth; // rows sit at the head's depth (head already groups them)

      if (!t.headless) {
        final tKey = 't:${t.foldKey}';
        final tNode = SidebarFlatNode(kind: SidebarNodeKind.typeHead, key: tKey, depth: baseDepth, ancestors: groupAnc, type: t);
        out.add(tNode);
        if (!open(tKey)) continue; // collapsed section: head only (no rows, no footer)
        rowAnc = [...groupAnc, tNode];
      }

      for (final r in t.rows) {
        walkRow(r, rowDepth, rowAnc);
      }

      // Pagination footer — only for a paginated section with something to show in the tail, and not
      // while a query is filtering (search paginates via its own re-fetch, not the tail). 分页尾槽(非过滤时)。
      if (!active && t.pageKey != null && (t.hasMore || t.loadingMore || t.loadError)) {
        out.add(SidebarFlatNode(kind: SidebarNodeKind.footer, key: 'f:${t.pageKey}', depth: rowDepth, ancestors: rowAnc, type: t));
      }
    }
  }

  return out;
}

/// Whether [r] or any descendant is on the visible set. 行或其子孙是否可见。
bool _visibleDeep(SidebarRow r, Set<String> visible) {
  if (visible.contains(r.id)) return true;
  for (final c in r.children) {
    if (_visibleDeep(c, visible)) return true;
  }
  return false;
}
