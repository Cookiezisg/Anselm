import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_edge_fade.dart';
import 'an_window.dart';
import 'term_fold.dart';

/// The LIVE-TAIL family head (WRK-066「同轨」族六) — the ONE «it's really working» rolling tail, three
/// faces: [AnLiveTailStyle.term] (ANSI + in-place cursor folding + top fade — Bash/yields, absorbs the
/// old AnTermTail), [AnLiveTailStyle.mono] (plain mono tail — memory strokes, absorbs ToolLiveTail v1),
/// [AnLiveTailStyle.prose] (reading typesetting, bottom-pinned max-height clamp — WebFetch distillation).
/// Whitespace-only input renders NOTHING (the empty-shell guard is built in, not per-caller). Code
/// streams do NOT live here — they are the code family's live face (AnCodeEditor.live, same shell rule).
///
/// 活尾族当家件(「同轨」族六)——唯一「真的在干活」滚动尾,三张脸:term(ANSI+原地折叠+顶缘渐隐,吸收旧
/// AnTermTail)/mono(纯等宽尾,吸收 ToolLiveTail v1)/prose(阅读排版+贴底限高钳,WebFetch 蒸馏)。纯空白
/// 输入渲空(空壳守卫内建,不再逐调用方各写)。代码流不住这——那是代码族的 live 脸(同壳律)。
enum AnLiveTailStyle { term, mono, prose }

class AnLiveTail extends StatelessWidget {
  const AnLiveTail(
    this.text, {
    this.style = AnLiveTailStyle.term,
    this.tailLines = 6,
    this.maxHeight,
    super.key,
  });

  final String text;
  final AnLiveTailStyle style;

  /// term/mono: how many trailing lines show. prose ignores it (wraps — clamp by [maxHeight]).
  /// term/mono 尾行数;prose 忽略(折行内容按 maxHeight 钳)。
  final int tailLines;

  /// prose: the bottom-pinned clamp (an [AnSize] tier). prose 贴底钳高(AnSize 档)。
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Built-in empty-shell guard (WRK-065 lineage): whitespace-only progress must not paint a window.
    // 空壳守卫内建:纯空白不渲窗。
    if (text.trim().isEmpty) return const SizedBox.shrink();

    switch (style) {
      case AnLiveTailStyle.term:
        final folded = termFold(text);
        while (folded.isNotEmpty && folded.last.isEmpty) {
          folded.removeLast();
        }
        if (folded.isEmpty) return const SizedBox.shrink();
        final hasMore = folded.length > tailLines;
        final tail = hasMore ? folded.sublist(folded.length - tailLines) : folded;
        final base = AnText.code.copyWith(color: c.inkMuted);
        return AnWindow(
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in tail)
                  Text.rich(TextSpan(children: ansiSpans(line, c, base: base)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            if (hasMore)
              Positioned(
                  top: 0, left: 0, right: 0, height: AnSpace.s16,
                  child: AnEdgeFade(fromTop: true, color: c.surfaceSunken)),
          ]),
        );

      case AnLiveTailStyle.mono:
        final lines = text.trimRight().split('\n');
        final tail = lines.length > tailLines ? lines.sublist(lines.length - tailLines) : lines;
        return AnWindow(
          child: Text(tail.join('\n'), style: AnText.code.copyWith(color: c.inkMuted)),
        );

      case AnLiveTailStyle.prose:
        return AnWindow(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight ?? AnSize.proseClamp),
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomLeft,
                heightFactor: 1, // shrink-wrap below the clamp 低于钳即贴内容高
                child: Text(text, style: AnText.reading.copyWith(color: c.inkMuted)),
              ),
            ),
          ),
        );
    }
  }
}
