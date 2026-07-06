import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';
import 'tool_card_control_approval.dart';
import 'tool_card_document_skill.dart';
import 'tool_card_entity_get_bodies.dart';
import 'tool_card_search.dart';
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
    this.liveBody,
    this.awaitingVerb,
    this.terminalVerb,
    this.verbOf,
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
  // Per-kind overrides: workflow swaps the code window for the growing graph (B2.5). 族覆盖:workflow 换图。
  Widget Function(BuildContext, ToolCardState)? body,
  Widget Function(BuildContext, ToolCardState)? liveBody,
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
      liveBody: liveBody ?? buildLiveBody,
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
  // create_workflow ★ two-act growth show: op ticker (streaming) → graph replaying its growth (settled).
  // create_workflow 两幕生长秀:op ticker → 图回放生长。
  'create_workflow': _build(
    kind: (t) => t.chat.tool.kind.workflow,
    create: true,
    body: workflowBuildBody,
    liveBody: workflowOpLiveBody,
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
