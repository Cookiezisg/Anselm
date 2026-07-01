import 'package:flutter/material.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/an_interactive.dart';
import '../../core/ui/an_scroll_behavior.dart';
import '../../core/ui/icons.dart';

/// Slice-2 POC v2 — DYNAMIC ANCESTOR STICKY (VS Code "sticky scroll") for the AnSidebarList rewrite.
/// The header stack that pins at the top = the ANCESTOR CHAIN of the top-most visible node, recomputed
/// on scroll: a flat list (entities/chat) pins one section head; a deep tree (documents) pins the whole
/// branch chain (breadcrumb-style, capped at [_maxSticky]). ONE mechanism for both.
///
/// Architecture (the researched winner — avoids TreeSliver's index→node blind spot + double-truth):
///   • a FLAT list is the single source of truth — the node tree flattened by each node's expanded state,
///     each row carrying its depth + ancestor chain
///   • CustomScrollView + SliverFixedExtentList (itemExtent = AnSize.row) → free virtualization; fixed
///     row height makes `offset ~/ rowH = firstVisibleIndex` exact (no fragile variable-extent math)
///   • a Stack overlay draws the ancestor head stack of flat[firstVisibleIndex], recomputed on scroll
///   • folding is INSTANT here (MVP, per the research "get sticky working first, add the tween after");
///     the collapse tween (SliverAnimatedList) is the next step once the sticky mechanic is proven
///
/// 切片 2 POC v2——动态祖先吸顶(VS Code sticky-scroll)。顶部吸顶的头栈 = 视口最顶部节点的**祖先链**,随滚动重算:
/// 扁平列表吸一层段头,深树吸整条分支链(面包屑,封顶 maxSticky)。扁平和深树**一套机制**。
/// 架构:flat 列表是唯一真相(树按展开态展平,每行带 depth + 祖先)+ CustomScrollView/SliverFixedExtentList(固定
/// 32 虚拟化,offset÷32=顶部 index 精确)+ Stack overlay 画祖先头栈。折叠此处瞬时(MVP),补间动画随后。
class SidebarVirtualPoc extends StatefulWidget {
  const SidebarVirtualPoc({super.key});

  @override
  State<SidebarVirtualPoc> createState() => _SidebarVirtualPocState();
}

/// A node in the source tree. Sections, folders and rows are all nodes — [children] make it a branch.
/// 源树节点。段/文件夹/行都是节点,children 使其成分支。
class _Node {
  _Node(this.id, this.label, {this.icon, this.children = const []});
  final String id;
  final String label;
  final IconData? icon;
  final List<_Node> children;
  bool get isBranch => children.isNotEmpty;
}

/// One visible row in the flattened list: the node + its depth + its ancestor chain (outermost→nearest).
/// 展平后的一行:节点 + 深度 + 祖先链(最外→最近)。
class _Flat {
  _Flat(this.node, this.depth, this.ancestors);
  final _Node node;
  final int depth;
  final List<_Node> ancestors;
}

const int _maxSticky = 4; // cap the ancestor stack so a deep tree can't eat the viewport (VS Code maxLineCount)

class _SidebarVirtualPocState extends State<SidebarVirtualPoc> {
  final ScrollController _scroll = ScrollController();
  final Set<String> _collapsed = {}; // ids of collapsed branches
  String? _selected;
  int _firstVisible = 0;

  late final List<_Node> _roots;

