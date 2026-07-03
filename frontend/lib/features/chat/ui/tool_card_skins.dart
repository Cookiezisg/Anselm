import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';

/// Family bodies for the tool card — the MACHINE-WINDOW identity (user decree, 2026-07-03):
/// a tool call is an OPERATION against the outside world, not the model's inner voice, so its
/// machine output NEVER borrows thinking's whisper grammar (no left rail, no bare prose).
/// Everything a machine produced lives inside an explicit contained window — a sunken rounded
/// panel in mono — while the row above stays a bare verb line. Terminal output, diffs, hit
/// lists: same container, different content.
///
/// 工具卡族体——**机器窗口**身份(用户定调,2026-07-03):tool call 是对外部世界的**操作**、不是
/// 模型的内心低语,机器输出**绝不**借用 thinking 的低语语法(无左 rail、无裸散文)。一切机器产物
/// 都住在明确的容器窗里——凹陷圆角等宽面板;上方的行保持裸动词行。终端输出/diff/命中列表:
/// 同一容器、不同内容。
///
/// [ToolWindow] is that container. 机器窗容器。
class ToolWindow extends StatelessWidget {
  const ToolWindow({required this.child, this.header, super.key});

  final Widget child;

  /// Optional window header (e.g. the command line echoed terminal-style). 可选窗头(命令回显)。
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: AnSpace.s4)],
          child,
        ],
      ),
    );
  }
}

/// The live tail: the last [tailLines] progress lines inside a small machine window while the
/// tool runs — the strongest "it's really working" cue (industry: Claude Code / Cursor). The
/// window grows/shrinks with its content (AnimatedSize via AnExpandReveal host) and dissolves
/// into the expanded body's full window on completion.
///
/// 活尾巴:执行中把 progress 尾 [tailLines] 行装进小机器窗——最强「真的在干活」信号(业界:
/// Claude Code/Cursor)。窗随内容长缩,完成后溶进展开体的完整窗。
class ToolLiveTail extends StatelessWidget {
  const ToolLiveTail({required this.text, this.tailLines = 3, super.key});

  final String text;
  final int tailLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = text.trimRight().split('\n');
    final tail = lines.length > tailLines ? lines.sublist(lines.length - tailLines) : lines;
    return ToolWindow(
      child: Text(tail.join('\n'),
          style: AnText.code.copyWith(color: c.inkMuted)),
    );
  }
}

/// Shared intent line (the LLM's self-reported summary) — shown above the window in the
/// dangerous-leaning families (F3/F13/F14: the user judges the self-report).
/// 共用意图行(LLM 自报 summary)——危险倾向族(F3/F13/F14)置于窗上,供用户判断自述。
Widget _intent(BuildContext context, ToolCardState state) {
  final c = context.colors;
  if (state.summary.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s6),
    child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted)),
  );
}

/// Cap + honest truncation note for window content. 窗内容封顶+诚实截断注记。
const int _windowCapChars = 6000;

Widget _cappedMono(BuildContext context, String raw, {Color? color}) {
  final t = Translations.of(context);
  final c = context.colors;
  final truncated = raw.length > _windowCapChars;
  final shown = truncated ? raw.substring(0, _windowCapChars) : raw;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(shown.trimRight(), style: AnText.code.copyWith(color: color ?? c.inkMuted)),
      if (truncated)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(t.chat.tool.truncatedNote(chars: raw.length),
              style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
    ],
  );
}

/// F3 Bash — the terminal window: `$ command` echo header + combined output (progress while
/// it ran, else the result), exit footer left intact (the honest raw record).
/// F3 Bash——终端窗:`$ 命令` 回显头 + 合并输出(有 progress 用之,否则 result),exit footer 原样保留。
Widget bashToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final cmd = argString(state.argsText, 'command') ?? '';
  final output = state.progressText.isNotEmpty ? state.progressText : state.resultText;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _intent(context, state),
      ToolWindow(
        header: cmd.isEmpty
            ? null
            : Text('\$ $cmd', style: AnText.code.copyWith(color: c.ink)),
        child: _cappedMono(context, output),
      ),
    ],
  );
}

/// F1 Write — the written content in a code window (language from the extension).
/// F1 Write——写入内容装代码窗(语言按扩展名)。
Widget writeToolBody(BuildContext context, ToolCardState state) {
  final path = argString(state.argsText, 'file_path') ?? '';
  final content = argString(state.argsText, 'content') ?? '';
  if (content.isEmpty) return const SizedBox.shrink();
  return AnCodeEditor(code: content, lang: _langOf(path));
}

/// F1 Edit — old→new as a unified diff (AnVersionDiff: the machine window with green/red
/// gutters, an existing primitive).
/// F1 Edit——old→new 渲 unified diff(AnVersionDiff:带绿红软底的机器窗,现成原语)。
Widget editToolBody(BuildContext context, ToolCardState state) {
  final oldS = argString(state.argsText, 'old_string');
  final newS = argString(state.argsText, 'new_string');
  if (oldS == null && newS == null) return const SizedBox.shrink();
  return AnVersionDiff(
    before: oldS ?? '',
    after: newS ?? '',
    lang: _langOf(argString(state.argsText, 'file_path') ?? ''),
  );
}

/// F2 Glob/Grep/LS — the hit-list window: raw result lines in mono (the backend's formats are
/// already line-oriented; refined per-mode styling can come with real-wire verification).
/// F2 检索族——命中窗:结果行等宽原样(后端格式本就按行;分模式精修等真线缆核验后再上)。
Widget listToolBody(BuildContext context, ToolCardState state) {
  if (state.resultText.trim().isEmpty) return const SizedBox.shrink();
  return ToolWindow(child: _cappedMono(context, state.resultText));
}

String? _langOf(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return null;
  return switch (path.substring(i + 1).toLowerCase()) {
    'dart' => 'dart',
    'py' => 'python',
    'go' => 'go',
    'js' || 'ts' || 'tsx' || 'jsx' => 'javascript',
    'json' => 'json',
    'md' => 'markdown',
    'sh' || 'bash' => 'bash',
    'yaml' || 'yml' => 'yaml',
    _ => null,
  };
}
