import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_json_tree.dart';
import '../../../i18n/strings.g.dart';
import 'tool_card_document_skill.dart';
import 'tool_card_skins.dart';

/// The INPUT/OUTPUT SECTION (WRK-056 #13) — the F08 exec family's ledger骨架: a 13-tier grey label
/// («输入» / «输出») over a machine window, the value rendered by EXPLICIT HARD RULES (never content
/// sniffing — the builder decides the shape at author time via [renderAsProse], not the widget at
/// runtime). Reused by run_function / call_handler / invoke_agent AND the mount function skin (they all
/// carry the same ExecutionResult shape). 输入/输出节:13 灰标签 + 机器窗;值渲染是显式硬规则、绝非内容嗅探。
///
/// Render decision tree:
///   • null → «无返回值» grey note.
///   • bool / num / short single-line String → inline mono.
///   • long String → a capped mono window (NEVER markdown-sniffed) + truncation note + copy.
///   • renderAsProse + String → typeset prose (ONLY when the spec explicitly opts in — invoke_agent's
///     string final answer).
///   • Map whose values are all scalars (or a single key) → a per-key list (13 grey key + value by the
///     same rules) — NOT an AnJsonTree (its 500-char single-value cap would shred a long declared value).
///   • Map/List with a genuine nested container → a bounded AnJsonTree.
class ToolIOSection extends StatelessWidget {
  const ToolIOSection({required this.label, required this.value, this.renderAsProse = false, this.textCap = 6000, super.key});

  final String label;
  final Object? value;
  final bool renderAsProse;
  final int textCap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s2),
      _content(context, c, value, renderAsProse),
    ]);
  }

  Widget _content(BuildContext context, AnColors c, Object? v, bool prose) {
    final t = Translations.of(context);
    if (v == null) return Text(t.chat.tool.noReturn, style: AnText.code.copyWith(color: c.inkFaint));
    if (v is bool || v is num) return _inline(c, '$v');
    if (v is String) {
      if (prose && v.isNotEmpty) return ProseWindow(markdown: v);
      final single = !v.contains('\n');
      if (single && v.length <= 80) return _inline(c, v);
      return _monoWindow(context, c, v);
    }
    if (v is Map) {
      // A per-key list only when EVERY value is a scalar (or it's a single key) — else a real nested
      // structure → the JSON tree. 全标量值(或单键)→逐键;真嵌套→JSON 树。
      final scalarish = v.values.every((x) => x == null || x is String || x is num || x is bool);
      if (v.length == 1 || scalarish) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          for (final e in v.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${e.key}', style: AnText.label.copyWith(color: c.inkFaint)),
                _content(context, c, e.value, false),
              ]),
            ),
        ]);
      }
      return _jsonTree(context, v);
    }
    // List / anything else → the bounded tree. 列表等→有界树。
    return _jsonTree(context, v);
  }

  Widget _inline(AnColors c, String s) => Text(s, style: AnText.code.copyWith(color: c.inkMuted));

  Widget _monoWindow(BuildContext context, AnColors c, String s) {
    final t = Translations.of(context);
    final over = s.length > textCap;
    final shown = over ? s.substring(0, textCap) : s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      ToolWindow(
        actions: [WindowCopyButton(copyPayload: s)],
        child: Text(shown, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 200, overflow: TextOverflow.ellipsis),
      ),
      if (over)
        Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(t.chat.tool.contentTruncated, style: AnText.meta.copyWith(color: c.inkFaint))),
    ]);
  }

  Widget _jsonTree(BuildContext context, Object v) =>
      ToolWindow(child: SizedBox(height: AnSize.jsonViewport, child: AnJsonTree(data: v, showRoot: false)));
}

/// Format elapsed ms as human time (`940ms` / `1.2s` / `2m 3s`). 耗时人话。
String fmtElapsed(int ms) {
  if (ms < 1000) return '${ms}ms';
  if (ms < 60000) return '${(ms / 1000).toStringAsFixed(ms < 10000 ? 1 : 0)}s';
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  return '${m}m ${s}s';
}
