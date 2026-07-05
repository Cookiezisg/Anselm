import 'dart:convert';

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
    this.liveBody,
    this.awaitingVerb,
    this.terminalVerb,
    this.ownsError = false,
  });

  /// The phase verb — gerund while live, past tense settled. The chassis supplies default terminal
  /// overrides (denied / cancelled / awaiting); a family may override those via [awaitingVerb] /
  /// [terminalVerb]. live=进行时,settled=过去时;终态默认覆盖归底盘,族可经下两字段夺回。
  final String Function(Translations t, {required bool live}) verb;

  /// Override the AWAITING-phase row verb (default 等待确认). ask_user → 等待你回答. 覆盖等待动词。
  final String Function(Translations t)? awaitingVerb;

  /// Override the SETTLED-phase row verb with OUTCOME awareness (succeeded/failed/denied/cancelled) —
  /// the first consumer of the verb-state seam (ask_user: 已回答/已跳过/空答案 off the result prose).
  /// 带结果覆盖终态动词(verb-state 缝首个消费者:ask_user 按结果散文分 已回答/已跳过/空答案)。
  final String Function(Translations t, ToolCardState state)? terminalVerb;

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

  /// The family body renders its OWN failure display (so the chassis skips the default error section) —
  /// for families where a non-zero terminal is a product-normal, not a red crash (decide_approval's
  /// NOT_PARKED first-decision-wins). 族体自管失败显示(底盘跳默认错误段)——如 decide_approval 的 NOT_PARKED。
  final bool ownsError;

  /// The LIVE machine window under the row while the call is in flight and not user-expanded:
  /// F3 = the terminal tail (progress lines); F4 builds = the content window streaming in as
  /// args flow. null → nothing shows while live.
  /// 在飞且未被用户展开时行下的**活机器窗**:F3=终端尾巴(progress 行);F4 builds=随 args 流入
  /// 的内容窗。null=live 期无窗。
  final Widget Function(BuildContext context, ToolCardState state)? liveBody;
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

