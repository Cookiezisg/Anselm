import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';
import 'tool_card_control_approval.dart';
import 'tool_card_conversation.dart';
import 'tool_card_document_skill.dart';
import 'tool_card_exec.dart';
import 'tool_card_flowrun.dart';
import 'tool_card_fs_search.dart';
import 'tool_card_ecosystem.dart';
import 'tool_card_entity_get_bodies.dart';
import 'tool_card_lifecycle.dart';
import 'tool_card_mount.dart';
import 'tool_card_runlog.dart';
import 'tool_card_search.dart';
import 'tool_card_subagent.dart';
import 'tool_card_todo.dart';
import 'tool_card_memory_web.dart';
import 'tool_card_trigger.dart';
import 'tool_card_workflow.dart';

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
    this.hasBodyOf,
    this.awaitingVerb,
    this.terminalVerb,
    this.verbOf,
    this.resultFailed,
    this.suppressReceiptAutoExpand = false,
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

  /// STATE-AWARE running/settled verb (verb-state seam extension) — replaces [verb] for the
  /// running/argsStreaming/succeeded/failed channel when the verb depends on ARGS, not just live/settled.
  /// F07 uses it for the search↔list dual channel (empty `query` ⇒ list channel); the channel is decided
  /// only once args are COMPLETE (during argsStreaming, "query not yet arrived" vs "won't come" are
  /// indistinguishable → the closure must lock the default channel and never flip mid-stream). Sits below
  /// [terminalVerb] and above [verb] in resolution. null → plain [verb] is used.
  /// 状态感知行动词(verb-state 缝扩展):动词依赖 args 时用它;F07 搜索↔列举双声道(空 query=列),仅
  /// args 完整后判声道(流中锁默认、绝不翻面)。优先级在 terminalVerb 下、verb 上。
  final String Function(Translations t, ToolCardState state, {required bool live})? verbOf;

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

  /// CONDITIONAL bodylessness — overrides the default `state.hasBody` (which is true whenever any
  /// output exists) so a family can be «receipt IS the card» for SOME results. F07 searches use it: an
  /// empty result (count 0) has no body / no chevron (the receipt «无匹配» is the whole card), a
  /// non-empty one expands to the hit list. null → the default `state.hasBody`. 条件式无体:F07 空结果
  /// 无体无 chevron(回执即卡),有命中才展开。
  final bool Function(ToolCardState state)? hasBodyOf;

  /// «Green but broken» reclassification (F05 §4): the tool_result closed status=completed, but its
  /// PAYLOAD says it failed (restart_handler's `error` key; a document soft-fail template). Returning
  /// true makes the chassis treat this succeeded card as a FAILURE (auto-expand + error/body voice), so
  /// a green shell never hides a red fact. The family's [terminalVerb] should also switch the verb.
  /// 结果内失败重分类:工具绿但物已坏→按失败渲(自动展开),配 terminalVerb 换动词。
  final bool Function(ToolCardState state)? resultFailed;

  /// Suppress the «danger receipt → auto-expand» rule for this family (WRK-056 §F03 poll honesty): a
  /// BashOutput poll's `exited`/`errored` status is danger-COLORED but must NOT auto-expand (a dead
  /// process returns the same status every poll — auto-expanding each history card re-opens the same
  /// failure). The card can still auto-expand via [resultFailed] (BashOutput uses it only for «session
  /// gone»). 抑制「危险回执→自动展开」(BashOutput exited/errored 染红但不展开;会话不存在经 resultFailed 展开)。
  final bool suppressReceiptAutoExpand;

  /// The family body renders its OWN failure display (so the chassis skips the default error section) —
  /// for families where a non-zero terminal is a product-normal, not a red crash (decide_approval's
  /// NOT_PARKED first-decision-wins). 族体自管失败显示(底盘跳默认错误段)——如 decide_approval 的 NOT_PARKED。
  final bool ownsError;
}

/// The generic fallback (V3a behavior, unchanged). 通用兜底(V3a 行为不变)。
final ToolCardSpec genericToolCardSpec = ToolCardSpec(
  verb: (t, {required bool live}) => live ? t.chat.tool.calling : t.chat.tool.called,
  target: (s) => s.toolName,
);

/// Map an fs error string to a localized DANGER receipt (F01: every Read/Write/Edit error is a normal
/// tool_result string — the card must端正 show the failure). null = not an fs error. fs 错误→红回执。
ToolReceipt? fsErrorReceipt(Translations t, String output) {
  final e = fsErrorKind(output);
  if (e == null) return null;
  final label = switch (e.kind) {
    FsErrorKind.notFound => t.chat.tool.fsNotFound,
    FsErrorKind.denied => t.chat.tool.fsDenied,
    FsErrorKind.readFirst => t.chat.tool.fsReadFirst,
    FsErrorKind.noMatch => t.chat.tool.fsNoMatch,
    FsErrorKind.ambiguous => t.chat.tool.fsAmbiguous(n: '${e.n}'),
    FsErrorKind.modified => t.chat.tool.fsModified,
    FsErrorKind.parentMissing => t.chat.tool.fsParentMissing,
    FsErrorKind.badPath => t.chat.tool.fsBadPath,
    FsErrorKind.failed => t.chat.tool.fsFailed,
  };
  return (text: label, tone: ToolReceiptTone.danger);
}

/// The target chip for an entity-EXECUTING tool (run_function / invoke_agent / fire_trigger /
/// trigger_workflow): the backend-resolved entity NAME when present (so the header reads "Run Function
/// «sync_inventory»"), else the truncated arg id as a fallback — the name lands with the tool_call CLOSE,
/// so mid-stream (or a non-nameable target) the id still shows. 实体执行工具的目标 chip:有后端解析名用名、
/// 否则退回截断 arg id(名随 close 落定,流式中/无可命名目标时仍显 id)。
String? _nameOrIdTarget(ToolCardState s, String idKey) {
  if (s.entityName.isNotEmpty) return s.entityName;
  final id = argStringPartial(s.argsText, idKey);
  return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
}

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
      // Every fs op checks for an error FIRST (danger receipt + auto-expand); else the success receipt.
      // 每个 fs 操作先查错误(红回执+自动展开),否则成功回执。
      receipt: (t, s) => fsErrorReceipt(t, s.resultText) ?? receipt?.call(t, s),
      body: body,
      bodyless: bodyless,
    );

/// F09 aggregate-search entry — verb pair + a target chip (first present of [chipArgs]/[chipArg]) +
/// the ok✓/failed✗ rollup receipt + empty→no-body (the receipt IS the card). F09 检索族条目工厂。
ToolCardSpec _searchLog({
  required String Function(Translations) running,
  required String Function(Translations) done,
  required Widget Function(BuildContext, ToolCardState) body,
  String? chipArg,
  List<String> chipArgs = const [],
}) {
  final args = chipArg != null ? [chipArg] : chipArgs;
  return ToolCardSpec(
    verb: (t, {required bool live}) => live ? running(t) : done(t),
    // The backend-resolved entity NAME wins (search_function_executions scoped to a function → its name),
    // else the first-present id arg truncated. 后端解析名优先(检索按实体域→显名)、否则首个 id 参截断。
    target: (s) {
      if (s.entityName.isNotEmpty) return s.entityName;
      for (final a in args) {
        final v = argStringPartial(s.argsText, a);
        if (v != null && v.isNotEmpty) return v.length > 12 ? '${v.substring(0, 12)}…' : v;
      }
      return null;
    },
    receipt: (t, s) => aggregatesReceipt(t, s.resultText),
    hasBodyOf: (s) => aggregatesHasBody(s.resultText),
    body: body,
  );
}