  @override
  void initState() {
    super.initState();
    _roots = [
      // flat section (like entities/chat): a section head + flat rows
      _Node('sec-fn', 'Functions', icon: AnIcons.function, children: [
        for (var i = 0; i < 6; i++) _Node('fn$i', 'function-$i'),
      ]),
      _Node('sec-pin', 'Pinned', icon: AnIcons.pin, children: [
        _Node('p1', 'normalize-input'),
        _Node('p2', 'validate-schema'),
      ]),
      // DEEP tree (like documents): folders nested → proves multi-level ancestor sticky
      _Node('sec-docs', 'Documents', icon: AnIcons.doc, children: [
        _Node('d-src', 'src', icon: AnIcons.doc, children: [
          _Node('d-ui', 'ui', icon: AnIcons.doc, children: [
            for (var i = 0; i < 8; i++) _Node('ui$i', 'widget_$i.dart'),
          ]),
          _Node('d-core', 'core', icon: AnIcons.doc, children: [
            for (var i = 0; i < 6; i++) _Node('core$i', 'service_$i.dart'),
          ]),
        ]),
        _Node('d-readme', 'README.md'),
      ]),
      // massive section: proves virtualization survives the flat+overlay approach
      _Node('sec-all', 'All (5000)', icon: AnIcons.entities, children: [
        for (var i = 0; i < 5000; i++) _Node('a$i', 'entity-$i'),
      ]),
    ];
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Flatten the tree by current expanded state → the single source of truth for rendering + ancestors.
  // 按当前展开态展平树 → 渲染 + 祖先的唯一真相。
  List<_Flat> _flatten() {
    final out = <_Flat>[];
    void walk(_Node n, int depth, List<_Node> anc) {
      out.add(_Flat(n, depth, anc));
      if (n.isBranch && !_collapsed.contains(n.id)) {
        final childAnc = [...anc, n];
        for (final c in n.children) {
          walk(c, depth + 1, childAnc);
        }
      }
    }

    for (final r in _roots) {
      walk(r, 0, const []);
    }
    return out;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final i = (_scroll.offset / AnSize.row).floor(); // fixed row height → exact first-visible index
    if (i != _firstVisible) setState(() => _firstVisible = i);
  }

  void _toggle(_Node n) => setState(() => _collapsed.contains(n.id) ? _collapsed.remove(n.id) : _collapsed.add(n.id));

  @override
  Widget build(BuildContext context) {
    final flat = _flatten();
    final top = _firstVisible.clamp(0, flat.isEmpty ? 0 : flat.length - 1);
    // The sticky head stack = the top-most visible row's ancestor chain (+ the row itself if it's a
    // branch), capped. 吸顶头栈 = 顶部行的祖先链(+ 若它本身是分支则含自身),封顶。
    final sticky = flat.isEmpty
        ? const <_Node>[]
        : [
            ...flat[top].ancestors,
            if (flat[top].node.isBranch) flat[top].node,
          ].take(_maxSticky).toList();

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const AnScrollBehavior(),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverFixedExtentList(
                itemExtent: AnSize.row,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _row(context, flat[index]),
                  childCount: flat.length,
                ),
              ),
            ],
          ),
        ),
        // The ancestor sticky overlay — opaque heads stacked at the top, recomputed on scroll.
        // 祖先吸顶 overlay——顶部 opaque 头栈,随滚动重算。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            key: const Key('poc-sticky-overlay'),
            mainAxisSize: MainAxisSize.min,
            children: [for (final n in sticky) _head(context, n, stuck: true)],
          ),
        ),
      ],
    );
  }

  // A branch/section head — chevron + icon + label. In the sticky overlay it's opaque + tappable to fold.
  // 分支/段头——chevron + icon + label。在吸顶 overlay 里 opaque + 可点折叠。
  Widget _head(BuildContext context, _Node n, {bool stuck = false, int depth = 0}) {
    final c = context.colors;
    final open = !_collapsed.contains(n.id);
    return AnInteractive(
      onTap: () => _toggle(n),
      expanded: open,
      builder: (ctx, states) => Container(
        height: AnSize.row,
        color: stuck ? c.surface : null, // opaque only when pinned, so rows scroll under it
        padding: EdgeInsets.only(left: AnSpace.s8 + depth * AnSize.iconLg, right: AnSpace.s12),
        decoration: stuck
            ? null
            : BoxDecoration(
                color: c.surfaceHover.whenActive(states.isActive),
                borderRadius: BorderRadius.circular(AnRadius.button),
              ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
              child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
            ),
            const SizedBox(width: AnSpace.s4),
            if (n.icon != null) ...[
              Icon(n.icon, size: AnSize.icon, color: c.inkMuted),
              const SizedBox(width: AnSpace.s6),
            ],
            Expanded(
              child: Text(n.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Flat f) {
    if (f.node.isBranch) return _head(context, f.node, depth: f.depth);
    final c = context.colors;
    final n = f.node;
    final selected = n.id == _selected;
    return AnInteractive(
      onTap: () => setState(() => _selected = n.id),
      builder: (ctx, states) => Container(
        height: AnSize.row,
        padding: EdgeInsets.only(left: AnSpace.s8 + f.depth * AnSize.iconLg + AnSize.iconLg, right: AnSpace.s12),
        decoration: BoxDecoration(
          color: selected ? c.surfaceHover : c.surfaceHover.whenActive(states.isActive),
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        child: Text(n.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.body.copyWith(color: selected ? c.ink : c.inkMuted)),
      ),
    );
  }
}
