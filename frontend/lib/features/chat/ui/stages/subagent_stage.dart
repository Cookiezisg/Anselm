import 'package:flutter/widgets.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/contract/messages/block_content.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/tool_receipts.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The SUBAGENT stage (WRK-061 §7-13, W4; ensemble retired in G1) — ONE delegate, ONE card. The
/// sticky accordion already lays parallel delegates out as sibling rows, so the row body renders
/// ONLY its own subject: a compact ReAct tail (the newest nested blocks: reasoning as a shimmer
/// whisper line, tool_call as a bare verb row, text as a summary line) with the «当前动作» read
/// O(1) off the reducer's tail pointer, plus the inline terminal while the delegate's current tool
/// streams progress. A close settles the card: status mark + tokens roll + a non-end_turn
/// stopReason stated plainly. History rehydration by folded sub-messages is the W6 path (R-14).
///
/// G1 law: stage bodies consume their per-row [StageScene] ONLY — never director-global state. The
/// old in-body ensemble read `stage.channels` (which excludes the DIRECTOR's subject, not this
/// row's node), so every non-subject row rendered itself twice and N expanded rows rendered N×N
/// cards; its tap-to-pin also fought the accordion's own row grammar.
///
/// subagent 舞台(W4;G1 群像退役)——一席一卡。粘性手风琴已把并行分身铺成同级行,行体只渲本行主角:
/// 紧凑 ReAct 尾(reasoning=低语行/tool_call=裸动词行/text=摘要行)+「当前动作」O(1) 读尾指针 +
/// 分身当前工具流出 progress 时的内联终端。close 结算:状态记号+tokens 滚动+非 end_turn 止因如实。
/// G1 立法:舞台体只消费本行 [StageScene]、禁 watch 导演器全局态——旧体内群像读 `stage.channels`
/// (它排除的是导演 subject、不是本行节点),非 subject 行渲自己两次、N 行同展 = N×N;点卡换台又与
/// 手风琴行级文法相斗。
class SubagentStageBody extends StatelessWidget {
  const SubagentStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    return _SubagentCard(node: scene.node, dense: false, showTerminal: true);
  }
}

/// The delegate's task label off a `Subagent` tool_call's args — the ONE derivation shared by the
/// accordion row head and the stage card (G3/A2-23: live and settled titles must never diverge;
/// G8 re-keys the wire field here, in exactly one place). 分身任务名单源:行头与卡头共用一条派生
/// (live/落定绝不改名;G8 换线缆键只改这一处)。
String? subagentTaskLabel(BlockNode node) =>
    argStringPartial(node.argumentsText, 'description');

/// One delegate's card: task name → current action (tail pointer) → the compact ReAct tail → the
/// settle line. 一席分身卡:任务名→当前动作(尾指针)→紧凑 ReAct 尾→结算行。
class _SubagentCard extends StatelessWidget {
  const _SubagentCard({
    required this.node,
    required this.dense,
    this.showTerminal = false,
  });

  final BlockNode node;
  final bool dense;

  /// The SUBJECT card rolls its live tool progress as an inline terminal; peer cards stay quiet
  /// (tap to bring theirs on stage). 主体卡滚内联终端;同席卡安静(点卡上台再看)。
  final bool showTerminal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final desc = subagentTaskLabel(node) ?? t.chat.stage.subagentUnnamed;
    final live = node.isOpen;
    final tailCount = dense ? 3 : 6;
    final trail = _trajectory(node);
    final tail = trail.length > tailCount
        ? trail.sublist(trail.length - tailCount)
        : trail;
    final current = node.lastDescendant;
    final term = (live && showTerminal) ? _liveProgressTail(node) : '';
    final showCurrent = live && current != null && !identical(current, node);
    // A just-opened delegate has nothing to say yet — header-only window, no dead body gap (复审).
    // 刚开播的分身无话可说——头独窗,不付死体距(复审)。
    final hasBody = showCurrent || tail.isNotEmpty;

    final card = AnWindow(
      header: Row(
        children: [
          Icon(AnIcons.subagent, size: AnSize.iconSm, color: c.inkMuted),
          const SizedBox(width: AnSpace.s4),
          Expanded(
            child: Text(
              desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.label
                  .weight(AnText.emphasisWeight)
                  .copyWith(color: c.ink),
            ),
          ),
        ],
      ),
      actions: [if (!live) _settleMark(c)],
      footer: live ? null : _settleLine(context, c, t),
      child: !hasBody
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // icon 沟文法:当前动作(无 icon)与尾行(trajectory 字形)共用一条 icon 沟——字形同心居中(旧
                // CrossAxisAlignment.start 把 iconXs 吊在首行上方,统一为 center 首行同心),文字全落同列。
                // The icon-gutter grammar: the current action (no glyph) and the tail rows (trajectory glyphs) share
                // ONE gutter — glyphs centred on the first line (the old start-align hung iconXs above the text;
                // unified to center), all text on the same column.
                if (showCurrent) ...[
                  // framed:false — these rows are already INSIDE the card's AnWindow content inset; the frame's X=8
                  // would double-indent them past the card header glyph. 卡内沟行不再叠加假想框内距(免越过卡头字形)。
                  stageGutterRow(
                    framed: false,
                    child: AnShimmerText(
                      _lineOf(context, current),
                      style: AnText.meta.copyWith(color: c.inkMuted),
                    ),
                  ),
                  if (tail.isNotEmpty) const SizedBox(height: AnSpace.s6),
                ],
                for (final b in tail)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AnSpace.s2),
                    child: stageGutterRow(
                      framed: false,
                      lead: Icon(
                        _glyphOf(b),
                        size: AnSize.iconXs,
                        color: c.inkFaint,
                      ),
                      child: Text(
                        _lineOf(context, b),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.meta.copyWith(color: c.inkFaint),
                      ),
                    ),
                  ),
              ],
            ),
    );
    if (term.trim().isEmpty) return card;
    // The inner terminal, live: when the delegate's current tool streams progress (Bash tee,
    // env-fix log…), its tail rolls right below the card — a SIBLING window (leaf law: AnLiveTail
    // carries its own AnWindow shell, windows never nest). 内层终端:分身当前工具流出 progress 时
    // 尾部在卡下就地滚动——同胞窗(叶子律:活尾自带窗壳,窗禁套窗)。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        const SizedBox(height: AnSpace.s6),
        AnLiveTail(term),
      ],
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
      if (child.kind == BlockKind.toolResult ||
          child.kind == BlockKind.progress) {
        continue;
      }
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
    final tout = tokens is Map
        ? (tokens['out'] ?? tokens['outputTokens'])
        : null;
    final stop = node.content?['stopReason'] as String? ?? '';
    // No outer Padding — the AnWindow footer slot brings its own s4 gap. footer 槽自带 s4 前距。
    return Wrap(
      spacing: AnSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (tin is int && tout is int)
          Text(
            t.chat.stage.tokensInOut(tin: tin, tout: tout),
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
        if (stop.isNotEmpty && stop != 'end_turn')
          Text(
            t.chat.stage.stopReasonWord(r: stop),
            style: AnText.meta.copyWith(color: c.warn),
          ),
      ],
    );
  }
}