/// F4 builds: create/edit × 8 entities + the trigger pair. The verb carries the KIND NOUN
/// (正在创建函数/Creating function); create targets the streaming args.name, edit targets the
/// entity id; the receipt is vN from the output + the env half-success (envStatus failed →
/// danger → auto-expand); the live body streams the authored content as args flow.
/// F4 构建族:create/edit×8 实体+trigger 对。动词带**类名词**;create 目标=流中 args.name、
/// edit=实体 id;回执=输出 vN + env 半成功(failed→危险色→自动展开);活体=内容随 args 流入。
ToolCardSpec _build({
  required String Function(Translations) kind,
  required bool create,
  String? editIdKey,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => create
          ? (live ? t.chat.tool.creatingKind(kind: kind(t)) : t.chat.tool.createdKind(kind: kind(t)))
          : (live ? t.chat.tool.updatingKind(kind: kind(t)) : t.chat.tool.updatedKind(kind: kind(t))),
      target: (s) => create
          ? argStringPartial(s.argsText, 'name')
          : (editIdKey == null ? null : argString(s.argsText, editIdKey)),
      receipt: (t, s) {
        Map<String, dynamic>? out;
        try {
          final d = jsonDecode(s.resultText);
          if (d is Map<String, dynamic>) out = d;
        } catch (_) {}
        if (out == null) return null;
        final v = out['version'];
        final envFailed = out['envStatus'] == 'failed' || (out['envError'] as String?)?.isNotEmpty == true;
        if (envFailed) return (text: t.chat.tool.envFailed, tone: ToolReceiptTone.danger);
        // A crashed handler instance (env ready but __init__ broke) is a danger the user must see —
        // auto-expand. stopped is benign (never-spawned) → not danger. crashed=真 brick 自动展开;stopped 良性。
        if (out['runtimeState'] == 'crashed') return (text: t.chat.tool.runtimeCrashed, tone: ToolReceiptTone.danger);
        return v == null ? null : (text: 'v$v', tone: ToolReceiptTone.none);
      },
      body: buildToolBody,
      liveBody: buildLiveBody,
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
      return (text: t.chat.tool.lines(n: '\n'.allMatches(content).length + 1), tone: ToolReceiptTone.none);
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

  // ── F4 builds 构建族 ──
  'create_function': _build(kind: (t) => t.chat.tool.kind.function, create: true),
  'edit_function': _build(kind: (t) => t.chat.tool.kind.function, create: false, editIdKey: 'functionId'),
  'create_handler': _build(kind: (t) => t.chat.tool.kind.handler, create: true),
  'edit_handler': _build(kind: (t) => t.chat.tool.kind.handler, create: false, editIdKey: 'handlerId'),
  'create_agent': _build(kind: (t) => t.chat.tool.kind.agent, create: true),
  'edit_agent': _build(kind: (t) => t.chat.tool.kind.agent, create: false, editIdKey: 'agentId'),
  'create_workflow': _build(kind: (t) => t.chat.tool.kind.workflow, create: true),
  'edit_workflow': _build(kind: (t) => t.chat.tool.kind.workflow, create: false, editIdKey: 'workflowId'),
  'create_control': _build(kind: (t) => t.chat.tool.kind.control, create: true),
  'edit_control': _build(kind: (t) => t.chat.tool.kind.control, create: false, editIdKey: 'controlId'),
  'create_approval': _build(kind: (t) => t.chat.tool.kind.approval, create: true),
  'edit_approval': _build(kind: (t) => t.chat.tool.kind.approval, create: false, editIdKey: 'approvalId'),
  'create_document': _build(kind: (t) => t.chat.tool.kind.document, create: true),
  'edit_document': _build(kind: (t) => t.chat.tool.kind.document, create: false, editIdKey: 'id'),
  'create_skill': _build(kind: (t) => t.chat.tool.kind.skill, create: true),
  'edit_skill': _build(kind: (t) => t.chat.tool.kind.skill, create: false, editIdKey: 'name'),
  'create_trigger': _build(kind: (t) => t.chat.tool.kind.trigger, create: true),
  'edit_trigger': _build(kind: (t) => t.chat.tool.kind.trigger, create: false, editIdKey: 'triggerId'),

  // ── F16 humanloop: ask_user (the danger gate is not a tool — it's the chassis awaitingConfirm phase) ──
  // 三段动词:正在提问(live)→ 等待你回答(awaiting,底盘渲门)→ 已回答/已跳过/空答案(按结果散文)。
  'ask_user': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.asking : t.chat.tool.answered,
    awaitingVerb: (t) => t.chat.tool.awaitingAnswer,
    terminalVerb: (t, s) {
      if (s.resultText.startsWith(declinedProsePrefix)) return t.chat.tool.skipped;
      if (s.resultText.trim() == askEmptyAnswerProse) return t.chat.tool.emptyAnswer;
      return t.chat.tool.answered;
    },
    target: (s) {
      final m = argString(s.argsText, 'message');
      if (m == null) return null;
      final first = m.split('\n').first.trim();
      return '"${first.length > 40 ? '${first.substring(0, 40)}…' : first}"';
    },
    receipt: (t, s) {
      // The answer's first line is the past tense's proof (only for a real answer). 答案首行=凭据。
      if (s.resultText.startsWith(declinedProsePrefix) || s.resultText.trim() == askEmptyAnswerProse) {
        return null;
      }
      final first = s.resultText.split('\n').first.trim();
      if (first.isEmpty) return null;
      final short = first.length > 48 ? '${first.substring(0, 48)}…' : first;
      return (text: '"$short"', tone: ToolReceiptTone.none);
    },
    body: askUserBody,
  ),

  // ── F16 decide_approval — the verdict (yes/no from args.decision) ──
  'decide_approval': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.deciding : t.chat.tool.decided,
    // A failed terminal (NOT_PARKED / error) means the decision never landed → neutral 已裁决, never
    // 已批准 (the row would falsely claim it took effect). 失败终态=裁决未生效→中性,不谎报已批准。
    terminalVerb: (t, s) => s.phase == ToolCardPhase.failed
        ? t.chat.tool.decided
        : switch (argString(s.argsText, 'decision')) {
            'yes' => t.chat.tool.approved,
            'no' => t.chat.tool.rejected,
            _ => t.chat.tool.decided,
          },
    target: (s) => argString(s.argsText, 'flowrunId'),
    receipt: (t, s) {
      // The flowrun's status after the decision (parse the result's flowrun.status). 裁决后 flowrun 状态。
      try {
        final d = jsonDecode(s.resultText);
        final fr = d is Map<String, dynamic> ? d['flowrun'] : null;
        final status = fr is Map<String, dynamic> ? fr['status'] as String? : null;
        if (status != null && status.isNotEmpty) return (text: status, tone: ToolReceiptTone.none);
      } catch (_) {}
      return null;
    },
    body: decideApprovalBody,
    ownsError: true, // NOT_PARKED is a product-normal, not a red crash 首决胜非红崩
  ),

  // ── F16 list_approval_inbox — zero-param, settle-only (no live window, no target chip) ──
  'list_approval_inbox': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.clearing : t.chat.tool.cleared,
    receipt: (t, s) {
      try {
        final d = jsonDecode(s.resultText);
        final count = d is Map<String, dynamic> ? (d['count'] as num?)?.toInt() : null;
        if (count != null) {
          return (
            text: count == 0 ? t.chat.tool.inboxEmpty : t.chat.tool.inboxCount(n: '$count'),
            tone: ToolReceiptTone.none
          );
        }
      } catch (_) {}
      return null;
    },
    body: listApprovalInboxBody,
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
    // The soul of the family: the little live terminal under the row. 族魂:行下活的小终端。
    liveBody: (context, s) =>
        s.progressText.isEmpty ? const SizedBox.shrink() : ToolLiveTail(text: s.progressText),
  ),
};

/// Resolve a tool's spec; unknown → generic. 解析工具规格;未知→通用。
ToolCardSpec toolCardSpecFor(String toolName) => _catalog[toolName] ?? genericToolCardSpec;
