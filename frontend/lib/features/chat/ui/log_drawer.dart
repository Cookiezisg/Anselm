import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import 'tool_card_skins.dart' show WindowCopyButton;

// The ONE log drawer (WRK-066 批4 合一) — converged from RunDossier's _LogDrawer and the exec bodies'
// _LogsDrawer (two near-duplicate private drawers). «日志 · N 行» disclosure over a DOUBLE-ENDED-capped
// (head 2000 + middle elision + tail 4000) machine window with a full-payload copy action; an MCP
// stderr tail (split on the fixed separator) becomes its own danger-colored sibling window carrying the
// backend's own caveat.
//
// 唯一日志抽屉(批4 合一,收敛 RunDossier._LogDrawer 与 exec._LogsDrawer 两近重复私件):「日志 · N 行」
// 披露 + 双端截断(头 2000+中缝省略+尾 4000)机器窗 + 全量复制;MCP stderr 尾按固定分隔符切出、成 danger
// 同胞窗保留后端告诫。

const String mcpStderrSeparator = '--- server stderr tail (server-level, may predate this call) ---';

/// Cap a log to head+tail with a middle elision (the tail — last yields / stderr / dying output — is the
/// most diagnostic, so NEVER head-truncate). Returns (head, omittedChars, tail); omitted=0 when it fits.
/// Budgets are the named [AnCap.logHead]/[AnCap.logTail] tiers (A-112 — the drawer's private constant
/// group moved into the token registry; the fits-whole threshold is DERIVED head+tail, not a coincidental
/// third literal). 日志双端保留:头+尾+中缝省略(尾最诊断,绝不头截)。预算走 AnCap 具名档(A-112,抽屉私有
/// 常量组入档;整渲阈=头+尾之和派生,不留巧合第三字面量)。
({String head, int omitted, String tail}) capLog(String log) {
  if (log.length <= AnCap.logHead + AnCap.logTail) return (head: log, omitted: 0, tail: '');
  return (
    head: log.substring(0, AnCap.logHead),
    omitted: log.length - AnCap.logHead - AnCap.logTail,
    tail: log.substring(log.length - AnCap.logTail),
  );
}

/// The shared log drawer. Line-counted label, double-ended cap, full-payload copy, MCP stderr split.
/// 共享日志抽屉:计行标签+双端截断+全量复制+stderr 分段。
class LogDrawer extends StatefulWidget {
  const LogDrawer({required this.logs, this.splitStderr = false, super.key});

  final String logs;

  /// Split an MCP stderr tail into its own danger window. ONLY the dossier (which renders
  /// get_mcp_call logs where the backend emits the separator) turns this on — exec logs are
  /// arbitrary function prints, and an unconditional split would hang a fake «server stderr»
  /// label on a colliding line (批4 复审). stderr 分段仅卷宗开启:exec 日志是任意打印,无条件切分
  /// 会给撞串行贴假标签。
  final bool splitStderr;

  @override
  State<LogDrawer> createState() => _LogDrawerState();
}

class _LogDrawerState extends State<LogDrawer> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final n = '\n'.allMatches(widget.logs.trimRight()).length + 1;
    // Split off an MCP stderr tail (server-level; the caveat matters — it may predate this call).
    // 切出 MCP stderr 尾(server 级;段头告诫要保留:可能早于本次调用)。
    final sepIdx = widget.splitStderr ? widget.logs.indexOf(mcpStderrSeparator) : -1;
    final main = sepIdx >= 0 ? widget.logs.substring(0, sepIdx) : widget.logs;
    final stderr = sepIdx >= 0 ? widget.logs.substring(sepIdx + mcpStderrSeparator.length).trimLeft() : null;
    final capped = capLog(main);
    return AnDisclosure(
      label: t.chat.tool.execLogs(n: '$n'),
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      child: _open
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              AnWindow(
                actions: [WindowCopyButton(copyPayload: widget.logs)],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(capped.head, style: AnText.code.copyWith(color: c.inkMuted)),
                  if (capped.omitted > 0) ...[
                    Text(t.chat.tool.logOmitted(n: '${capped.omitted}'), style: AnText.meta.copyWith(color: c.inkFaint)),
                    Text(capped.tail, style: AnText.code.copyWith(color: c.inkMuted)),
                  ],
                ]),
              ),
              if (stderr != null && stderr.isNotEmpty) ...[
                const SizedBox(height: AnSpace.s4),
                Text(t.chat.tool.dossierStderr, style: AnText.meta.copyWith(color: c.danger)),
                const SizedBox(height: AnSpace.s2),
                AnWindow(
                    child: Text(stderr.length > AnCap.stderrTail ? stderr.substring(stderr.length - AnCap.stderrTail) : stderr,
                        style: AnText.code.copyWith(color: c.danger), maxLines: 60, overflow: TextOverflow.ellipsis)),
              ],
            ])
          : null,
    );
  }
}
