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
/// [AnLiveTailStyle.prose] (reading typesetting, bottom-pinned max-height clamp + top fade on overflow —
/// WebFetch distillation, document drafts, thinking). Whitespace-only input renders NOTHING (the
/// empty-shell guard is built in, not per-caller). [bare] drops the window shell for tails living
/// INLINE in content flow (thinking) — machine-output tails keep the window.
///
/// **O(tail) is built in**: every face slices its input to the visible tail (reverse newline scan +
/// the [AnCap.window] char cap) BEFORE any fold/split/layout — callers may hand the full possibly-MB
/// buffer; per-frame cost stays bounded (the 对抗复审 finding: a caller-side contract WILL be
/// forgotten — so the head owns it). Code streams do NOT live here — they are the code family's
/// live face (AnCodeEditor.live, same shell rule).
///
/// 活尾族当家件(「同轨」族六)——唯一「真的在干活」滚动尾,三张脸:term(ANSI+原地折叠+顶缘渐隐,吸收旧
/// AnTermTail)/mono(纯等宽尾,吸收 ToolLiveTail v1)/prose(阅读排版+贴底限高钳+溢出顶渐隐,WebFetch 蒸馏/
/// 文稿流入/thinking)。纯空白输入渲空(空壳守卫内建)。bare=无框脸,给住在内容流里的内联尾(thinking)。
/// **O(tail) 内建**:三脸都先反向扫描切尾(+[AnCap.window] 字符帽)再折叠/排版——调用方可直接喂全量缓冲,
/// 每帧成本有界(复审教训:调用侧契约必有人忘,当家件自己扛)。代码流不住这——那是代码族的 live 脸(同壳律)。
enum AnLiveTailStyle { term, mono, prose }

/// The prose face's logical-line slice — generous vs its pixel clamp (wrapping means fewer logical
/// lines can fill it). prose 脸切尾行数——比像素钳宽裕(折行下更少逻辑行即填满)。
const int _proseTailLines = 24;

/// Slice the last [lines] logical lines of [text] via a REVERSE newline scan (never O(full)), then
/// apply the [AnCap.window] char cap — the real bound when one logical line is huge (a `\r` progress
/// spam line has no newlines at all; cutting mid-frame is safe, the next `\r` overwrites it).
/// 反向扫换行切尾 [lines] 行(绝不 O(全文)),再套字符帽——单逻辑行巨大时(\r 进度雨全在一行)靠帽兜底,
/// 切在帧中间无害(下个 \r 即覆盖)。
String _tailSlice(String text, int lines) {
  var cut = text.length;
  for (var remaining = lines; remaining > 0 && cut > 0; remaining--) {
    final nl = text.lastIndexOf('\n', cut - 1);
    if (nl < 0) {
      cut = 0;
      break;
    }
    cut = nl;
  }
  var start = cut == 0 ? 0 : cut + 1;
  if (text.length - start > AnCap.window) start = text.length - AnCap.window;
  return start == 0 ? text : text.substring(start);
}

class AnLiveTail extends StatelessWidget {
  const AnLiveTail(
    this.text, {
    this.style = AnLiveTailStyle.term,
    this.tailLines = 6,
    this.maxHeight,
    this.bare = false,
    super.key,
  });

  final String text;
  final AnLiveTailStyle style;

  /// term/mono: how many trailing lines show. prose ignores it (wraps — clamp by [maxHeight]).
  /// term/mono 尾行数;prose 忽略(折行内容按 maxHeight 钳)。
  final int tailLines;

  /// prose: the bottom-pinned clamp (an [AnSize] tier). prose 贴底钳高(AnSize 档)。
  final double? maxHeight;

  /// Drop the window shell — for tails inline in content flow (thinking), where a bordered card
  /// would promote quiet prose to machine-window weight. 无框脸:内容流内联尾(thinking),
  /// 描边卡会把安静散文抬成机器窗重量。
  final bool bare;

  Widget _shell(Widget body) => bare ? body : AnWindow(child: body);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Built-in empty-shell guard (WRK-065 lineage): whitespace-only progress must not paint a window.
    // 空壳守卫内建:纯空白不渲窗。
    if (text.trim().isEmpty) return const SizedBox.shrink();

