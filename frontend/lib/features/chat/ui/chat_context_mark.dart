import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';

/// The context-compaction WHISPER — the quiet timeline marker the transcript drops where the context
/// manager folded older turns into the running summary (backend `compaction` block). Deliberately NOT
/// the thinking whisper (that left-rail idiom is reserved for the assistant's reasoning; a compaction is
/// a SYSTEM event between turns): a centered hairline rule split by a muted layers-icon pill, so it reads
/// as "time passed / history was summarized here" without shouting. Localized from the block's marker —
/// the backend produces an English sentence with a count; [ChatContextMark] re-renders it in the UI
/// locale, parsing the count off the marker (raw fallback if the wording ever drifts).
///
/// 上下文压缩低语——contextmgr 把旧回合折进摘要处 transcript 落的安静时间轴标记(后端 compaction 块)。**刻意
/// 不用 thinking 低语**(那左轨语法留给助手推理;压缩是回合间的系统事件):居中发丝线中夹一个灰 layers 图标药丸,
/// 读作「这里时间过去了 / 历史被摘要了」而不喧哗。文案本地化——后端产英文带 count 句,此件按 UI 语言重渲、
/// 从 marker 解出 count(措辞漂移则回退原句)。
class ChatContextMark extends StatelessWidget {
  const ChatContextMark({required this.marker, super.key});

  /// The backend compaction block's content (the English marker sentence). 后端 compaction 块内容(英文 marker)。
  final String marker;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = _label(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _rule(c)),
          // Flexible (not a fixed Padding) so a long label ellipsizes instead of forcing an overflow at a
          // narrow width. Flexible(非定宽 Padding),窄宽时省略号而非溢出。
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AnIcons.layers, size: AnSize.iconSm, color: c.inkFaint),
                  const SizedBox(width: AnSpace.s6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _rule(c)),
        ],
      ),
    );
  }

  Widget _rule(AnColors c) => Container(height: AnSize.hairline, color: c.line);

  /// Localized whisper text: the count parsed off the marker → "…N earlier messages folded…", or the bare
  /// "Context compacted" when there is no count, or the raw marker if it doesn't look like ours.
  /// 本地化文案:从 marker 解 count → 带数量句;无数则裸「已压缩」;不像我们的句就原样。
  String _label(BuildContext context) {
    final t = context.t.chat;
    final n = _count(marker);
    // With a count → the full localized sentence; without → the bare localized label. 有数带量句,无数裸标签。
    return n != null ? t.contextCompactedCount(n: n) : t.contextCompacted;
  }

  static int? _count(String marker) {
    final m = RegExp(r'\d+').firstMatch(marker);
    return m == null ? null : int.tryParse(m.group(0)!);
  }
}
