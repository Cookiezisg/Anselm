import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/contract/messages/block_content.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/tool_receipts.dart';
import '../tool_card_skins.dart';
import '../../state/conversation_stream_provider.dart';
import '../../state/stage_director_provider.dart';
import 'stage_scene.dart';

/// The SUBAGENT stage (WRK-061 §7-13, W4) — the delegate's live broadcast. ONE subagent: a compact
/// ReAct tail (the newest nested blocks: reasoning as a shimmer whisper line, tool_call as a bare verb
/// row, text as a summary line) with the «当前动作» read O(1) off the reducer's tail pointer. TWO OR
/// MORE live subagents: the ENSEMBLE — equal cards (task name + current action + a 3-line tail),
/// tapping one pins it on stage. A close settles the card: status mark + tokens roll + a non-end_turn
/// stopReason stated plainly. History rehydration by executionId is the W6 path (R-14).
///
/// subagent 舞台(W4)——分身的直播。单席:紧凑 ReAct 尾(最新嵌套块:reasoning=低语行/tool_call=裸动词行/
/// text=摘要行),「当前动作」O(1) 读 reducer 尾指针。≥2 并行=群像:等高卡(任务名+当前动作+3 行尾),点卡
/// 上台。close 结算:状态记号+tokens 滚动+非 end_turn 止因如实陈词。历史 executionId 径归 W6(R-14)。
class SubagentStageBody extends ConsumerWidget {
  const SubagentStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final stage = ref.watch(stageDirectorProvider(scene.conversationId));
    final transcript =
        ref.watch(conversationStreamProvider(scene.conversationId).notifier).transcript;

    // The ensemble: every OTHER live subagent alongside the subject. 群像:主角+其余 live 分身。
    final peers = [
      for (final ch in stage.channels)
        if (ch.kind == 'subagent' && ch.live) ch.blockId,
    ];

    if (peers.isEmpty) {
      return _SubagentCard(node: scene.node, dense: false, showTerminal: true);
    }
    final director = ref.read(stageDirectorProvider(scene.conversationId).notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(t.chat.stage.ensembleTitle, style: AnText.label.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s4),
      _SubagentCard(node: scene.node, dense: true, showTerminal: true),
      for (final blockId in peers)
        if (transcript.value.liveBlock(blockId) case final BlockNode peer) ...[
          const SizedBox(height: AnSpace.s6),
          AnInteractive(
            onTap: () => director.pin(blockId: blockId),
            builder: (ctx, states) => Container(
              decoration: BoxDecoration(
                color: states.isActive ? c.surfaceHover : null,
                borderRadius: BorderRadius.circular(AnRadius.button),
              ),
              child: _SubagentCard(node: peer, dense: true, showTerminal: false),
            ),
          ),
        ],
    ]);
  }
}

/// One delegate's card: task name → current action (tail pointer) → the compact ReAct tail → the
/// settle line. 一席分身卡:任务名→当前动作(尾指针)→紧凑 ReAct 尾→结算行。
class _SubagentCard extends StatelessWidget {
  const _SubagentCard({required this.node, required this.dense, this.showTerminal = false});

  final BlockNode node;
  final bool dense;