    switch (style) {
      case AnLiveTailStyle.term:
        // Fold only the sliced tail — cursor-up reaches ≤ kTermWindow lines back, so give the fold
        // that much context beyond the visible tail. 只折切好的尾:cursor-up 最多回 kTermWindow 行,
        // 切尾时多留这段上下文。
        final folded = termFold(_tailSlice(text, tailLines + kTermWindow));
        while (folded.isNotEmpty && folded.last.isEmpty) {
          folded.removeLast();
        }
        if (folded.isEmpty) return const SizedBox.shrink();
        final hasMore = folded.length > tailLines;
        final tail = hasMore ? folded.sublist(folded.length - tailLines) : folded;
        final base = AnText.code.copyWith(color: c.inkMuted);
        return _shell(Stack(children: [
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
                // Fade blends to the WHITE window face (灰底退役,拍板 #1). 渐隐融白窗面。
                child: AnEdgeFade(fromTop: true, color: c.surface)),
        ]));

      case AnLiveTailStyle.mono:
        final lines = _tailSlice(text.trimRight(), tailLines).split('\n');
        final tail = lines.length > tailLines ? lines.sublist(lines.length - tailLines) : lines;
        return _shell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // One visual line per logical line — the term face's metric contract (复审 #23: a
            // wrapping long line must not blow the tailLines height). 与 term 同契约:行不折、超长裁。
            for (final line in tail)
              Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.code.copyWith(color: c.inkMuted)),
          ],
        ));

      case AnLiveTailStyle.prose:
        return _shell(_ProseTail(
          text: _tailSlice(text, _proseTailLines),
          maxHeight: maxHeight ?? AnSize.proseClamp,
        ));
    }
  }
}

/// The prose face's tail machinery: a bottom-pinned clamp + a top fade that only appears once the
/// text actually overflows. Overflow is read from scroll metrics (geometry the viewport already
/// computed) — NEVER from a TextPainter pre-layout, which would double the shaping work every frame
/// (the C-004 failure this face exists to kill; the input is already tail-sliced by the head).
///
/// prose 脸的尾部机械:贴底钳 + 仅在真溢出时出现的顶缘渐隐。溢出从滚动 metrics 读(视口已算好的几何),
/// 绝不用 TextPainter 预排版探(那会把每帧 shaping 翻倍——C-004;输入已被族头切尾)。
class _ProseTail extends StatefulWidget {
  const _ProseTail({required this.text, required this.maxHeight});

  final String text;
  final double maxHeight;

  @override
  State<_ProseTail> createState() => _ProseTailState();
}

class _ProseTailState extends State<_ProseTail> {
  bool _overflows = false;

  bool _onMetrics(ScrollMetricsNotification n) {
    // ScrollMetricsNotification is dispatched via a post-frame microtask (never during layout),
    // so flipping state directly is legal AND prompt — a postFrameCallback here would not itself
    // schedule a frame and could strand the fade until some unrelated repaint (复审 finding).
    // 该通知经帧后微任务派发(绝不在 layout 期),直接 setState 合法且即时——postFrameCallback 自己
    // 不排帧,会把渐隐搁浅到下次无关重绘(复审 finding)。
    final over = n.metrics.maxScrollExtent > 0.5;
    if (over != _overflows && mounted) setState(() => _overflows = over);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Bottom-pinned clamp done RIGHT (复审 HIGH #1): a reverse non-interactive scroll view gives
    // the text UNBOUNDED height and shows its BOTTOM. Align(bottomLeft) under a maxHeight clamp
    // clamps the paragraph ITSELF and freezes the HEAD — the exact opposite of a live tail.
    // 贴底钳正确惯用式:reverse 只读滚动给子树无界高、视口示底;Align 会把段落本身钳住冻结开头。
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: ClipRect(
        child: Stack(children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: SingleChildScrollView(
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              child: Text(widget.text, style: AnText.reading.copyWith(color: c.inkMuted)),
            ),
          ),
          if (_overflows)
            Positioned(
                top: 0, left: 0, right: 0, height: AnSpace.s16,
                child: AnEdgeFade(fromTop: true, color: c.surface)),
        ]),
      ),
    );
  }
}
