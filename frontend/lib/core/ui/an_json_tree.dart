import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show TreeSliverIndentationType;

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../perf/frame_safe.dart';
import 'an_edge_fade.dart';
import 'an_interactive.dart';
import 'an_scroll_behavior.dart';
import 'icons.dart';

/// E2 — the one JSON / structured-data primitive (WRK-040 G5.2). JSON is parsed into a collapsible
/// TREE, never shown as a raw string. object/array = a foldable summary row (chevron + key + {n}/[n]);
/// leaf = a key + type-coloured value. Built on Flutter's BUILT-IN [TreeSliver] (zero new deps; the
/// official virtualized tree — `treeNodeBuilder` builds only the visible rows, so a ~650KB flowrun
/// result doesn't build the whole widget tree at once), with [TreeSliverIndentationType.none] so the
/// rows self-draw their indent in the kit's flat style. Type colours come from [SyntaxColors] (the same
/// palette the code editor / diff use). Read-only.
///
/// Dart-RUNTIME-TYPE dispatch (NOT the demo's `typeof`): Map→object / List→array / String→string /
/// num→number / bool→boolean / Null→null; a hand-built `dynamic` of an unexpected type falls back to
/// `toString` + neutral colour (never throws). A `seen` ancestor set yields `[Circular]` rather than a
/// stack overflow (jsonDecode output is acyclic, but a hand-built Map can cycle). The node tree is built
/// UPFRONT (the per-row WIDGETS virtualize, the node objects don't) and capped at [_maxNodes] with a
/// "… N more" leaf — building millions of nodes is the upfront ceiling (WRK-040 §9).
///
/// SCROLL HOST: a virtualized [TreeSliver] is a real viewport, so AnJsonTree REQUIRES a BOUNDED height
/// from its parent (a panel / inspector body / a [SizedBox] / an [Expanded]) — like AnPage. TreeSliver
/// does NOT support shrinkWrap (it throws inside a shrink-wrapping viewport), and that bounded viewport
/// is exactly what lets it build only the visible rows for a ~650KB result. Wrap in [AnScrollBehavior]
/// so the scrollbar is hidden (kit style).
///
/// E2——唯一 JSON/结构化展示原语。JSON 必解析成可折叠树、不裸露。object/array=可折叠 summary 行,leaf=key+类型着色值。
/// 搭 Flutter 内置 TreeSliver(零新依赖、官方虚拟化,只建可视行,解 650KB 悬崖)+ IndentationType.none 自绘缩进。
/// 类型按 Dart runtime type 分派(非 typeof);环检测出 [Circular];节点树 upfront 建+封顶。**滚动宿主:须父给有界高**
/// (同 AnPage;TreeSliver 不支持 shrinkWrap——有界 viewport 正是虚拟化前提)。
class AnJsonTree extends StatefulWidget {
  const AnJsonTree({
    this.data,
    this.jsonString,
    this.rootLabel = 'root',
    this.showRoot = true,
    this.openDepth,
    this.maxHeight,
    super.key,
  }) : assert(
         data == null || jsonString == null,
         'pass data OR jsonString, not both',
       );

  /// The decoded value (Map/List/String/num/bool/null). 已解码值。
  final Object? data;

  /// A JSON string to decode (shows an error row on parse failure). Mutually exclusive with [data]. JSON 串。
  final String? jsonString;

  /// The root row's label. 根行名。
  final String rootLabel;

  /// false → hide the root row and render its children at depth 0 (an outer Section owns the title). 隐根行。
  final bool showRoot;

  /// Initial expand depth (default: root → 2, no-root → 1). 默认展开深度。
  final int? openDepth;

  /// SELF-SIZING mode: bound the viewport to the CURRENT visible-row count, capped at this height —
  /// instead of the caller pinning a height it cannot know. Without it the host has to guess, and the
  /// only quantity a host can see is the top-level key count, which is wrong the moment anything is
  /// expanded (WRK-077 CR-3: a 2-key result gave a 64px box, so expanding an 8-element array put every
  /// new row below the fold and the tree read as "click does nothing"). The box grows and shrinks with
  /// the tree and never exceeds the cap, so the virtualization guarantee is untouched.
  ///
  /// **自量高**模式:视口跟随**当前可见行数**、以此高封顶——而不是让调用方钉一个它无法知道的高。没有它,
  /// 宿主只能猜,而宿主唯一看得见的量是顶层键数;一旦有任何展开,这个量就是错的(WRK-077 CR-3:2 键结果
  /// 给出 64px 框,于是展开 8 元素数组时新行全在折线以下,树读起来就是「点了没反应」)。框随树长随树缩、
  /// 绝不越顶,故虚拟化保证不受影响。
  final double? maxHeight;