  /// The SUBJECT card rolls its live tool progress as an inline terminal; peer cards stay quiet
  /// (tap to bring theirs on stage). 主体卡滚内联终端;同席卡安静(点卡上台再看)。
  final bool showTerminal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final desc = argStringPartial(node.argumentsText, 'description') ?? t.chat.stage.subagentUnnamed;
    final live = node.isOpen;
    final tailCount = dense ? 3 : 6;
    final trail = _trajectory(node);
    final tail = trail.length > tailCount ? trail.sublist(trail.length - tailCount) : trail;
    final current = node.lastDescendant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AnSpace.s8),
      decoration: BoxDecoration(
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(AnIcons.subagent, size: AnSize.iconSm, color: c.inkMuted),
          const SizedBox(width: AnSpace.s4),
          Expanded(
            child: Text(desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
          ),
          if (!live) _settleMark(c),
        ]),
        if (live && current != null && !identical(current, node)) ...[
          const SizedBox(height: AnSpace.s4),
          AnShimmerText(_lineOf(context, current), style: AnText.meta.copyWith(color: c.inkMuted)),
        ],
        // The inner terminal, live: when the delegate's current tool streams progress (Bash tee,
        // env-fix log…), its tail rolls right here — the restrained take on «the page is the
        // terminal's» (an inline bounded window, no takeover theatrics). 内层终端活窗:分身当前工具
        // 流出 progress 时尾部就地滚动——「一整页是终端用的」的克制版(内联有界窗,不做接管戏)。
        if (live && showTerminal) ...[
          if (_liveProgressTail(node) case final String term when term.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s6),
            AnTermTail(text: term),
          ],
        ],
        if (tail.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s6),
          for (final b in tail)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_glyphOf(b), size: AnSize.iconSm - 4, color: c.inkFaint),
                const SizedBox(width: AnSpace.s4),
                Expanded(
                  child: Text(_lineOf(context, b),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.meta.copyWith(color: c.inkFaint)),
                ),
              ]),
            ),
        ],
        if (!live) _settleLine(context, c, t),
      ]),
    );
  }

  // The newest OPEN tool's streaming progress text (depth-first through message wrappers) — ''
  // when nothing streams. A tool_call's progress children carry bash/yield tees (persisted blocks,
  // so a reload replays them too). 最新 open 工具的 progress 流文本;无流为 ''。
  String _liveProgressTail(BlockNode n) {
    BlockNode? openTool;
    void walk(BlockNode x) {
      for (final child in x.children) {
        if (child.kind == BlockKind.message) {
          walk(child);
        } else if (child.kind == BlockKind.toolCall && child.isOpen) {
          openTool = child;
        }
      }
    }

    walk(n);
    final tool = openTool;
    if (tool == null) return '';
    final buf = StringBuffer();
    for (final child in tool.children) {
      if (child.kind == BlockKind.progress) buf.write(child.displayText);
    }
    final text = buf.toString();
    return text.isEmpty ? '' : tailLines(text, 10);
  }

  // The E3 trajectory (nested blocks minus result/progress; message wrappers flattened — the
  // ToolCardState.of shape, re-derived here off the raw node so peers need no card state).
  // E3 轨迹(摊平 message 包装,同卡州形状;直接从裸节点派生,同席不需卡态)。
  List<BlockNode> _trajectory(BlockNode n) {
    final out = <BlockNode>[];
    for (final child in n.children) {
      if (child.kind == BlockKind.toolResult || child.kind == BlockKind.progress) continue;
      if (child.kind == BlockKind.message) {
        out.addAll(child.children);
      } else {
        out.add(child);
      }
    }
    return out;
  }

  IconData _glyphOf(BlockNode b) => switch (b.kind) {
        BlockKind.reasoning => AnIcons.reasoning,
        BlockKind.toolCall => AnIcons.tool,
        _ => AnIcons.chat,
      };

  String _lineOf(BuildContext context, BlockNode b) {
    switch (b.kind) {
      case BlockKind.toolCall:
        final name = b.name ?? '';
        final target = b.entityName ?? '';
        return target.isEmpty ? name : '$name · $target';
      default:
        final text = b.displayText;
        final lastLine = tailLines(text.trimRight(), 1);
        return lastLine;
    }
  }

  Widget _settleMark(AnColors c) => Icon(
        node.isError ? AnIcons.error : AnIcons.check,
        size: AnSize.iconSm,
        color: node.isError ? c.danger : c.ok,
      );

  Widget _settleLine(BuildContext context, AnColors c, Translations t) {
    final tokens = node.content?['tokens'];
    final tin = tokens is Map ? (tokens['in'] ?? tokens['inputTokens']) : null;
    final tout = tokens is Map ? (tokens['out'] ?? tokens['outputTokens']) : null;
    final stop = node.content?['stopReason'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s4),
      child: Wrap(spacing: AnSpace.s8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (tin is int && tout is int)
          Text(t.chat.stage.tokensInOut(tin: tin, tout: tout),
              style: AnText.meta.copyWith(color: c.inkFaint)),
        if (stop.isNotEmpty && stop != 'end_turn')
          Text(t.chat.stage.stopReasonWord(r: stop), style: AnText.meta.copyWith(color: c.warn)),
      ]),
    );
  }
}
