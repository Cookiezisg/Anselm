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
/// coalesced rebuild. 渲染 agent 轨迹树:text 内联,reasoning/tool_call 默认折叠,result/progress 嵌套。
class BlockTreeView extends StatelessWidget {
  const BlockTreeView({required this.roots, super.key});

  final List<BlockNode> roots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in roots)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: BlockView(node: n),
          ),
      ],
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