  @override
  State<AnJsonTree> createState() => _AnJsonTreeState();
}

const int _maxNodes =
    2000; // node cap — a huge JSON building millions of nodes freezes the build 节点上限
const int _maxVal =
    500; // single-value cap — guard a giant text node (CSS ellipsis is visual only) 单值上限

class _AnJsonTreeState extends State<AnJsonTree> {
  final TreeSliverController _controller = TreeSliverController();
  final ScrollController _scroll = ScrollController();
  late List<TreeSliverNode<_JNode>> _tree;
  String? _parseError;

  /// Which paths were open before the current rebuild — null on the first build (use [openDepth]).
  /// 本次重建前哪些路径是展开的;首建为 null(用 openDepth)。
  Set<String>? _restore;
  bool _above = false;
  bool _below = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnJsonTree old) {
    super.didUpdateWidget(old);
    // Dart compares Map/List by IDENTITY, so `old.data != widget.data` fires whenever anything upstream
    // decodes a fresh object with the very same content — an SSE tick, a poll, a DTO rebuild — and the
    // rebuild wiped every expansion the reader had opened. Verified with a widget probe before fixing:
    // expand a depth-1 branch, re-pump an EQUAL-but-new Map, and the children were gone.
    //
    // Deep-comparing the data would be the obvious fix and the wrong one: a ~650KB result would pay a
    // full walk on every tick, to answer a question we don't actually care about. What the reader cares
    // about is that THEIR expansions survive, so that is what we preserve — by path, in O(open nodes),
    // which is also correct when the data genuinely did change a little.
    //
    // A structural change (root shown/labelled differently, a new openDepth) is an explicit request to
    // re-seed the shape, so it deliberately does NOT preserve.
    //
    // Dart 对 Map/List 按**身份**判等,故上游只要解出一个内容完全相同的新对象(SSE tick / 轮询 / DTO 重建),
    // `old.data != widget.data` 就成立,重建会抹掉读者已展开的一切。**修之前先用 widget 探针验过**:展开
    // 一个 depth-1 分支,再灌一个内容相同的新 Map,子行就没了。
    //
    // 深比数据是显而易见、但错的修法:~650KB 结果要为每个 tick 付一次全量走查,去回答一个我们其实不关心的
    // 问题。读者关心的是**他自己的展开**还在,那就保它——按路径、O(已展开节点),而且在数据确实小改时同样正确。
    //
    // 结构性变更(根的显隐/名、新的 openDepth)是明确要求重铺形状,故**刻意不**保留。
    final structural =
        old.showRoot != widget.showRoot ||
        old.rootLabel != widget.rootLabel ||
        old.openDepth != widget.openDepth;
    if (structural ||
        !identical(old.data, widget.data) ||
        old.jsonString != widget.jsonString) {
      _rebuild(preserveOpen: !structural);
    }
  }

  /// The paths currently expanded, walked from the live nodes. 当前展开的路径(据活节点走查)。
  Set<String> _openPaths() {
    final out = <String>{};
    void walk(List<TreeSliverNode<_JNode>> nodes) {
      for (final node in nodes) {
        if (node.children.isEmpty) continue;
        if (node.isExpanded) out.add(node.content.path);
        walk(node.children);
      }
    }

    walk(_tree);
    return out;
  }

  /// Rows the viewport would show right now — a node plus, if it is open, its subtree.
  /// 视口此刻会显示的行数——节点本身,若其展开则加上子树。
  int _visibleRows() {
    var n = 0;
    void walk(List<TreeSliverNode<_JNode>> nodes) {
      for (final node in nodes) {
        n++;
        if (node.isExpanded) walk(node.children);
      }
    }

    walk(_tree);
    return n;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final off = _scroll.offset;
    final above = off > 1.0;
    final below = off < max - 1.0;
    // A scroll listener is notified from inside performLayout; dirtying there is illegal (CR-1b).
    // 滚动监听器会在 performLayout 内部被通知,在那儿弄脏非法。
    if (above != _above || below != _below) {
      runFrameSafe(() {
        if (!mounted) return;
        if (above == _above && below == _below) return;
        setState(() {
          _above = above;
          _below = below;
        });
      });
    }
  }

  void _rebuild({bool preserveOpen = false}) {
    _restore = preserveOpen ? _openPaths() : null;
    _parseError = null;
    Object? data;
    if (widget.jsonString != null) {
      try {
        data = jsonDecode(widget.jsonString!);
      } catch (e) {
        _parseError = e.toString();
        _tree = const [];
        return;
      }
    } else {
      data = widget.data;
    }
    _tree = _buildTree(data);
  }

  List<TreeSliverNode<_JNode>> _buildTree(Object? data) {
    final ctx = _BuildCtx();
    final openDepth = widget.openDepth ?? (widget.showRoot ? 2 : 1);
    final kind = _kindOf(data);
    if (!widget.showRoot && (kind == _JKind.object || kind == _JKind.array)) {
      // No root row → the data's entries ARE the top level, at depth 0 (flush, like the demo). 无根→顶层 depth 0。
      return _children(data, 0, openDepth, ctx, '');
    }
    return [_buildNode(widget.rootLabel, data, 0, openDepth, ctx, '')];
  }

  List<TreeSliverNode<_JNode>> _children(
    Object? value,
    int depth,
    int openDepth,
    _BuildCtx ctx,
    String parentPath,
  ) {
    final entries = value is List
        ? [for (var i = 0; i < value.length; i++) MapEntry('$i', value[i])]
        : (value is Map
              ? value.entries.map((e) => MapEntry('${e.key}', e.value)).toList()
              : const <MapEntry<String, Object?>>[]);
    final out = <TreeSliverNode<_JNode>>[];
    for (var i = 0; i < entries.length; i++) {
      if (ctx.count >= _maxNodes) {
        out.add(
          TreeSliverNode(
            _JNode(
              label: '…',
              path: '$parentPath/…',
              kind: _JKind.nullValue,
              moreCount: entries.length - i,
            ),
          ),
        );
        break;
      }
      out.add(
        _buildNode(
          entries[i].key,
          entries[i].value,
          depth,
          openDepth,
          ctx,
          parentPath,
        ),
      );
    }
    return out;
  }

  TreeSliverNode<_JNode> _buildNode(
    String key,
    Object? value,
    int depth,
    int openDepth,
    _BuildCtx ctx,
    String parentPath,
  ) {
    ctx.count++;
    final kind = _kindOf(value);
    // Keys are joined with '/' — a key containing a slash could in principle collide with a nested path,
    // which would restore the wrong branch's open state. Harmless (a wrongly-open row, never wrong data)
    // and not worth an escaping scheme. 键以 '/' 相连:含斜杠的键理论上可与嵌套路径撞,导致恢复错分支的展开态
    // ——无害(顶多多开一行,数据永不会错),不值得为它引入转义。
    final path = '$parentPath/$key';
    if (kind != _JKind.object && kind != _JKind.array) {
      return TreeSliverNode(
        _JNode(
          label: key,
          path: path,
          kind: kind,
          value: _valueText(value, kind),
        ),
      );
    }
    if (ctx.seen.contains(value)) {
      // Circular ref (hand-built Map) → don't recurse (a stack overflow otherwise). 环→不下钻。
      return TreeSliverNode(
        _JNode(label: key, path: path, kind: _JKind.nullValue, circular: true),
      );
    }
    ctx.seen.add(value!);
    final children = _children(value, depth + 1, openDepth, ctx, path);
    ctx.seen.remove(value);
    final s = _summary(value, kind);
    // value: s lets an EMPTY collection render in the leaf path as a dim "{0}"/"[0]" (no fake chevron
    // button — children.isEmpty falls to leaf in _buildRow). value:s 让空集合走叶路径(无假分支钮)。
    return TreeSliverNode(
      _JNode(label: key, path: path, kind: kind, summary: s, value: s),
      children: children,
      // A preserved open-set wins over openDepth: on a data refresh the reader's own expansions are the
      // truth, not the seed depth. 保留下来的展开集优先于 openDepth:数据刷新时读者自己的展开才是真相。
      expanded: _restore?.contains(path) ?? depth < openDepth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_parseError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnSpace.s12,
          vertical: AnSpace.s8,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${context.t.tree.invalidJson}  ',
                style: AnText.code.copyWith(color: c.danger),
              ),
              TextSpan(
                text: _parseError,
                style: AnText.code.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          style: AnText.code,
        ),
      );
    }
    final reduced = AnMotionPref.reduced(context);
    // Top-level item count for the container a11y label (collection root → its children; else the tree). 顶层项数。
    final topCount = widget.showRoot
        ? (_tree.isNotEmpty ? _tree.first.children.length : 0)
        : _tree.length;
    // A virtualized TreeSliver is a real viewport — it does NOT support shrinkWrap (RenderTreeSliver
    // throws inside a shrink-wrapping viewport), so AnJsonTree REQUIRES a bounded height from its parent
    // (a panel / inspector body / a SizedBox), like AnPage. That bounded viewport is what makes the
    // virtualization (build only visible rows) possible for a ~650KB result. 须有界高(虚拟化前提,不支持 shrinkWrap)。
    Widget tree = ScrollConfiguration(
      behavior: const AnScrollBehavior(),
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          TreeSliver<_JNode>(
            tree: _tree,
            controller: _controller,
            indentation: TreeSliverIndentationType.none,
            // reduced → AnimationStyle.noAnimation (the cleaner no-motion path; flutter#153889's
            // duration-zero freeze was fixed in 3.41.9 — both skip now — but noAnimation stays correct).
            // reduced 走 noAnimation(更干净;#153889 的 duration-zero 冻结 3.41.9 已修,仍用 noAnimation)。
            toggleAnimationStyle: reduced
                ? AnimationStyle.noAnimation
                : AnimationStyle(
                    curve: AnMotion.easeOut,
                    duration: AnMotion.mid,
                  ),
            treeRowExtentBuilder: (node, dimensions) => AnSize.row,
            treeNodeBuilder: _buildRow,
            // Self-sizing mode has to re-measure when the tree folds. In every other mode the height is
            // the caller's, so there is nothing to recompute and we don't rebuild. Inline in a safe
            // phase — a toggle comes from a tap, not from layout. 自量高模式在折叠时须重新量;其余模式高
            // 归调用方、无可重算,故不重建。安全相位下同步执行(toggle 来自点击、不来自布局)。
            onNodeToggle: widget.maxHeight == null
                ? null
                : (_) => runFrameSafe(() {
                    if (mounted) setState(() {});
                  }),
          ),
        ],
      ),
    );

    // The scroll affordance. A bounded viewport that silently hides rows is the whole reason CR-3 read
    // as "click does nothing": the tree DID expand, the new rows were simply below a fold with no edge
    // to suggest one existed. Each fade shows only while that side genuinely has more, so a tree that
    // fits shows none.
    //
    // The Stack and both strips are UNCONDITIONAL, and the strips fade by opacity rather than appearing
    // and disappearing. Writing this the natural way — `if (_above || _below) tree = Stack(...)` — moved
    // the CustomScrollView between two different positions in the tree the first time a fade turned on,
    // which remounted it and threw "TreeSliverController is already associated with another TreeSliver".
    // That is the ticket book's own no-conditional-wrapping law (§5.8 RI), and it bit here within the
    // hour of being written down: a wrapper that comes and goes is a remount, every time.
    //
    // 滚动示能。有界视口无声藏行,正是 CR-3 读起来像「点了没反应」的全部原因:树**确实**展开了,新行只是落在
    // 一条没有任何边缘提示的折线之下。每侧渐隐只在那一侧真的还有内容时显示,故装得下的树两侧都不显示。
    //
    // Stack 与两条渐隐带**无条件**恒在,靠不透明度淡入淡出、而非出现/消失。按自然写法写(`if (_above ||
    // _below) tree = Stack(...)`)会在第一次亮起渐隐时把 CustomScrollView 从树的一个位置搬到另一个位置,
    // 于是它被重挂、抛出「TreeSliverController is already associated with another TreeSliver」。这正是本
    // 工单册自己那条**禁止条件包装**军规(§5.8 RI),而它在写下的当天就在这里咬了一口:**来来去去的包装层
    // 就是重挂**,每次都是。
    tree = Stack(
      children: [
        Positioned.fill(child: tree),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AnSpace.s12,
          child: AnimatedOpacity(
            opacity: _above ? 1 : 0,
            duration: reduced ? Duration.zero : AnMotion.fast,
            child: AnEdgeFade(fromTop: true, color: c.surface),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: AnSpace.s12,
          child: AnimatedOpacity(
            opacity: _below ? 1 : 0,
            duration: reduced ? Duration.zero : AnMotion.fast,
            child: AnEdgeFade(fromTop: false, color: c.surface),
          ),
        ),
      ],
    );

    // Same law, one allowance stated out loud: this wrapper IS conditional, on a CONSTRUCTOR argument.
    // Flipping maxHeight between null and non-null on a live instance would remount the subtree — no call
    // site does (each passes a literal), and there is no unconditional form, because a null cap means the
    // parent owns the bound and a SizedBox must not be there at all.
    // 同一条法,一处例外要说在明面上:本包装层**是**条件的,条件是一个**构造参数**。在活实例上让 maxHeight
    // 在 null 与非 null 之间翻会重挂子树——没有调用点这么做(各自传字面量),且此处无法写成无条件形式:cap 为
    // null 意味着界归父级,那时 SizedBox 根本不该在树上。
    if (widget.maxHeight != null) {
      final h = (_visibleRows() * AnSize.row).clamp(
        AnSize.row,
        widget.maxHeight!,
      );
      // Grow/shrink with the fold animation rather than snapping a frame ahead of the rows.
      // 随折叠动效长缩,而不是比行提前一帧硬跳。
      tree = AnimatedSize(
        duration: reduced ? Duration.zero : AnMotion.mid,
        curve: AnMotion.easeOut,
        alignment: Alignment.topCenter,
        child: SizedBox(height: h.toDouble(), child: tree),
      );
    }

    return Semantics(
      container: true,
      label: context.t.a11y.jsonTree(count: topCount),
      child: tree,
    );
  }

  Widget _buildRow(
    BuildContext context,
    TreeSliverNode<Object?> node,
    AnimationStyle toggleAnimationStyle,
  ) {
    final n = node.content as _JNode;
    final c = context.colors;
    final syntax = context.syntax;
    final reduced = AnMotionPref.reduced(context);
    // A branch only if it's a collection WITH children — an EMPTY {}/[] renders as a (non-tappable) leaf
    // so it doesn't expose a fake expand button that does nothing. 仅非空集合是分支;空集合走叶、不假装可展开。
    final isBranch =
        (n.kind == _JKind.object || n.kind == _JKind.array) &&
        node.children.isNotEmpty;
    final depth = node.depth ?? 0;
    final indent = depth * AnSize.iconLg; // demo --indent = 20 (== iconLg) 每级缩进

    if (isBranch) {
      // [chevron | key {n}] — tappable, hover-tinted; expanded announced for a screen reader.
      return AnInteractive(
        onTap: () => _controller.toggleNode(node),
        expanded: node.isExpanded,
        builder: (ctx, states) {
          final active = states.isActive;
          return AnimatedContainer(
            duration: reduced ? Duration.zero : AnMotion.fast,
            height: AnSize.row,
            padding: EdgeInsets.only(
              left: AnSpace.s8 + indent,
              right: AnSpace.s12,
            ),
            decoration: BoxDecoration(
              color: c.surfaceHover.whenActive(active),
              borderRadius: BorderRadius.circular(AnRadius.button),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: node.isExpanded ? 0.25 : 0, // ▸ → ▾
                  duration: reduced ? Duration.zero : AnMotion.mid,
                  child: Icon(
                    AnIcons.chevronRight,
                    size: AnSize.icon,
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(width: AnSpace.s6),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: n.label,
                          style: AnText.code.copyWith(
                            color: active ? c.ink : c.inkMuted,
                          ),
                        ),
                        TextSpan(
                          text: '  ${n.summary}',
                          style: AnText.codeInline.copyWith(color: c.inkFaint),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // leaf: [key | value] flush at the indent (no chevron slot). Two Flexibles clip key & value
    // INDEPENDENTLY (demo's `[.k auto][.v 1fr]` double-track) — a long key can't hide the value. Scalars
    // read "key: value"; an empty collection / marker reads "key  text". 叶:双 Flexible 独立省略、长 key 不吞 value。
    final isCollection =
        n.kind == _JKind.object ||
        n.kind == _JKind.array; // empty collection → leaf 空集合
    final String valueText;
    final Color valueColor;
    var italic = false;
    if (n.circular) {
      valueText = context.t.tree.circular;
      valueColor = c.danger; // a cycle IS an error 环=错误
    } else if (n.moreCount > 0) {
      valueText = context.t.tree.moreItems(count: n.moreCount);
      valueColor = c
          .inkFaint; // truncation is informational, not an error (demo uses the muted null tier) 截断非错误
    } else if (isCollection) {
      valueText = n.value ?? ''; // "{0}" / "[0]"
      valueColor = c.inkFaint;
    } else {
      valueText = n.value ?? '';
      valueColor = _valueColor(n.kind, syntax);
      italic = n.kind == _JKind.nullValue; // demo .null is italic null 走斜体
    }
    final useColon =
        !isCollection &&
        !n.circular &&
        n.moreCount == 0; // only scalars read "key: value" 仅标量带冒号
    return Padding(
      padding: EdgeInsets.only(left: AnSpace.s8 + indent, right: AnSpace.s12),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              n.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.code.copyWith(
                color: n.circular ? c.danger : c.inkMuted,
              ),
            ),
          ),
          Text(
            useColon ? ': ' : '  ',
            style: AnText.code.copyWith(color: c.inkFaint),
          ),
          Flexible(
            flex: 5,
            child: Text(
              valueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.code.copyWith(
                color: valueColor,
                fontStyle: italic ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// One tree row's data. Diagnostic markers ([Circular] / "N more") carry semantic flags, formatted with
// i18n at row-build time (the node tree is built without a context). 树行数据;诊断标记带语义旗、建行时本地化。
class _JNode {
  const _JNode({
    required this.label,
    required this.path,
    required this.kind,
    this.value,
    this.summary,
    this.circular = false,
    this.moreCount = 0,
  });
  final String label;

  /// Slash-joined key path from the root — the identity the open-set is preserved by. 路径=展开集的身份。
  final String path;
  final _JKind kind;
  final String? value; // leaf value text 叶值
  final String? summary; // branch {n} / [n] 分支摘要
  final bool circular; // ancestor cycle → [Circular] 环
  final int moreCount; // node-cap truncation → "N more" 截断
}

enum _JKind { object, array, string, number, boolean, nullValue, unknown }

class _BuildCtx {
  int count = 0;
  final Set<Object> seen =
      {}; // identity ancestor path (Map/List == is identity) 祖先路径(identity)
}

// Dispatch by Dart RUNTIME type (NOT the demo's typeof). 按 Dart 运行时类型分派。
_JKind _kindOf(Object? v) {
  if (v == null) return _JKind.nullValue;
  if (v is Map) return _JKind.object;
  if (v is List) return _JKind.array;
  if (v is String) return _JKind.string;
  if (v is bool) {
    return _JKind
        .boolean; // before num (bool is not num in Dart, but order is intentional) 先 bool
  }
  if (v is num) {
    return _JKind
        .number; // int + double both → number (one colour) int/double 同 number 色
  }
  return _JKind.unknown; // hand-built dynamic of an unexpected type 兜底
}

String _summary(Object? v, _JKind kind) =>
    kind == _JKind.array ? '[${(v as List).length}]' : '{${(v as Map).length}}';

String _valueText(Object? v, _JKind kind) {
  switch (kind) {
    case _JKind.nullValue:
      return 'null';
    case _JKind.string:
      final s = v as String;
      if (s.isEmpty) return '""';
      return s.length > _maxVal ? '${s.substring(0, _maxVal)}…' : s;
    case _JKind.number:
    case _JKind.boolean:
      return '$v';
    default:
      return '$v'; // unknown → toString 兜底
  }
}

Color _valueColor(_JKind kind, SyntaxColors s) {
  switch (kind) {
    case _JKind.string:
      return s.string;
    case _JKind.number:
      return s.number;
    case _JKind.boolean:
      return s.keyword; // bool reads as a keyword (true/false) 布尔走关键字色
    case _JKind.nullValue:
      return s.comment; // null muted like a comment null 走注释色
    default:
      return s.comment;
  }
}
