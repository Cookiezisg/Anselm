import 'package:flutter/widgets.dart';

import '../../../../core/contract/messages/block_content.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/model/status_state.dart' show AnTone;
import '../../../../core/ui/an_chip.dart';
import '../../../../core/ui/an_disclosure.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';

/// Renders a streamed agent ReAct trace ([BlockTreeReducer.roots]) as a nested, collapsible transcript —
/// text inline, reasoning + tool_call collapsed by default (CLAUDE.md), tool_result / progress nested
/// under their tool_call (E3). Pure projection of the reducer's tree; the parent owns the scroll +
/// coalesced rebuild.
///
/// Root subtrees ride a REVISION-KEYED identity cache (S6 — the chat transcript's settled-row cache,
/// adapted): [BlockNode.revision] has subtree semantics (any descendant change bumps its ancestors),
/// so an unchanged revision proves the WHOLE subtree is unchanged and the cached identical widget
/// short-circuits its element rebuild. During streaming only the active root's subtree rebuilds per
/// coalesced frame — settled roots cost zero builds (the old bare Column rebuilt the entire trace
/// every frame, O(blocks)). Keyed by revision, NOT isOpen: a closed tool_call still grows its nested
/// tool_result/progress children, which chat's isOpen-gated cache would miss. Each root sits behind
/// a [RepaintBoundary] so the streaming root's repaints stay inside its own bounds.
///
/// 渲染 agent 轨迹树:text 内联,reasoning/tool_call 默认折叠,result/progress 嵌套。根子树走
/// **revision 键身份缓存**(S6——chat settled 行缓存的适配版):revision 是子树版本(后代变化 bump
/// 祖先),rev 未变即整子树未变,缓存的同实例 widget 短路 element 重建——流式期只有活动根重建,
/// 落定根零 build(旧裸 Column 每帧整树重建)。键用 revision 而非 isOpen:闭合 tool_call 的嵌套
/// result/progress 仍会追加,isOpen 门控会漏。每根裹 RepaintBoundary,流式根重绘不出own bounds。
class BlockTreeView extends StatefulWidget {
  const BlockTreeView({required this.roots, super.key});

  final List<BlockNode> roots;

  @override
  State<BlockTreeView> createState() => _BlockTreeViewState();
}

class _BlockTreeViewState extends State<BlockTreeView> {
  // id → (revision, built widget). Bounded like chat's row cache (C-037) — a runaway trace evicts
  // FIFO-oldest, which are the roots furthest above the live tail. id→(版本,已建件);有界,逐最旧。
  static const _cacheCap = 400;
  final Map<String, (int, Widget)> _cache = {};

  Widget _rootFor(BlockNode n) {
    final hit = _cache[n.id];
    if (hit != null && hit.$1 == n.revision) return hit.$2;
    if (_cache.length >= _cacheCap) _cache.remove(_cache.keys.first);
    final built = Padding(
      key: ValueKey(n.id),
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      // RepaintBoundary + same key across revisions: the element (and BlockView's collapse State)
      // carries over when a revision rebuild swaps the instance. 同 key 跨版本:折叠 State 随 element 延续。
      child: RepaintBoundary(child: BlockView(node: n)),
    );
    _cache[n.id] = (n.revision, built);
    return built;
  }

  @override
  Widget build(BuildContext context) {
    // A fresh run replaces every block id — drop the dead entries eagerly. 新 run 换全部块 id,清死条目。
    if (widget.roots.isEmpty) _cache.clear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final n in widget.roots) _rootFor(n)],
    );
  }
}

/// One block + its children. Stateful for the per-node collapse toggle (reasoning / tool_call start
/// collapsed). 单块 + 子树;折叠开关有状态(reasoning/tool_call 默认收起)。
class BlockView extends StatefulWidget {
  const BlockView({required this.node, super.key});

  final BlockNode node;

  @override
  State<BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends State<BlockView> {
  late bool _open =
      widget.node.kind != BlockKind.reasoning &&
      widget.node.kind != BlockKind.toolCall;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return switch (n.kind) {
      BlockKind.text => _plain(context, n.displayText),
      BlockKind.reasoning => _collapsible(
        context,
        context.t.entities.run.reasoning,
        AnIcons.reasoning,
        n.displayText,
        dim: true,
      ),
      BlockKind.toolCall => _toolCall(context, n),
      BlockKind.toolResult => _toolResult(context, n),
      BlockKind.progress => _progress(context, n.displayText),
      BlockKind.message => _children(context, n.children),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _plain(BuildContext context, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: AnText.body.copyWith(color: context.colors.ink));
  }

  Widget _progress(BuildContext context, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: AnText.value(mono: true).copyWith(color: context.colors.inkMuted),
    );
  }

  // reasoning: a dim, collapsible-by-default disclosure (chevron + label → mono body). reasoning 折叠披露。
  Widget _collapsible(
    BuildContext context,
    String label,
    IconData icon,
    String body, {
    bool dim = false,
  }) {
    final c = context.colors;
    return AnDisclosure(
      label: label,
      icon: icon,
      iconColor: c.inkFaint,
      labelStyle: AnText.meta.copyWith(color: dim ? c.inkFaint : c.inkMuted),
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      child: Text(
        body,
        style: AnText.value(
          mono: true,
        ).copyWith(color: dim ? c.inkMuted : c.ink),
      ),
    );
  }

  Widget _toolCall(BuildContext context, BlockNode n) {
    final c = context.colors;
    final t = context.t;
    final danger = n.danger;
    final showDanger = danger != null && danger != Danger.safe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnDisclosure(
          label: n.name ?? t.entities.run.toolCall,
          icon: AnIcons.tool,
          labelStyle: AnText.value(mono: true).copyWith(color: c.ink),
          trailing: showDanger
              ? AnChip(
                  _dangerLabel(t, danger),
                  tone: danger == Danger.dangerous
                      ? AnTone.danger
                      : AnTone.warn,
                )
              : null,
          open: _open,
          onToggle: () => setState(() => _open = !_open),
          child: Text(
            n.argumentsText,
            style: AnText.value(mono: true).copyWith(color: c.inkMuted),
          ),
        ),
        // children (tool_result / progress) always shown, indented under the call. 子节点常显、缩进。
        if (n.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4, left: AnSpace.s16),
            child: _children(context, n.children),
          ),
      ],
    );
  }

  Widget _toolResult(BuildContext context, BlockNode n) {
    final c = context.colors;
    final body = n.error?.isNotEmpty == true ? n.error! : n.displayText;
    if (body.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AnIcons.enter, size: AnSize.iconSm, color: c.inkFaint),
        const SizedBox(width: AnSpace.s6),
        Expanded(
          child: Text(
            body,
            style: AnText.value(
              mono: true,
            ).copyWith(color: n.isError ? c.danger : c.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _children(BuildContext context, List<BlockNode> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in children)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s4),
          child: BlockView(node: c),
        ),
    ],
  );

  String _dangerLabel(Translations t, String danger) =>
      danger == Danger.dangerous
      ? t.entities.run.danger.dangerous
      : t.entities.run.danger.cautious;
}
