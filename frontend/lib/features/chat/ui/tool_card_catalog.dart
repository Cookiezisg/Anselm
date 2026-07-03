import 'package:flutter/widgets.dart';

import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';

/// One tool's card grammar: the deterministic verb pair (decision #1 — the collapsed line's
/// voice; the LLM's `summary` stays inside the body), the target chip, the settled receipt,
/// and the family body. V3b populates F1 fs-ops / F2 fs-search / F3 shell; every un-cataloged
/// tool (incl. the whole MCP-dynamic family) falls to the GENERIC entry — never a silent hole.
///
/// 一个工具的卡片文法:确定性动词对(拍板 #1——收起行的声音,LLM `summary` 留在体内)、目标
/// chip、终态回执、族体。V3b 填入 F1 文件操作 / F2 文件检索 / F3 shell;一切未编目工具(含整个
/// MCP 动态族)落**通用**条目——绝不无声。
class ToolCardSpec {
  const ToolCardSpec({
    required this.verb,
    this.target,
    this.receipt,
    this.body,
    this.bodyless = false,
    this.liveTail = false,
  });

  /// The phase verb — gerund while live, past tense settled (terminal overrides — denied /
  /// cancelled / awaiting — stay with the chassis). live=进行时,settled=过去时;终态覆盖归底盘。
  final String Function(Translations t, {required bool live}) verb;

  /// The mono target chip; null/empty → verb self-sufficient. Streaming-tolerant (args may be
  /// a partial fragment). 目标 chip;可空=动词自足。须容忍流中的不完整 args。
  final String? Function(ToolCardState state)? target;

  /// The settled receipt suffix (the past tense's proof). null → no receipt.
  /// 终态回执后缀(过去时的凭据);null=无。
  final ToolReceipt? Function(Translations t, ToolCardState state)? receipt;

  /// The family expanded body; null → the chassis's generic body. 族展开体;null=通用体。
  final Widget Function(BuildContext context, ToolCardState state)? body;

  /// Never expands (Read: the receipt IS the card — industry consensus). 永不展开(Read)。
  final bool bodyless;

  /// Show the live machine-window tail (last progress lines) under the row while running.
  /// 执行中在行下显机器窗活尾巴(progress 尾行)。
  final bool liveTail;
}

/// The generic fallback (V3a behavior, unchanged). 通用兜底(V3a 行为不变)。
final ToolCardSpec genericToolCardSpec = ToolCardSpec(
  verb: (t, {required bool live}) => live ? t.chat.tool.calling : t.chat.tool.called,
  target: (s) => s.toolName,
);

ToolCardSpec _fsOp({
  required String Function(Translations) liveVerb,
  required String Function(Translations) doneVerb,
  ToolReceipt? Function(Translations, ToolCardState)? receipt,
  Widget Function(BuildContext, ToolCardState)? body,
  bool bodyless = false,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? liveVerb(t) : doneVerb(t),
      target: (s) {
        final p = argString(s.argsText, 'file_path');
        return p == null ? null : pathBasename(p);
      },
      receipt: receipt,
      body: body,
      bodyless: bodyless,
    );

ToolCardSpec _search({
  required String Function(Translations) liveVerb,
  required String Function(Translations) doneVerb,
  required String argKey,
  bool quote = true,
  required String Function(Translations, String) countLabel,
  Widget Function(BuildContext, ToolCardState)? body,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? liveVerb(t) : doneVerb(t),
      target: (s) {
        final v = argString(s.argsText, argKey);
        if (v == null) return null;
        return quote ? '"$v"' : pathBasename(v);
      },
      receipt: (t, s) => countReceipt(s.resultText,
          countLabel: (n) => countLabel(t, n), noneLabel: t.chat.tool.noMatches),
      body: body,
    );

/// The family table — keyed by exact tool name. 族表,按精确工具名键。
final Map<String, ToolCardSpec> _catalog = {
  // ── F1 fs-ops 文件操作 ──
  'Read': _fsOp(
    liveVerb: (t) => t.chat.tool.reading,
    doneVerb: (t) => t.chat.tool.read,
    receipt: (t, s) => readReceipt(s.resultText,
        linesLabel: (n) => t.chat.tool.lines(n: n),
        truncatedLabel: (n) => t.chat.tool.linesTruncated(n: n)),
    bodyless: true, // the receipt IS the card 回执即卡
  ),
  'Write': _fsOp(
    liveVerb: (t) => t.chat.tool.writing,
    doneVerb: (t) => t.chat.tool.wrote,
    receipt: (t, s) {
      final content = argString(s.argsText, 'content');
      if (content == null || content.isEmpty) return null;
      return (text: t.chat.tool.lines(n: '\n'.allMatches(content).length + 1), danger: false);
    },
    body: writeToolBody,
  ),
  'Edit': _fsOp(
    liveVerb: (t) => t.chat.tool.editing,
    doneVerb: (t) => t.chat.tool.edited,
    body: editToolBody,
  ),

  // ── F2 fs-search 文件检索 ──
  'Glob': _search(
    liveVerb: (t) => t.chat.tool.globbing,
    doneVerb: (t) => t.chat.tool.globbed,
    argKey: 'pattern',
    countLabel: (t, n) => t.chat.tool.files(n: n),
    body: listToolBody,
  ),
  'Grep': _search(
    liveVerb: (t) => t.chat.tool.grepping,
    doneVerb: (t) => t.chat.tool.grepped,
    argKey: 'pattern',
    countLabel: (t, n) => t.chat.tool.matches(n: n),
    body: listToolBody,
  ),
  'LS': _search(
    liveVerb: (t) => t.chat.tool.listing,
    doneVerb: (t) => t.chat.tool.listed,
    argKey: 'path',
    quote: false,
    countLabel: (t, n) => t.chat.tool.items(n: n),
    body: listToolBody,
  ),

  // ── F3 shell ──
  'Bash': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.runningCmd : t.chat.tool.ranCmd,
    target: (s) {
      final c = argString(s.argsText, 'command');
      return c == null ? null : commandChip(c);
    },
    receipt: (t, s) => bashReceipt(s.resultText,
        exitLabel: (code) => t.chat.tool.exit(code: code), timedOutLabel: t.chat.tool.timedOut),
    body: bashToolBody,
    liveTail: true, // the soul of the family: the little live terminal 族魂:活的小终端
  ),
};

/// Resolve a tool's spec; unknown → generic. 解析工具规格;未知→通用。
ToolCardSpec toolCardSpecFor(String toolName) => _catalog[toolName] ?? genericToolCardSpec;
