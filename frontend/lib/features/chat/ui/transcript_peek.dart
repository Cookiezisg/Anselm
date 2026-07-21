import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/contract/messages/block_content.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';

// TranscriptPeek (WRK-056 #47 sibling, B5.10) — a bounded step catalog over a hydrated agent trajectory.
// A get_agent_execution record / an invoke_agent reload rebuilds its Execution.transcript into BlockNode
// roots ([hydrateTranscriptTree]) and shows a COMPACT read-only mini-transcript here: reasoning/text as
// truncated lines, tool_call as a mono name+summary row — inside a machine window, never borrowing
// thinking's whisper grammar. Capped: a failed run keeps the first few + last many (the failure is near
// the end); an ok run takes the head. An «open full» escape deep-links the durable record.
// TranscriptPeek:有界步骤目录,机器窗内紧凑只读迷你轨迹。

class TranscriptPeek extends StatelessWidget {
  const TranscriptPeek({
    required this.roots,
    required this.totalBlocks,
    this.failed = false,
    this.cap = 30,
    this.onOpenFull,
    super.key,
  });

  final List<BlockNode> roots;
  final int totalBlocks;
  final bool failed;
  final int cap;
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    if (roots.isEmpty) {
      return Text(
        t.chat.tool.transcriptEmpty,
        style: AnText.meta.copyWith(color: c.inkFaint),
      );
    }
    // Cap selection: a failed run's cause is usually near the END → keep the first 5 + last (cap-5); an
    // ok run reads top-down → keep the head. 封顶取块:失败取首 5+末尾,成功取头。
    final over = roots.length > cap;
    final shown = !over
        ? roots
        : failed
        ? [...roots.take(5), ...roots.skip(roots.length - (cap - 5))]
        : roots.take(cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              t.chat.tool.transcriptSteps(n: '$totalBlocks'),
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
            if (onOpenFull != null) ...[
              const Spacer(),
              AnInteractive(
                onTap: onOpenFull,
                builder: (context, _) => Text(
                  t.chat.tool.transcriptOpenFull,
                  style: AnText.meta
                      .weight(AnText.emphasisWeight)
                      .copyWith(color: c.accent),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AnSpace.s4),
        AnWindow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (over && failed) ...[
                // Show the gap honestly — a failed run is first-5 + tail, not contiguous. 失败非连续,诚实标缝。
                for (final n in shown.take(5)) _blockRow(context, n),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
                  child: Text(
                    t.chat.tool.transcriptCapped(
                      shown: '$cap',
                      total: '${roots.length}',
                    ),
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                ),
                for (final n in shown.skip(5)) _blockRow(context, n),
              ] else ...[
                for (final n in shown) _blockRow(context, n),
                if (over)
                  Padding(
                    padding: const EdgeInsets.only(top: AnSpace.s2),
                    child: Text(
                      t.chat.tool.transcriptCapped(
                        shown: '$cap',
                        total: '${roots.length}',
                      ),
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _blockRow(BuildContext context, BlockNode n) =>
      transcriptBlockRow(context, n);
}

/// One compact read-only row for a trajectory block — reasoning (dim tagged line) / text (tagged line) /
/// tool_call (glyph + mono name + summary). Shared by [TranscriptPeek] (settled trace) and
/// [NestedRunPane] (live E3 subtree). tool_result / other kinds render nothing (they nest / aren't
/// peeked). 轨迹块紧凑只读行(思考/回复/工具调用)。
Widget transcriptBlockRow(BuildContext context, BlockNode n) {
  final c = context.colors;
  final t = Translations.of(context);
  Widget line(String tag, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
    // Text.rich, not RichText — RichText ignores the ambient textScaler, so a11y scaling never
    // reached these lines (A-099). Text.rich 继承环境 textScaler,a11y 缩放才生效。
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$tag  ',
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
          TextSpan(
            text: text,
            style: AnText.code.copyWith(color: color),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
  switch (n.kind) {
    case BlockKind.reasoning:
      return line(t.chat.tool.transcriptThought, n.displayText, c.inkFaint);
    case BlockKind.text:
      return line(t.chat.tool.transcriptReply, n.displayText, c.inkMuted);
    case BlockKind.toolCall:
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              AnIcons.toolIcon(n.name ?? ''),
              size: AnSize.iconSm,
              color: c.inkFaint,
            ),
            const SizedBox(width: AnSpace.s6),
            Text(n.name ?? '', style: AnText.mono.copyWith(color: c.inkMuted)),
            if ((n.summary ?? '').isNotEmpty) ...[
              const SizedBox(width: AnSpace.s6),
              Flexible(
                child: Text(
                  n.summary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ),
            ],
          ],
        ),
      );
    default:
      return const SizedBox.shrink(); // tool_result nests under a call; other kinds are not peeked. 其余不 peek。
  }
}

/// NestedRunPane (WRK-056 #47) — the LIVE E3 trajectory window under a Subagent / invoke_agent card while
/// its run streams. A machine window (never thinking's whisper grammar) holding the nested reasoning/
/// text/tool_call blocks as compact rows; the LAST row shimmers while the run is in flight. It reads
/// state.nested (the tool_call's non-result child subtree) — present only DURING the live session (E3
/// blocks aren't persisted), so on reload the card falls back to the «replay from record» note.
/// NestedRunPane:嵌套运行活窗(机器窗内嵌套块紧凑行,末行 live 微光)。
class NestedRunPane extends StatelessWidget {
  const NestedRunPane({
    required this.nested,
    this.live = false,
    this.tail = 8,
    super.key,
  });

  final List<BlockNode> nested;
  final bool live;

  /// While live, show only the last [tail] rows (a growing tail, not the whole history). 活期只显尾。
  final int tail;

  @override
  Widget build(BuildContext context) {
    if (nested.isEmpty) return const SizedBox.shrink();
    final rows = live && nested.length > tail
        ? nested.sublist(nested.length - tail)
        : nested;
    return AnWindow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, n) in rows.indexed)
            if (live && i == rows.length - 1 && n.isOpen)
              AnShimmerText(
                _peekText(context, n),
                style: AnText.code.copyWith(color: context.colors.inkFaint),
              )
            else
              transcriptBlockRow(context, n),
        ],
      ),
    );
  }

  String _peekText(BuildContext context, BlockNode n) {
    final t = Translations.of(context);
    return switch (n.kind) {
      BlockKind.reasoning =>
        '${t.chat.tool.transcriptThought}  ${n.displayText}',
      BlockKind.text => '${t.chat.tool.transcriptReply}  ${n.displayText}',
      BlockKind.toolCall => n.name ?? '',
      _ => '',
    };
  }
}