/// F09 count-search entry (flowruns/firings/activations — no aggregates): verb pair + target chip +
/// the `N 条`/`N+ 条` receipt + empty→no-body. F09 计数检索族条目工厂。
ToolCardSpec _countLog({
  required String Function(Translations) running,
  required String Function(Translations) done,
  required Widget Function(BuildContext, ToolCardState) body,
  required String chipArg,
  required String listKey,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? running(t) : done(t),
      target: (s) {
        if (s.entityName.isNotEmpty) return s.entityName;
        final v = argStringPartial(s.argsText, chipArg);
        return v == null || v.isEmpty ? null : (v.length > 12 ? '${v.substring(0, 12)}…' : v);
      },
      receipt: (t, s) => countListReceipt(t, s.resultText, listKey),
      hasBodyOf: (s) => countListHasBody(s.resultText, listKey),
      body: body,
    );

/// F09 get-record entry — verb pair + a target chip (the record id) + the status·elapsed (or fire)
/// receipt + failed→auto-expand. F09 卷宗卡条目工厂。
ToolCardSpec _getRecord({
  required String Function(Translations) running,
  required String Function(Translations) done,
  required String chipArg,
  required ToolReceipt? Function(Translations, String) receipt,
  required bool Function(String) failed,
  required Widget Function(BuildContext, ToolCardState) body,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? running(t) : done(t),
      target: (s) {
        final v = argStringPartial(s.argsText, chipArg);
        return v == null || v.isEmpty ? null : (v.length > 12 ? '${v.substring(0, 12)}…' : v);
      },
      receipt: (t, s) => receipt(t, s.resultText),
      resultFailed: (s) => failed(s.resultText),
      body: body,
    );

ToolCardSpec _search({
  required String Function(Translations) liveVerb,
  required String Function(Translations) doneVerb,
  required String argKey,
  bool quote = true,
  required String Function(Translations, String) countLabel,
  Widget Function(BuildContext, ToolCardState)? body,
  // A custom receipt (LS/Glob parse a structured total instead of counting lines). 自定义回执。
  ToolReceipt? Function(Translations, ToolCardState)? receipt,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? liveVerb(t) : doneVerb(t),
      target: (s) {
        final v = argString(s.argsText, argKey);
        if (v == null) return null;
        return quote ? '"$v"' : pathBasename(v);
      },
      receipt: receipt ??
          (t, s) => countReceipt(s.resultText, countLabel: (n) => countLabel(t, n), noneLabel: t.chat.tool.noMatches),
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
  // Per-kind overrides: workflow swaps the code window for the growing graph (B2.5). 族覆盖:workflow 换图。
  Widget Function(BuildContext, ToolCardState)? body,
  ToolReceipt? Function(Translations, ToolCardState)? receipt,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => create
          ? (live ? t.chat.tool.creatingKind(kind: kind(t)) : t.chat.tool.createdKind(kind: kind(t)))
          : (live ? t.chat.tool.updatingKind(kind: kind(t)) : t.chat.tool.updatedKind(kind: kind(t))),
      target: (s) => create
          ? argStringPartial(s.argsText, 'name')
          : (editIdKey == null ? null : argString(s.argsText, editIdKey)),
      receipt: receipt ?? (t, s) {
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
      body: body ?? buildToolBody,
    );

/// F07 entity searches (WRK-056 §F07): the collapsed row's dual channel — SEARCH when `query` is
/// present, LIST when it's empty — decided ONLY after args complete (during argsStreaming the default
/// search channel is locked, never flipped mid-stream). The query becomes the target chip; the receipt
/// is [searchReceipt] (double-shape, nil-slice safe). `listOnly` = list_documents/list_attachments (no
/// query arg → always the list channel). The settled body (ToolHitList) lands in B3.3 — until then the
/// collapsed row is already fully specific over the generic body.
/// F07 实体搜索:双声道(有 query=搜、空=列,仅 args 完整后判)+ query chip + searchReceipt;体 B3.3 落。
ToolCardSpec _entitySearch({
  required String Function(Translations) kind,
  required String listKey,
  bool listOnly = false,
  Widget Function(BuildContext, ToolCardState)? body,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) {
        final kw = kind(t);
        return listOnly
            ? (live ? t.chat.tool.listingKind(kind: kw) : t.chat.tool.listedKind(kind: kw))
            : (live ? t.chat.tool.searchingKind(kind: kw) : t.chat.tool.searchedKind(kind: kw));
      },
      verbOf: listOnly
          ? null
          : (t, s, {required bool live}) {
              final argsComplete = s.phase != ToolCardPhase.argsStreaming;
              final q = argStringPartial(s.argsText, 'query');
              final listChannel = argsComplete && (q == null || q.trim().isEmpty);
              final kw = kind(t);
              return listChannel
                  ? (live ? t.chat.tool.listingKind(kind: kw) : t.chat.tool.listedKind(kind: kw))
                  : (live ? t.chat.tool.searchingKind(kind: kw) : t.chat.tool.searchedKind(kind: kw));
            },
      target: listOnly
          ? null
          : (s) {
              final q = argStringPartial(s.argsText, 'query');
              if (q == null || q.trim().isEmpty) return null;
              final first = q.split('\n').first.trim();
              return '"${first.length > 40 ? '${first.substring(0, 40)}…' : first}"';
            },
      receipt: (t, s) => searchReceipt(s.resultText,
          listKey: listKey,
          hits: (n) => t.chat.tool.hits(n: '$n'),
          hitsOfTotal: (n, total) => t.chat.tool.hitsOfTotal(n: '$n', total: '$total'),
          empty: listOnly ? t.chat.tool.emptyList : t.chat.tool.noMatches),
      body: body,
      // «receipt IS the card» when there are no hits — no chevron / no empty window. 空结果回执即卡。
      hasBodyOf: (s) {
        final h = parseSearchHits(s.resultText, listKey);
        return h != null && h.items.isNotEmpty;
      },
    );

/// F06 entity-get: «正在查看 X → 已查看 X»; the chip SETTLES from the args id to the output name
/// (a directory line — `已查看函数 fetch-weather`); the body is the four-part exhibit ([EntityGetBody]).
/// The receipt is the entity's version (get success ⇒ never danger — a bad env shows in the body, not
/// by hijacking the row). F06 实体 get:动词带类名词 + chip 落定换名 + 四段陈列体 + vN 回执。
ToolCardSpec _entityGet({
  required String Function(Translations) kind,
  required String idKey,
  required Widget Function(BuildContext, ToolCardState) body,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) =>
          live ? t.chat.tool.viewingKind(kind: kind(t)) : t.chat.tool.viewedKind(kind: kind(t)),
      target: (s) {
        // Settled: the chip changes from the id to the human name (the history reads like a directory).
        // 落定:chip 从 id 换成人话名(历史读起来像目录)。
        final name = argString(s.resultText, 'name');
        if (name != null && name.isNotEmpty) return name;
        return argStringPartial(s.argsText, idKey);
      },
      receipt: (t, s) {
        Map<String, dynamic>? out;
        try {
          final d = jsonDecode(s.resultText);
          if (d is Map<String, dynamic>) out = d;
        } catch (_) {}
        final v = (out?['activeVersion'] as Map?)?['version'] ?? out?['version'];
        // get success ⇒ never danger (the entity's own bad state is INFORMATION, shown in the body).
        // get 成功⇒绝不 danger(实体坏态是被看见的信息、体内讲)。
        return v == null ? null : (text: 'v$v', tone: ToolReceiptTone.none);
      },
      body: body,
    );

// ── F05 lifecycle helpers: the «极薄卡» family — verb + honest receipt + a minimal body (ref pill +
// note, or the delete audit). F05 极薄卡:动词 + 诚实回执 + 极薄体。──

/// revert: `⤺ v{version}` + a thin ref-pill note. handler's note is amber (restart + memory wipe).
/// revert:倒带徽标 + 薄 ref 注记(handler 琥珀:重启+内存抹)。
ToolCardSpec _revert({
  required String Function(Translations) kind,
  required String kindWire,
  required String idKey,
  bool handler = false,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) =>
          live ? t.chat.tool.revertingKind(kind: kind(t)) : t.chat.tool.revertedKind(kind: kind(t)),
      target: (s) => argStringPartial(s.argsText, idKey),
      receipt: (t, s) => revertReceipt(s.resultText, rewind: (v) => t.chat.tool.rewind(v: '$v')),
      body: (context, s) {
        final t = Translations.of(context);
        return lifecycleRefNote(context,
            kind: kindWire,
            id: argString(s.argsText, idKey) ?? '',
            note: handler ? t.chat.tool.noteRevertHd : t.chat.tool.noteRevertFn,
            noteColor: handler ? context.colors.warn : null);
      },
    );

/// delete: TOMBSTONE chip (mono, NOT a pill — a dead entity gets no live jump) + the impact audit.
/// `agentForm` reads the string-tail dependents; `soft` = amber (document/trigger soft delete).
/// delete:墓碑 chip(纯 mono 不可点)+ 删除审计。
ToolCardSpec _delete({
  required String Function(Translations) kind,
  required String idKey,
  bool agentForm = false,
  bool soft = false,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) =>
          live ? t.chat.tool.deletingKind(kind: kind(t)) : t.chat.tool.deletedKind2(kind: kind(t)),
      // Tombstone: the id, plain mono — the target chip is NOT a ref pill. 墓碑:纯 mono id。
      target: (s) => argStringPartial(s.argsText, idKey),
      receipt: (t, s) => deleteReceipt(s.resultText,
          deleted: t.chat.tool.deletedShort, affected: (n) => t.chat.tool.depsAffected(n: '$n'), agentForm: agentForm),
      body: deleteBody(agentForm: agentForm),
    );

/// A generic lifecycle action: verb + a computed receipt + a ref-pill note body. 通用生命周期动作。
ToolCardSpec _action({
  required String Function(Translations, {required bool live}) verb,
  required String idKey,
  required String kindWire,
  ToolReceipt? Function(Translations, ToolCardState)? receipt,
  String Function(Translations)? note,
  Color? Function(BuildContext)? noteColor,
  bool Function(ToolCardState)? resultFailed,
  String Function(Translations, ToolCardState)? terminalVerb,
}) =>
    ToolCardSpec(
      verb: verb,
      terminalVerb: terminalVerb,
      resultFailed: resultFailed,
      target: (s) => argStringPartial(s.argsText, idKey),
      receipt: receipt,
      body: (context, s) => lifecycleRefNote(context,
          kind: kindWire,
          id: argString(s.argsText, idKey) ?? '',
          note: note?.call(Translations.of(context)),
          noteColor: noteColor?.call(context)),
    );

Map<String, dynamic>? _result(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

/// A receipt when a bool key holds the expected value (stage `{staged:true}`). bool 键回执。
ToolReceipt? _lifecycleWord(String output, String key, bool expect, String label) {
  final o = _result(output);
  return o != null && o[key] == expect ? (text: label, tone: ToolReceiptTone.none) : null;
}

/// A receipt keyed off `lifecycleState` (activate → 监听中). lifecycleState 回执。
ToolReceipt? _lifecycleState(String output, Map<String, String> byState) {
  final ls = _result(output)?['lifecycleState'] as String?;
  final label = ls == null ? null : byState[ls];
  return label == null ? null : (text: label, tone: ToolReceiptTone.none);
}

/// deactivate — honest half-state: inactive → 已下线 (none) / draining → 排空中 (warn). 下线双态。
ToolReceipt? _deactivateReceipt(Translations t, String output) {
  final ls = _result(output)?['lifecycleState'] as String?;
  if (ls == 'inactive') return (text: t.chat.tool.offline, tone: ToolReceiptTone.none);
  if (ls == 'draining') return (text: t.chat.tool.draining, tone: ToolReceiptTone.warn);
  return null;
}

/// update_handler_config — `N 键` from the args `config` top-level key count. 配置键数。
ToolReceipt? _configKeysReceipt(Translations t, String argsText) {
  try {
    final d = jsonDecode(argsText);
    if (d is Map && d['config'] is Map) {
      final n = (d['config'] as Map).length;
      return n == 0 ? null : (text: t.chat.tool.nKeys(n: '$n'), tone: ToolReceiptTone.warn);
    }
  } catch (_) {}
  return null;
}

/// update_meta triplet: a DYNAMIC verb (rename when ONLY `name` is in args, else update-info — decided
/// after args complete) + a changed-field receipt (the Chinese field names from the args keys) + a
/// single-ended delta body. update_meta 三胞胎:动态动词 + 改字段回执 + 单端 delta 体。
ToolCardSpec _meta({
  required String Function(Translations) kind,
  required String kindWire,
  required String idKey,
  bool handlerNote = false,
}) =>
    ToolCardSpec(
      verb: (t, {required bool live}) => live ? t.chat.tool.updatingMeta : t.chat.tool.updatedMeta,
      // Dynamic: only-name → rename; decided after args complete (argsStreaming locks the generic pair).
      // 仅 name 键→改名对;args 完整后判(流中锁通用)。
      verbOf: (t, s, {required bool live}) {
        if (s.phase == ToolCardPhase.argsStreaming) return live ? t.chat.tool.updatingMeta : t.chat.tool.updatedMeta;
        final keys = _metaChangedKeys(s.argsText, idKey);
        final renameOnly = keys.length == 1 && keys.first == 'name';
        if (renameOnly) return live ? t.chat.tool.renaming : t.chat.tool.renamed;
        return live ? t.chat.tool.updatingMeta : t.chat.tool.updatedMeta;
      },
      target: (s) => argStringPartial(s.argsText, idKey),
      receipt: (t, s) {
        final labels = _metaChangedKeys(s.argsText, idKey)
            .map((k) => switch (k) {
                  'name' => t.chat.tool.kvName,
                  'description' => t.chat.tool.kvDescription,
                  'tags' => t.chat.tool.kvTags,
                  _ => k,
                })
            .toList();
        return labels.isEmpty ? null : (text: labels.join(' · '), tone: ToolReceiptTone.none);
      },
      body: (context, s) {
        final t = Translations.of(context);
        return metaDeltaBody(context, kindWire: kindWire, id: argString(s.argsText, idKey) ?? '',
            argsText: s.argsText, idKey: idKey, note: handlerNote ? t.chat.tool.noteMetaHandler : null);
      },
    );

/// The changed meta keys present in the args (excluding the id key). Rename detection + receipt source.
/// args 里出现的可改元数据键(排除 id 键)。
List<String> _metaChangedKeys(String argsText, String idKey) {
  final keys = <String>[];
  for (final k in ['name', 'description', 'tags']) {
    if (RegExp('"$k"\\s*:').hasMatch(argsText)) keys.add(k);
  }
  return keys;
}

/// The family table — keyed by exact tool name. 族表,按精确工具名键。
final Map<String, ToolCardSpec> _catalog = {
  // ── F1 fs-ops 文件操作 ──
  'Read': _fsOp(
    liveVerb: (t) => t.chat.tool.reading,
    doneVerb: (t) => t.chat.tool.read,
    // Four-quadrant receipt: L 行 / 行 F–L / N+ 行 / 行 F–N+. 四象限。
    receipt: (t, s) => readReceipt(s.resultText,
        lines: (l) => t.chat.tool.lines(n: '$l'),
        range: (f, l) => t.chat.tool.readRange(f: '$f', l: '$l'),
        linesFloor: (n) => t.chat.tool.readFloor(n: '$n'),
        rangeFloor: (f, n) => t.chat.tool.readRangeFloor(f: '$f', n: '$n')),
    bodyless: true, // the receipt IS the card 回执即卡
  ),
  'Write': _fsOp(
    liveVerb: (t) => t.chat.tool.writing,
    doneVerb: (t) => t.chat.tool.wrote,
    receipt: (t, s) {
      // Write success = `Wrote <path>` — the receipt is the content's line count (empty → 空文件, body
      // hidden). A non-«Wrote» / non-error result → grey «结果未确认» (a past-tense verb over an
      // unconfirmed write would read as success). 写成功=行数;空→空文件;非确认→灰「结果未确认」。
      final content = argString(s.argsText, 'content');
      if (s.resultText.isNotEmpty && !s.resultText.trimLeft().startsWith('Wrote ')) {
        return (text: t.chat.tool.fsUnconfirmed, tone: ToolReceiptTone.warn);
      }
      if (content == null || content.isEmpty) return (text: t.chat.tool.emptyFile, tone: ToolReceiptTone.none);
      return (text: t.chat.tool.lines(n: '${'\n'.allMatches(content).length + 1}'), tone: ToolReceiptTone.none);
    },
    // The F01 «生长秀» lives in the body's in-flight face (WRK-065). 生长秀在体的活脸里。
    body: writeToolBody,
  ),
  'Edit': _fsOp(
    liveVerb: (t) => t.chat.tool.editing,
    doneVerb: (t) => t.chat.tool.edited,
    receipt: (t, s) {
      // Edit success = `Replaced N occurrence(s) in <path>.` → «N 处替换»; a non-«Replaced» / non-error
      // result → grey «结果未确认». Edit 成功=N 处替换;非确认→灰。
      final m = RegExp(r'Replaced (\d+) occurrence').firstMatch(s.resultText);
      if (m != null) return (text: t.chat.tool.edited2(n: m.group(1)!), tone: ToolReceiptTone.none);
      if (s.resultText.isNotEmpty) return (text: t.chat.tool.fsUnconfirmed, tone: ToolReceiptTone.warn);
      return null;
    },
    // The surgery two-act lives in the body's in-flight face (WRK-065). 手术两幕在体的活脸里。
    body: editToolBody,
  ),

  // ── F2 fs-search 文件检索 ──
  'Glob': _search(
    liveVerb: (t) => t.chat.tool.globbing,
    doneVerb: (t) => t.chat.tool.globbed,
    argKey: 'pattern',
    countLabel: (t, n) => t.chat.tool.items(n: n), // items, not files (matches include dir/link) 含目录/链接
    // The count comes from the JSON `total` (truncated → N+); a non-JSON result → the error/timeout string
    // is handled by the body. 计数取 JSON total(截断→N+);非 JSON=错误/超时。
    receipt: (t, s) {
      final g = parseGlobResult(s.resultText);
      if (g == null) return null; // error/timeout string → no count receipt
      if (g.total == 0) return (text: t.chat.tool.noMatches, tone: ToolReceiptTone.none);
      return (text: t.chat.tool.items(n: g.truncated ? '${g.total}+' : '${g.total}'), tone: ToolReceiptTone.none);
    },
    body: globToolBody,
  ),
  'Grep': _search(
    liveVerb: (t) => t.chat.tool.grepping,
    doneVerb: (t) => t.chat.tool.grepped,
    argKey: 'pattern',
    countLabel: (t, n) => t.chat.tool.matches(n: n),
    body: grepToolBody, // content view / count heat / files list by output_mode. 按 output_mode 分派。
  ),
  'LS': _search(
    liveVerb: (t) => t.chat.tool.listing,
    doneVerb: (t) => t.chat.tool.listed,
    argKey: 'path',
    quote: false,
    countLabel: (t, n) => t.chat.tool.items(n: n),
    // The count is the header's `(T entries)` total (truncated → N+). 计数=头部 entries 总数。
    receipt: (t, s) {
      final ls = parseLsListing(s.resultText);
      if (ls == null) return null; // error string → no receipt
      if (ls.total == 0) return (text: t.chat.tool.lsEmpty, tone: ToolReceiptTone.none);
      return (text: t.chat.tool.items(n: ls.truncated ? '${ls.total}+' : '${ls.total}'), tone: ToolReceiptTone.none);
    },
    body: lsToolBody,
  ),

  // ── F4 builds 构建族 ──
  'create_function': _build(kind: (t) => t.chat.tool.kind.function, create: true),
  'edit_function': _build(kind: (t) => t.chat.tool.kind.function, create: false, editIdKey: 'functionId'),
  'create_handler': _build(kind: (t) => t.chat.tool.kind.handler, create: true),
  'edit_handler': _build(kind: (t) => t.chat.tool.kind.handler, create: false, editIdKey: 'handlerId'),
  'create_agent': _build(kind: (t) => t.chat.tool.kind.agent, create: true),
  'edit_agent': _build(kind: (t) => t.chat.tool.kind.agent, create: false, editIdKey: 'agentId'),
  // create_workflow ★ two-act growth show: op ticker (streaming) → graph replaying its growth (settled).
  // create_workflow 两幕生长秀:op ticker → 图回放生长。
  'create_workflow': _build(
    kind: (t) => t.chat.tool.kind.workflow,
    create: true,
    body: workflowBuildBody,
    receipt: workflowCreateReceipt,
  ),
  // edit_workflow ★ morph roster: the delta (added/updated/deleted from the ops) — the pure-delta form
  // (after-graph canvas needs the fetch seam #50). edit_workflow morph 花名册(纯 delta 形)。
  'edit_workflow': _build(
    kind: (t) => t.chat.tool.kind.workflow,
    create: false,
    editIdKey: 'workflowId',
    body: editWorkflowBody,
  ),
  // control ★ decision ladder / approval ★ form preview — whole-set replace → always the full snapshot.
  // control 决策梯 / approval 表单预览——整体替换,永远渲全新快照。
  'create_control': _build(kind: (t) => t.chat.tool.kind.control, create: true, body: controlBranchBody),
  'edit_control': _build(
      kind: (t) => t.chat.tool.kind.control, create: false, editIdKey: 'controlId', body: controlBranchBody),
  'create_approval': _build(kind: (t) => t.chat.tool.kind.approval, create: true, body: approvalFormBody),
  'edit_approval': _build(
      kind: (t) => t.chat.tool.kind.approval, create: false, editIdKey: 'approvalId', body: approvalFormBody),
  // document ★ typeset prose window + soft-fail sentence receipt; skill ★ prose + allowedTools warn 药丸.
  // document 排版稿子流 + 软失败句回执;skill 稿子 + allowedTools 警示药丸。
  'create_document': _build(
      kind: (t) => t.chat.tool.kind.document, create: true, body: documentBody, receipt: docSentenceReceipt),
  'edit_document': _build(
      kind: (t) => t.chat.tool.kind.document, create: false, editIdKey: 'id', body: documentBody, receipt: docSentenceReceipt),
  'create_skill': _build(
      kind: (t) => t.chat.tool.kind.skill, create: true, body: skillBody, receipt: skillReceipt),
  'edit_skill': _build(
      kind: (t) => t.chat.tool.kind.skill, create: false, editIdKey: 'name', body: skillBody, receipt: skillReceipt),
  // trigger ★ TriggerConfigCard — one of FOUR faces by kind (cron/webhook/fsnotify/sensor); create
  // returns 未监听 (an active workflow reference starts it), edit hot-updates a live trigger.
  // trigger 四 kind 配置脸;创建=未监听、编辑=热更新。
  'create_trigger': _build(
      kind: (t) => t.chat.tool.kind.trigger, create: true, body: triggerConfigBody, receipt: triggerReceipt),
  'edit_trigger': _build(
      kind: (t) => t.chat.tool.kind.trigger, create: false, editIdKey: 'triggerId', body: triggerConfigBody, receipt: triggerReceipt),

  // ── F07 searches: dual-channel verb (search↔list) + query chip + searchReceipt (double-shape,
  // nil-safe). listKey = the plural entity name; the settled ToolHitList body lands in B3.3.
  // F07 检索:双声道动词 + query chip + searchReceipt(双形状、nil 安全);命中窗体 B3.3 落。──
  'search_function': _entitySearch(
      kind: (t) => t.chat.tool.kind.function,
      listKey: 'functions',
      body: searchHitBody(listKey: 'functions', cap: 20, row: (t, h) => entityHitRow('function', h))),
  'search_handler': _entitySearch(
      kind: (t) => t.chat.tool.kind.handler,
      listKey: 'handlers',
      body: searchHitBody(listKey: 'handlers', cap: 20, row: (t, h) => entityHitRow('handler', h))),
  'search_agent': _entitySearch(
      kind: (t) => t.chat.tool.kind.agent,
      listKey: 'agents',
      body: searchHitBody(listKey: 'agents', cap: 20, row: (t, h) => entityHitRow('agent', h))),
  'search_workflow': _entitySearch(
      kind: (t) => t.chat.tool.kind.workflow,
      listKey: 'workflows',
      body: searchHitBody(listKey: 'workflows', cap: 20, row: workflowHitRow)),
  'search_control': _entitySearch(
      kind: (t) => t.chat.tool.kind.control,
      listKey: 'controls',
      body: searchHitBody(listKey: 'controls', cap: 20, row: (t, h) => entityHitRow('control', h))),
  'search_approval': _entitySearch(
      kind: (t) => t.chat.tool.kind.approval,
      listKey: 'approvals',
      body: searchHitBody(listKey: 'approvals', cap: 20, row: (t, h) => entityHitRow('approval', h))),
  'search_documents': _entitySearch(
      kind: (t) => t.chat.tool.kind.document,
      listKey: 'documents',
      body: searchHitBody(listKey: 'documents', cap: 20, row: (t, h) => entityHitRow('document', h))),
  'search_triggers': _entitySearch(
      kind: (t) => t.chat.tool.kind.trigger,
      listKey: 'triggers',
      body: searchHitBody(listKey: 'triggers', cap: 20, row: triggerHitRow)),
  'search_blocks': _entitySearch(
      kind: (t) => t.chat.tool.kind.blocks,
      listKey: 'blocks',
      body: searchHitBody(listKey: 'blocks', cap: 20, row: (t, h) => blockHitRow(h))),
  // The two bounded list_* tools carry no query — always the list channel (cap 30). list_* 无 query,恒列。
  'list_documents': _entitySearch(
      kind: (t) => t.chat.tool.kind.document,
      listKey: 'documents',
      listOnly: true,
      body: searchHitBody(listKey: 'documents', cap: 30, row: (t, h) => documentListRow(h))),
  'list_attachments': _entitySearch(
      kind: (t) => t.chat.tool.kind.attachment,
      listKey: 'attachments',
      listOnly: true,
      body: searchHitBody(listKey: 'attachments', cap: 30, row: (t, h) => attachmentListRow(h))),

  // ── F06 entity-get: «正在查看 X → 已查看 X»; chip settles id→name; the four-part exhibit body.
  // F06 实体 get:动词带类名词 + chip 落定换名 + 四段陈列体。──
  'get_function': _entityGet(kind: (t) => t.chat.tool.kind.function, idKey: 'functionId', body: f06GetBodies['get_function']!),
  'get_handler': _entityGet(kind: (t) => t.chat.tool.kind.handler, idKey: 'handlerId', body: f06GetBodies['get_handler']!),
  'get_agent': _entityGet(kind: (t) => t.chat.tool.kind.agent, idKey: 'agentId', body: f06GetBodies['get_agent']!),
  'get_workflow': _entityGet(kind: (t) => t.chat.tool.kind.workflow, idKey: 'workflowId', body: f06GetBodies['get_workflow']!),
  'get_control': _entityGet(kind: (t) => t.chat.tool.kind.control, idKey: 'controlId', body: f06GetBodies['get_control']!),
  'get_approval': _entityGet(kind: (t) => t.chat.tool.kind.approval, idKey: 'approvalId', body: f06GetBodies['get_approval']!),
  'get_skill': _entityGet(kind: (t) => t.chat.tool.kind.skill, idKey: 'name', body: f06GetBodies['get_skill']!),
  'get_trigger': _entityGet(kind: (t) => t.chat.tool.kind.trigger, idKey: 'triggerId', body: f06GetBodies['get_trigger']!),
  // read_document / read_attachment — string TEMPLATE results (not JSON): the chip settles to the parsed
  // name; the body renders the prose / the extracted text. read 串模板:chip 落定换名 + 排版/抽取正文体。
  'read_document': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.readingDoc : t.chat.tool.readDoc,
    target: (s) {
      // settled: the `# <name>` heading; live: the args id. 落定:# 标题;live:args id。
      final first = s.resultText.startsWith('# ') ? s.resultText.split('\n').first.substring(2).trim() : null;
      return (first != null && first.isNotEmpty) ? first : argStringPartial(s.argsText, 'id');
    },
    body: readDocumentBody,
  ),
  'read_attachment': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.readingAtt : t.chat.tool.readAtt,
    target: (s) => argStringPartial(s.argsText, 'id'),
    body: readAttachmentBody,
  ),

  // ── F05 lifecycle: 26 thin cards (revert×6 / delete×9 / workflow 生杀四将 / restart / activate_skill /
  // move / update_meta×3 / config). 极薄卡:一行陈述 + 不可抵赖凭据。──
  'revert_function': _revert(kind: (t) => t.chat.tool.kind.function, kindWire: 'function', idKey: 'functionId'),
  'revert_handler': _revert(kind: (t) => t.chat.tool.kind.handler, kindWire: 'handler', idKey: 'handlerId', handler: true),
  'revert_agent': _revert(kind: (t) => t.chat.tool.kind.agent, kindWire: 'agent', idKey: 'agentId'),
  'revert_workflow': _revert(kind: (t) => t.chat.tool.kind.workflow, kindWire: 'workflow', idKey: 'workflowId'),
  'revert_control': _revert(kind: (t) => t.chat.tool.kind.control, kindWire: 'control', idKey: 'controlId'),
  'revert_approval': _revert(kind: (t) => t.chat.tool.kind.approval, kindWire: 'approval', idKey: 'approvalId'),
  'delete_function': _delete(kind: (t) => t.chat.tool.kind.function, idKey: 'functionId'),
  'delete_handler': _delete(kind: (t) => t.chat.tool.kind.handler, idKey: 'handlerId'),
  'delete_agent': _delete(kind: (t) => t.chat.tool.kind.agent, idKey: 'agentId', agentForm: true),
  'delete_workflow': _delete(kind: (t) => t.chat.tool.kind.workflow, idKey: 'workflowId'),
  'delete_control': _delete(kind: (t) => t.chat.tool.kind.control, idKey: 'controlId'),
  'delete_approval': _delete(kind: (t) => t.chat.tool.kind.approval, idKey: 'approvalId'),
  'delete_skill': _delete(kind: (t) => t.chat.tool.kind.skill, idKey: 'name'),
  'delete_trigger': _delete(kind: (t) => t.chat.tool.kind.trigger, idKey: 'triggerId', soft: true),
  // delete_document: SOFT (amber, recoverable) — string template receipt + soft-fail reclassification.
  'delete_document': ToolCardSpec(
    verb: (t, {required bool live}) =>
        live ? t.chat.tool.deletingKind(kind: t.chat.tool.kind.document) : t.chat.tool.deletedKind2(kind: t.chat.tool.kind.document),
    target: (s) => argStringPartial(s.argsText, 'id'),
    receipt: (t, s) => deletedDocReceipt(s.resultText,
        deleted: t.chat.tool.deletedShort, withDescendants: (n) => t.chat.tool.docDescendants(n: '$n')),
    body: (context, s) => lifecycleRefNote(context, kind: 'document', id: argString(s.argsText, 'id') ?? '', note: Translations.of(context).chat.tool.noteDeleteDocSoft),
  ),
  // workflow 生杀四将
  'stage_workflow': _action(
    verb: (t, {required bool live}) => live ? t.chat.tool.staging : t.chat.tool.staged,
    idKey: 'workflowId', kindWire: 'workflow',
    receipt: (t, s) => _lifecycleWord(s.resultText, 'staged', true, t.chat.tool.staged2),
    note: (t) => t.chat.tool.noteStage,
  ),
  'activate_workflow': _action(
    verb: (t, {required bool live}) => live ? t.chat.tool.activatingWf : t.chat.tool.activatedWf,
    idKey: 'workflowId', kindWire: 'workflow',
    receipt: (t, s) => _lifecycleState(s.resultText, {'active': t.chat.tool.listening2}),
  ),
  'deactivate_workflow': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.deactivatingWf : t.chat.tool.deactivatedWf,
    target: (s) => argStringPartial(s.argsText, 'workflowId'),
    receipt: (t, s) => _deactivateReceipt(t, s.resultText),
    // draining → an amber body note explaining the half-state (kept OUT of the row receipt). draining 注记。
    body: (context, s) {
      final draining = _result(s.resultText)?['lifecycleState'] == 'draining';
      return lifecycleRefNote(context,
          kind: 'workflow',
          id: argString(s.argsText, 'workflowId') ?? '',
          note: draining ? Translations.of(context).chat.tool.noteDraining : null,
          noteColor: draining ? context.colors.warn : null);
    },
  ),
  'kill_workflow': _action(
    verb: (t, {required bool live}) => live ? t.chat.tool.killingWf : t.chat.tool.killedWf,
    idKey: 'workflowId', kindWire: 'workflow',
    receipt: (t, s) => killReceipt(s.resultText, killedN: (n) => t.chat.tool.killedN(n: '$n'), none: t.chat.tool.noInflight),
    note: (t) => t.chat.tool.noteKill,
  ),
  // restart_handler — the «green but broken» flagship (error key → failed reclassification).
  'restart_handler': _action(
    verb: (t, {required bool live}) => live ? t.chat.tool.restarting : t.chat.tool.restarted,
    idKey: 'handlerId', kindWire: 'handler',
    receipt: (t, s) => restartReceipt(s.resultText, label: (rs) => rs,
        errored: (e) => '${t.chat.tool.restartFailed}: $e'),
    resultFailed: (s) => (_result(s.resultText)?['error'] as String?)?.isNotEmpty == true,
    note: (t) => t.chat.tool.noteRestart, noteColor: (c) => c.colors.warn,
  ),
  'activate_skill': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.activatingSkill : t.chat.tool.activatedSkill,
    target: (s) => argStringPartial(s.argsText, 'name'),
    // The injected output is an instruction payload → a capped machine window (fork answers have no
    // panel; 6000 cap). 注入载荷→capped 机器窗。
    body: (context, s) => activateSkillBody(context, s),
  ),
  'move_document': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.movingDoc : t.chat.tool.movedDoc,
    target: (s) => argStringPartial(s.argsText, 'id'),
    receipt: (t, s) => movedReceipt(s.resultText, toPath: (p) => t.chat.tool.movedTo(path: p)),
    body: (context, s) => lifecycleRefNote(context, kind: 'document', id: argString(s.argsText, 'id') ?? ''),
  ),
  // update_meta triplet — dynamic verb (rename when only `name` in args) + changed-field receipt.
  'update_function_meta': _meta(kind: (t) => t.chat.tool.kind.function, kindWire: 'function', idKey: 'functionId'),
  'update_handler_meta': _meta(kind: (t) => t.chat.tool.kind.handler, kindWire: 'handler', idKey: 'handlerId', handlerNote: true),
  'update_agent_meta': _meta(kind: (t) => t.chat.tool.kind.agent, kindWire: 'agent', idKey: 'agentId'),
  'update_handler_config': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.configuring : t.chat.tool.configured,
    target: (s) => argStringPartial(s.argsText, 'handlerId'),
    receipt: (t, s) => _configKeysReceipt(t, s.argsText),
    body: (context, s) => lifecycleRefNote(context, kind: 'handler', id: argString(s.argsText, 'handlerId') ?? '', note: Translations.of(context).chat.tool.noteConfig, noteColor: context.colors.warn),
  ),

  // ── F17 conversation: 3 thin cards. manage = action-dispatched verb + status echo (rename plays
  // through the autoname typewriter off-card); list/search = a mini-rail of tappable doors.
  // F17 对话薄卡:manage 状态回显 / list·search 迷你 rail 命中门。──
  'manage_conversation': ToolCardSpec(
    verbOf: (t, s, {required bool live}) => manageConversationVerb(t, s, live: live),
    verb: (t, {required bool live}) => live ? t.chat.tool.cvManaging : t.chat.tool.cvManaged,
    // Only rename carries a target chip: the new title (args → output on settle). 仅 rename 显标题 chip。
    target: (s) {
      final live = argStringPartial(s.argsText, 'title');
      final settled = argString(s.resultText, 'title');
      return (settled != null && settled.isNotEmpty) ? settled : live;
    },
    body: manageConversationBody,
  ),
  'list_conversations': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.cvListing : t.chat.tool.cvListed,
    target: (s) {
      // 含归档 / 续页 chips (argStringPartial can't read a bool/cursor cheaply — probe the args). chip。
      final incl = RegExp(r'"includeArchived"\s*:\s*true').hasMatch(s.argsText);
      final cursor = RegExp(r'"cursor"\s*:\s*"').hasMatch(s.argsText);
      final parts = <String>[];
      // (labels resolved lazily in the row; here we just signal presence via a mono word)
      if (incl) parts.add('archived');
      if (cursor) parts.add('cursor');
      return parts.isEmpty ? null : parts.join(' · ');
    },
    receipt: (t, s) => listConversationsReceipt(t, s.resultText),
    hasBodyOf: (s) => conversationHasBody(s.resultText, isSearch: false),
    body: conversationHitBody(isSearch: false),
  ),
  'search_conversations': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.cvSearching : t.chat.tool.cvSearched,
    target: (s) {
      final q = argStringPartial(s.argsText, 'query');
      return (q == null || q.trim().isEmpty) ? null : '"${q.trim()}"';
    },
    receipt: (t, s) => searchConversationsReceipt(t, s.resultText),
    hasBodyOf: (s) => conversationHasBody(s.resultText, isSearch: true),
    body: conversationHitBody(isSearch: true),
  ),

  // ── F08 exec: «input → black box → output» made auditable (ToolIOSection). run_function/call_handler
  // share the ExecutionResult shape. F08 执行:输入→黑箱→输出的可核账凭据。──
  'run_function': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.runningFn : t.chat.tool.ranFn,
    // Prefer the backend-resolved entity NAME (Run Function «sync_inventory»); fall back to the arg id
    // while it's still streaming or when the target isn't nameable. 优先后端解析名、退回 arg id。
    target: (s) => _nameOrIdTarget(s, 'functionId'),
    receipt: (t, s) => execReceipt(t, s.resultText),
    resultFailed: (s) => execResultFailed(s.resultText),
    body: runFunctionBody,
  ),
  'call_handler': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.callingMethod : t.chat.tool.calledMethod,
    target: (s) {
      final m = argString(s.argsText, 'method');
      return m == null ? null : '$m()';
    },
    // A scalar result → a value preview `→ v`; else no receipt (the body shows it). 标量→值预览。
    receipt: (t, s) {
      try {
        final d = jsonDecode(s.resultText);
        if (d is Map && d.containsKey('result')) {
          final r = d['result'];
          if (r is String || r is num || r is bool) {
            final v = r is String ? '"$r"' : '$r';
            return (text: '→ ${v.length > 24 ? '${v.substring(0, 24)}…' : v}', tone: ToolReceiptTone.none);
          }
        }
      } catch (_) {}
      return null;
    },
    body: callHandlerBody,
  ),
  // invoke_agent — run an agent (chip=agentId; failed/timeout→auto-expand; cancelled stays grey). The
  // LIVE nested trajectory (NestedRunPane) is B6; this is the settled body. invoke_agent 落定卡。
  'invoke_agent': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.invokingAgent : t.chat.tool.invokedAgent,
    target: (s) => _nameOrIdTarget(s, 'agentId'),
    receipt: (t, s) => invokeReceipt(t, s.resultText),
    resultFailed: (s) => invokeResultFailed(s.resultText),
    body: invokeAgentBody,
  ),
  // fire_trigger — the thin activation card (chip=triggerId, receipt=activationId; never danger). 薄卡。
  'fire_trigger': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.firingTrigger : t.chat.tool.firedTrigger,
    target: (s) => _nameOrIdTarget(s, 'triggerId'),
    receipt: (t, s) => fireReceipt(t, s.resultText),
    body: fireTriggerBody,
  ),
  // trigger_workflow — the async «run now» card (chip=workflowId, receipt=flowrunId; never danger).
  // 异步「立即运行」薄卡。
  'trigger_workflow': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.triggeringWf : t.chat.tool.triggeredWf,
    target: (s) => _nameOrIdTarget(s, 'workflowId'),
    receipt: (t, s) => triggerWorkflowReceipt(t, s.resultText),
    body: triggerWorkflowBody,
  ),
  // replay_flowrun — the node-ledger card (chip=flowrunId; failed→auto-expand; run header has no
  // parked, so «awaiting approval» is read off the nodes). replay 节点台账卡。
  'replay_flowrun': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.replayingRun : t.chat.tool.replayedRun,
    target: (s) {
      final id = argStringPartial(s.argsText, 'flowrunId');
      return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
    },
    receipt: (t, s) => replayReceipt(t, s.resultText),
    resultFailed: (s) => replayResultFailed(s.resultText),
    body: replayFlowrunBody,
  ),

  // ── F09 run-log search (aggregate families: fn exec / hd calls / agent runs / mcp calls) ──
  // All share {list, nextCursor?, hasMore, aggregates}; body = bead strip + slim RunLedger; the receipt
  // is the ok✓/failed✗ rollup (grey — archive failures aren't THIS call failing). F09 检索族。
  'search_function_executions': _searchLog(
      running: (t) => t.chat.tool.searchingFnExec, done: (t) => t.chat.tool.searchedFnExec,
      chipArg: 'functionId', body: fnExecBody),
  'search_handler_calls': _searchLog(
      running: (t) => t.chat.tool.searchingHdCalls, done: (t) => t.chat.tool.searchedHdCalls,
      chipArg: 'handlerId', body: hdCallsBody),
  'search_agent_executions': _searchLog(
      running: (t) => t.chat.tool.searchingAgentExec, done: (t) => t.chat.tool.searchedAgentExec,
      chipArgs: const ['agentId', 'conversationId', 'flowrunId'], body: agentExecBody),
  'search_mcp_calls': _searchLog(
      running: (t) => t.chat.tool.searchingMcpCalls, done: (t) => t.chat.tool.searchedMcpCalls,
      chipArg: 'serverId', body: mcpCallsBody),
  // Count families (no aggregates — never fabricate a ✓/✗ split): flowruns / firings / activations.
  'search_flowruns': _countLog(
      running: (t) => t.chat.tool.searchingFlowruns, done: (t) => t.chat.tool.searchedFlowruns,
      chipArg: 'workflowId', listKey: 'runs', body: flowrunsBody),
  'search_firings': _countLog(
      running: (t) => t.chat.tool.searchingFirings, done: (t) => t.chat.tool.searchedFirings,
      chipArg: 'triggerId', listKey: 'firings', body: firingsBody),
  'search_activations': _countLog(
      running: (t) => t.chat.tool.searchingActivations, done: (t) => t.chat.tool.searchedActivations,
      chipArg: 'triggerId', listKey: 'activations', body: activationsBody),
  // ── F09 get-record (thin dossiers): fn exec / hd call / mcp call / activation ──
  // The receipt is status·elapsed (failed/timeout → danger auto-expand — you opened it to triage); the
  // body is a RunDossier (or, for activations, a bespoke fire record). F09 卷宗卡。
  'get_function_execution': _getRecord(
      running: (t) => t.chat.tool.gettingFnExec, done: (t) => t.chat.tool.gotFnExec,
      chipArg: 'executionId', receipt: execRecordReceipt, failed: execRecordFailed, body: getFnExecBody),
  'get_handler_call': _getRecord(
      running: (t) => t.chat.tool.gettingHdCall, done: (t) => t.chat.tool.gotHdCall,
      chipArg: 'callId', receipt: execRecordReceipt, failed: execRecordFailed, body: getHdCallBody),
  'get_mcp_call': _getRecord(
      running: (t) => t.chat.tool.gettingMcpCall, done: (t) => t.chat.tool.gotMcpCall,
      chipArg: 'callId', receipt: execRecordReceipt, failed: execRecordFailed, body: getMcpCallBody),
  'get_activation': _getRecord(
      running: (t) => t.chat.tool.gettingActivation, done: (t) => t.chat.tool.gotActivation,
      chipArg: 'activationId', receipt: activationFireReceipt, failed: activationRecordFailed, body: getActivationBody),
  // get_flowrun — the run cockpit read (run header + FlowrunNodeList + provenance). Same shape as
  // replay; failed run → danger auto-expand. get_flowrun 运行解剖卡。
  'get_flowrun': _getRecord(
      running: (t) => t.chat.tool.gettingFlowrun, done: (t) => t.chat.tool.gotFlowrun,
      chipArg: 'flowrunId', receipt: getFlowrunReceipt, failed: getFlowrunFailed, body: getFlowrunBody),
  // get_agent_execution — the heavy dossier (head + modelId/provider + input/output + TranscriptPeek).
  // The transcript is hydrated through the shared adapter (live-path parity). get_agent_execution 重卡。
  'get_agent_execution': _getRecord(
      running: (t) => t.chat.tool.gettingAgentExec, done: (t) => t.chat.tool.gotAgentExec,
      chipArg: 'executionId', receipt: execRecordReceipt, failed: execRecordFailed, body: getAgentExecBody),

  // ── F12 relations + F13 mcp-mgmt + capability/model (B7.2 ecosystem tail) ──
  'get_relations': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.gettingRelations : t.chat.tool.gotRelations,
    target: (s) {
      final id = argStringPartial(s.argsText, 'id');
      return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
    },
    receipt: (t, s) => relationsReceipt(t, s.resultText),
    body: relationsBody,
  ),
  'capability_check_workflow': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.checkingCapability : t.chat.tool.checkedCapability,
    target: (s) {
      final id = argStringPartial(s.argsText, 'workflowId');
      return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
    },
    receipt: (t, s) => capabilityReceipt(t, s.resultText),
    resultFailed: (s) => capabilityFailed(s.resultText),
    body: capabilityBody,
  ),
  'install_mcp_server': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.installingMcp : t.chat.tool.installedMcp,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: (t, s) => mcpStatusReceipt(t, s.resultText),
    resultFailed: (s) => mcpStatusFailed(s.resultText),
    body: mcpStatusBody,
  ),
  'uninstall_mcp_server': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.uninstallingMcp : t.chat.tool.uninstalledMcp,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: (t, s) => mcpStatusReceipt(t, s.resultText),
    body: mcpStatusBody,
  ),
  'reconnect_mcp': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.reconnectingMcp : t.chat.tool.reconnectedMcp,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: (t, s) => mcpStatusReceipt(t, s.resultText),
    resultFailed: (s) => mcpStatusFailed(s.resultText),
    body: mcpStatusBody,
  ),
  'list_mcp_marketplace': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.browsingMarket : t.chat.tool.browsedMarket,
    receipt: (t, s) => marketplaceReceipt(t, s.resultText),
    body: marketplaceBody,
  ),
  'get_model_config': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.gettingModelConfig : t.chat.tool.gotModelConfig,
    receipt: (t, s) => modelConfigReceipt(t, s.resultText),
    body: modelConfigBody,
  ),

  // ── F11 todo: the task checklist (todo_write carries the full list in args; todo_read the rendered) ──
  'todo_write': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.todoWriting : t.chat.tool.todoWrote,
    receipt: (t, s) => todoReceipt(t, argsJson: s.argsText, rendered: s.resultText),
    body: todoWriteBody,
  ),
  'todo_read': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.todoReading : t.chat.tool.todoRead,
    receipt: (t, s) => todoReceipt(t, rendered: s.resultText),
    body: todoReadBody,
  ),

  // ── F15 nested conversation: Subagent (spawn a sub-task) + get_subagent_trace (read it back) ──
  // The Subagent's E3 trajectory streams live under the card (NestedRunPane); its result IS the final
  // answer string. get_subagent_trace reads the durable record (list / one run's hydrated blocks). F15。
  'Subagent': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.spawningSubagent : t.chat.tool.spawnedSubagent,
    target: (s) => argStringPartial(s.argsText, 'subagent_type'),
    body: subagentBody,
  ),
  'get_subagent_trace': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.gettingSubTrace : t.chat.tool.gotSubTrace,
    target: (s) {
      final v = argStringPartial(s.argsText, 'subagentRunId');
      return v == null || v.isEmpty ? null : (v.length > 12 ? '${v.substring(0, 12)}…' : v);
    },
    receipt: (t, s) => subTraceReceipt(t, s.resultText),
    body: getSubTraceBody,
  ),

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
    // Background variant: a `run_in_background:true` arg (or the settled background-spawn result) → «已转入
    // 后台» instead of «已运行命令» (the command detached, it didn't complete). 后台变体动词。
    verbOf: (t, s, {required bool live}) {
      final bg = RegExp(r'"run_in_background"\s*:\s*true').hasMatch(s.argsText) ||
          s.resultText.startsWith('Started background command');
      if (!bg) return live ? t.chat.tool.runningCmd : t.chat.tool.ranCmd;
      return live ? t.chat.tool.runningCmd : t.chat.tool.ranBg;
    },
    target: (s) {
      final c = argString(s.argsText, 'command');
      return c == null ? null : commandChip(c);
    },
    receipt: (t, s) => bashReceipt(s.resultText,
        exitLabel: (code) => t.chat.tool.exit(code: code),
        timedOutLabel: t.chat.tool.timedOut,
        blockedLabel: t.chat.tool.bashBlocked,
        cancelledLabel: t.chat.tool.bashCancelled,
        exitUnknownLabel: t.chat.tool.bashExitUnknown,
        // Short id in the row receipt (the full copyable bsh_id is in the body). 收起行短 id。
        backgroundLabel: (id) => t.chat.tool.bashBackground(id: id.length > 10 ? '${id.substring(0, 10)}…' : id)),
    // The family's soul — the live terminal — is the body's in-flight face (WRK-065). 族魂活终端在体内。
    body: bashToolBody,
  ),
  // BashOutput (B4.6): poll a background session — bsh_id chip + status receipt + terminal body.
  // BashOutput:轮询后台会话——bsh_id chip + status 回执 + 终端体。
  'BashOutput': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.polling : t.chat.tool.polled,
    target: (s) {
      final id = argStringPartial(s.argsText, 'bash_id');
      return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
    },
    receipt: (t, s) => statusReceipt(s.resultText,
        running: t.chat.tool.statusRunning,
        exited: (code) => t.chat.tool.statusExited(code: code),
        killed: t.chat.tool.statusKilled,
        errored: t.chat.tool.statusErrored,
        notFound: t.chat.tool.statusNotFound),
    body: bashOutputBody,
    // Poll honesty: exited/errored are danger-colored but don't auto-expand; only «session gone» does.
    // 轮询诚实:exited/errored 染红不展开;仅会话不存在(resultFailed)展开。
    suppressReceiptAutoExpand: true,
    resultFailed: (s) => s.resultText.startsWith('Background shell process not found'),
  ),
  // KillShell (B4.7, thin): terminate a background session — three-state receipt + a thin session body.
  // KillShell 薄卡:终止后台会话——三态回执 + 薄会话体。
  'KillShell': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.killing : t.chat.tool.killed3,
    target: (s) {
      final id = argStringPartial(s.argsText, 'bash_id');
      return id == null ? null : (id.length > 12 ? '${id.substring(0, 12)}…' : id);
    },
    receipt: (t, s) => killShellReceipt(s.resultText, finished: t.chat.tool.killFinished, notFound: t.chat.tool.killNotFound),
    body: killShellBody,
  ),

  // ── F11 memory 记忆三件(WRK-059 H2):一张索引卡两次现身;write 有生长秀,forget 刻意薄 ──
  'write_memory': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.memorizing : t.chat.tool.memorized,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: memoryWriteReceipt,
    body: writeMemoryBody,
    // The result-payload soft-reject is the failure fact (status stays completed). 软拒即失败事实。
    resultFailed: (s) => s.resultText.trimLeft().startsWith('Cannot save memory'),
  ),
  'read_memory': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.recalling : t.chat.tool.recalled,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: memoryReadReceipt,
    body: readMemoryBody,
    // A read miss is an honest empty — receipt IS the card (no body, no chevron). 读空回执即卡。
    hasBodyOf: (s) => !s.resultText.contains('not found') || parseMemoryTemplate(s.resultText) != null,
  ),
  'forget_memory': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.forgetting : t.chat.tool.forgot,
    target: (s) => argStringPartial(s.argsText, 'name'),
    receipt: memoryForgetReceipt,
    body: forgetMemoryBody,
  ),

  // ── F10 web 双件(WRK-059 H2):soft-fail 诚实是要点——status=completed 的失败句绝不渲中性绿 ──
  'WebFetch': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.fetchingWeb : t.chat.tool.fetchedWeb,
    target: (s) {
      final url = argStringPartial(s.argsText, 'url');
      if (url == null || url.isEmpty) return null;
      final bare = url.replaceFirst(RegExp(r'^https?://'), '');
      return bare.length > 48 ? '${bare.substring(0, 48)}…' : bare;
    },
    receipt: webFetchReceipt,
    body: webFetchBody,
    resultFailed: (s) => webFetchOutcome(s.resultText) == WebFetchOutcome.fail,
  ),
  'WebSearch': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.searchingWeb : t.chat.tool.searchedWeb,
    target: (s) {
      final q = argStringPartial(s.argsText, 'query');
      if (q == null || q.isEmpty) return null;
      return '"${q.length > 48 ? '${q.substring(0, 48)}…' : q}"';
    },
    receipt: webSearchReceipt,
    body: webSearchBody,
    resultFailed: (s) => switch (webSearchOutcome(s.resultText)) {
      WebSearchOutcome.noBackend || WebSearchOutcome.misconfig || WebSearchOutcome.providerFail => true,
      _ => false,
    },
  ),

  // ── search_tools 翻工具箱(WRK-059 H2):命中=逐卡陈列;无匹配=回执即卡 ──
  'search_tools': ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.searchingTools : t.chat.tool.searchedTools,
    target: (s) {
      final q = argStringPartial(s.argsText, 'query');
      if (q == null || q.isEmpty) return null;
      return '"${q.length > 48 ? '${q.substring(0, 48)}…' : q}"';
    },
    receipt: searchToolsReceipt,
    body: searchToolsBody,
    hasBodyOf: (s) => !s.resultText.trimLeft().startsWith('No tools matched'),
  ),
};

/// Resolve a tool's spec; unknown → generic. 解析工具规格;未知→通用。
/// Resolve a tool's spec: an exact catalog match, else a NAME-ROUTED mount skin (`mcp__…` /
/// `handler__method`), else the generic fallback. 解析:精确表 → mount 名路由 → 通用兜底。
ToolCardSpec toolCardSpecFor(String toolName) =>
    _catalog[toolName] ?? mountSpecFor(toolName) ?? genericToolCardSpec;
