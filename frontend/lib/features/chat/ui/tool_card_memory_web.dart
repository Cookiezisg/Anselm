import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/platform/open_external_url.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'dart:convert';


import 'tool_card_document_skill.dart' show ProseWindow;
import 'tool_card_skins.dart';

// The last uncataloged REAL tools (WRK-059 H2): the memory trio (write/read/forget — one index
// card, two appearances), the web pair (WebFetch/WebSearch — soft-fail HONESTY is the point:
// status=completed with a failure sentence must never render as a neutral green), and
// search_tools (the toolbox flip-through). Receipts parse the backend's STABLE English templates
// — template drift degrades to the generic body, never to silence or a guess.
//
// 最后六个未编目真工具(WRK-059 H2):记忆三件(写/读/忘——一张索引卡两次现身)、web 双件(soft-fail
// **诚实**是要点:status=completed 但内容是失败句,绝不许渲成中性绿)、search_tools(翻工具箱)。
// 回执解析后端**稳定英文模板**——模板漂移降级通用体,绝不无声、绝不猜。

/// Decode a JSON object, or null (never throws) — the family's tolerant reader. 容错 JSON 读取。
Map<String, dynamic>? tryJsonMap(String text) {
  try {
    final d = jsonDecode(text.trim());
    return d is Map<String, dynamic> ? d : null;
  } catch (_) {
    return null;
  }
}

// ── memory 记忆 ─────────────────────────────────────────────────────────────

/// Parsed `### <name> (source: <x>)` note — write echoes it, read returns it. 记忆模板反解。
typedef MemoryNote = ({String name, String source, String description, String body});

/// Parse the backend memory template: line 1 `### <name> (source: <x>)`, optional description
/// lines, `---`, then the markdown body. null = template mismatch (the caller dumps the raw text
/// into the generic body — honest degradation). 反解记忆模板;不匹配返 null(通用体倾倒原文)。
MemoryNote? parseMemoryTemplate(String text) {
  final m = RegExp(r'^### (.+) \(source: ([a-z]+)\)\s*$', multiLine: false)
      .firstMatch(text.split('\n').first);
  if (m == null) return null;
  final lines = text.split('\n');
  final sep = lines.indexOf('---');
  final description =
      (sep > 1 ? lines.sublist(1, sep) : const <String>[]).join('\n').trim();
  final body = sep >= 0 ? lines.sublist(sep + 1).join('\n').trim() : '';
  return (name: m.group(1)!, source: m.group(2)!, description: description, body: body);
}

/// write_memory's three-branch receipt (POSITIVE gating — «not failed» is never «succeeded»):
/// `Saved memory "` → N 行 (counted off ARGS content, the structural truth — but only WITH the
/// output credential); `Cannot save memory` → 未保存 danger; anything else → null (no receipt,
/// generic dump). write_memory 三分支正向门控回执。
ToolReceipt? memoryWriteReceipt(Translations t, ToolCardState s) {
  final out = s.resultText.trimLeft();
  if (out.startsWith('Saved memory "')) {
    final content = s.argsSession.closedStringAt(['content']) ?? '';
    if (content.isEmpty) return null;
    return (text: t.chat.tool.lines(n: '${'\n'.allMatches(content).length + 1}'), tone: ToolReceiptTone.none);
  }
  if (out.startsWith('Cannot save memory')) {
    return (text: t.chat.tool.memNotSaved, tone: ToolReceiptTone.danger);
  }
  return null;
}

/// read_memory: template hit → N 行 (body lines); miss (`not found`) → 未找到 GREY — a read miss
/// is an honest empty, not an incident (the F2 noMatches voice). read_memory 回执;miss=灰非红。
ToolReceipt? memoryReadReceipt(Translations t, ToolCardState s) {
  final out = s.resultText;
  final note = parseMemoryTemplate(out);
  if (note != null) {
    final n = note.body.isEmpty ? 0 : '\n'.allMatches(note.body).length + 1;
    return (text: t.chat.tool.lines(n: '$n'), tone: ToolReceiptTone.none);
  }
  if (out.contains('not found')) return (text: t.chat.tool.memNotFound, tone: ToolReceiptTone.none);
  return null;
}

/// forget_memory: the past-tense verb IS the credential on success (no suffix); `not found` →
/// 本就不存在 grey. forget_memory 回执:成功无后缀(过去时即凭据);miss=灰。
ToolReceipt? memoryForgetReceipt(Translations t, ToolCardState s) {
  final out = s.resultText.trimLeft();
  if (out.startsWith('Forgot memory "')) return null;
  if (out.contains('not found')) return (text: t.chat.tool.memAlreadyGone, tone: ToolReceiptTone.none);
  return null;
}

/// The memory index card — write and read wear the SAME face (two tools, one memory entity):
/// name in mono + a source badge (`user` = a hand-written memory recalled — accent; `ai` = none),
/// the optional description, a hairline rule, then the RENDERED markdown body (the document's
/// native tongue is typeset prose, never raw source). The shell is the ONE window ([AnWindow],
/// WRK-066 族一 — the sunken well is retired); long bodies collapse at the prose viewport tier.
///
/// 记忆索引卡——写与读同一张脸(两个工具、一个记忆实体):name mono + source 徽(user=手写记忆被
/// 回忆,accent;ai=none)+ 可缺 description + 发丝线 + **渲染态 markdown 正文**(文档母语是排版稿,
/// 不是源码)。壳=唯一窗(族一,凹面退役);长文按散文视口档折叠。
class MemoryNoteCard extends StatelessWidget {
  const MemoryNoteCard({required this.note, super.key});

  final MemoryNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final long = note.body.length > AnCap.noteFoldChars; // short notes render whole 短笺整渲
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: Text(note.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.mono.copyWith(color: c.ink)),
        ),
        const SizedBox(width: AnSpace.s6),
        AnChip(
            note.source == 'user'
                ? context.t.chat.tool.memSourceUser
                : context.t.chat.tool.memSourceAi,
            tone: note.source == 'user' ? AnTone.accent : AnTone.none),
      ]),
      if (note.description.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s4),
        Text(note.description, style: AnText.label.copyWith(color: c.inkMuted)),
      ],
      if (note.body.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        const AnDivider(),
        const SizedBox(height: AnSpace.s6),
        AnMarkdown(note.body),
      ],
    ]);
    return AnWindow(
      maxHeight: long ? AnSize.proseViewport : null,
      collapsible: long,
      child: body,
    );
  }
}

/// write_memory body — LIVE: the note being written stroke by stroke (the args session's unescaped
/// `content` tail, 6 mono lines — the W0 engine already handles split escapes; the raw-args dump
/// stays a SETTLED-only fallback, mid-stream it's just unreadable JSON shrapnel, WRK-065). SETTLED:
/// the card off ARGS (the structural truth the model authored); soft-reject shows the backend
/// sentence in a mono window. write_memory 体:活=便笺一笔一笔被写下(生 JSON 倾倒仅落定兜底——流中
/// 是不可读残片);落定=args 成卡;软拒原句进机器窗。
Widget writeMemoryBody(BuildContext context, ToolCardState state) {
  if (toolLive(state)) {
    final name = state.argsSession.closedStringAt(['name']) ?? '';
    final content = state.argsSession.liveStringNamed('content') ?? '';
    if (name.isEmpty && content.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (name.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s4),
          child: Text(name, style: AnText.mono.copyWith(color: c.inkMuted)),
        ),
      if (content.isNotEmpty)
        // The memo is PROSE being authored — the family's prose tail (bottom-pinned: the newest
        // words visible), same verdict as document/skill drafts (A-022 归族改判,台账记录). 便笺是
        // 正在写的散文——族六 prose 尾(贴底示新),与 doc/skill 稿同判。
        AnLiveTail(content, style: AnLiveTailStyle.prose),
    ]);
  }
  final out = state.resultText.trimLeft();
  if (out.startsWith('Cannot save memory')) {
    return AnWindow(
        child: Text(state.resultText,
            style: AnText.code.copyWith(color: context.colors.danger)));
  }
  final name = state.argsSession.closedStringAt(['name']) ?? '';
  final content = state.argsSession.closedStringAt(['content']) ?? '';
  if (name.isEmpty && content.isEmpty) {
    // args didn't parse — the chassis generic body dumps them honestly. args 未解,回落通用体。
    return AnWindow(
        child: Text(state.argsText,
            maxLines: 6, overflow: TextOverflow.ellipsis,
            style: AnText.code.copyWith(color: context.colors.inkFaint)));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _summaryLine(context, state),
    MemoryNoteCard(note: (
      name: name,
      source: 'ai', // writes are always the model's hand 写入恒 ai
      description: state.argsSession.closedStringAt(['description']) ?? '',
      body: content,
    )),
  ]);
}

/// read settled: the SAME card, parsed back off the wire template; miss/mismatch degrade honestly.
/// 读落定:同一张卡,从线缆模板反解;miss/漂移诚实降级。
Widget readMemoryBody(BuildContext context, ToolCardState state) {
  final note = parseMemoryTemplate(state.resultText);
  if (note == null) {
    return AnWindow(
        child: Text(state.resultText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: AnText.code.copyWith(color: context.colors.inkFaint)));
  }
  return MemoryNoteCard(note: note);
}

/// forget settled: thin on purpose — deletion doesn't perform. One credential line: the name chip
/// + the irreversible badge; the user's attention belongs on «should this pass», nothing else.
/// 忘落定:刻意薄——删除不表演。一行凭据:name chip + 不可逆徽;注意力全留给「放不放行」。
Widget forgetMemoryBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final name = state.argsSession.closedStringAt(['name']) ?? '';
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _summaryLine(context, state),
    Row(children: [
      if (name.isNotEmpty) ...[
        Text(name, style: AnText.mono.copyWith(color: c.inkMuted)),
        const SizedBox(width: AnSpace.s6),
      ],
      AnChip(t.chat.tool.irreversible, tone: AnTone.danger),
    ]),
    if (state.resultText.contains('not found')) ...[
      const SizedBox(height: AnSpace.s4),
      Text(state.resultText, style: AnText.meta.copyWith(color: c.inkFaint)),
    ],
  ]);
}

/// The LLM's self-reported intent line (shown in expanded bodies). 自报意图行。
Widget _summaryLine(BuildContext context, ToolCardState state) {
  if (state.summary.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s6),
    child: Text(state.summary,
        style: AnText.meta.copyWith(color: context.colors.inkMuted)),
  );
}

// ── web 网页 ────────────────────────────────────────────────────────────────

enum WebSearchOutcome { hits, empty, noBackend, misconfig, providerFail, unparsed }

/// Classify a WebSearch result — the backend returns status=completed even for its FAILURE
/// SENTENCES, so honesty needs a classifier, not the status. Anchors are the backend's hardcoded
/// templates (contract-locked by unit tests; a template change must change this in the same
/// commit). WebSearch 结局分类——后端失败句也 status=completed,诚实靠分类器不靠 status。
WebSearchOutcome webSearchOutcome(String result) {
  final out = result.trimLeft();
  if (out.startsWith('No search backend configured')) return WebSearchOutcome.noBackend;
  if (out.startsWith('The configured default search key') ||
      out.contains('has no base URL configured')) {
    return WebSearchOutcome.misconfig;
  }
  if (out.startsWith('Search via ')) return WebSearchOutcome.providerFail;
  try {
    final hits = webSearchHits(result);
    if (hits != null) return hits.isEmpty ? WebSearchOutcome.empty : WebSearchOutcome.hits;
  } catch (_) {/* fall through 落底 */}
  return WebSearchOutcome.unparsed;
}

/// The parsed hits (title/url/snippet rows), or null when the payload isn't the JSON shape.
/// 解出的命中行;非 JSON 形状返 null。
List<({String title, String url, String snippet})>? webSearchHits(String result) {
  final rows = <({String title, String url, String snippet})>[];
  final decoded = tryJsonMap(result);
  if (decoded == null) return null;
  final list = decoded['results'];
  if (list is! List) return null;
  for (final e in list) {
    if (e is Map) {
      rows.add((
        title: '${e['title'] ?? ''}',
        url: '${e['url'] ?? ''}',
        snippet: '${e['snippet'] ?? e['description'] ?? ''}',
      ));
    }
  }
  return rows;
}

ToolReceipt? webSearchReceipt(Translations t, ToolCardState s) {
  switch (webSearchOutcome(s.resultText)) {
    case WebSearchOutcome.hits:
      final truncated = tryJsonMap(s.resultText)?['truncated'] == true;
      final n = webSearchHits(s.resultText)?.length ?? 0;
      return (
        text: truncated ? t.chat.tool.webHitsPlus(n: '$n') : t.chat.tool.webHits(n: '$n'),
        tone: ToolReceiptTone.none
      );
    case WebSearchOutcome.empty:
      return (text: t.chat.tool.webEmpty, tone: ToolReceiptTone.none);
    case WebSearchOutcome.noBackend:
      return (text: t.chat.tool.webNoBackend, tone: ToolReceiptTone.danger);
    case WebSearchOutcome.misconfig:
      return (text: t.chat.tool.webMisconfig, tone: ToolReceiptTone.danger);
    case WebSearchOutcome.providerFail:
      return (text: t.chat.tool.webProviderFail, tone: ToolReceiptTone.danger);
    case WebSearchOutcome.unparsed:
      return null;
  }
}

/// WebSearch settled: the hit list — title 15 / snippet 13 clamped / host mono 12; a row click
/// opens the REAL page (openExternalUrl, scheme-gated). Failure sentences live in a mono window
/// verbatim (guidance text carries itself; nav ghosts wait for their settings faces).
/// WebSearch 落定:命中列——行点开真网页;失败句原样机器窗(引导文自足;ghost 钮等 settings 面)。
Widget webSearchBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  switch (webSearchOutcome(state.resultText)) {
    case WebSearchOutcome.hits:
      final hits = webSearchHits(state.resultText) ?? const [];
      final source = '${tryJsonMap(state.resultText)?['source'] ?? ''}';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (source.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: AnChip(source, tone: AnTone.none),
          ),
        _WebHits(hits: hits),
      ]);
    case WebSearchOutcome.empty:
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
        child: Text(Translations.of(context).chat.tool.webEmptyBody,
            style: AnText.label.copyWith(color: c.inkFaint)),
      );
    case WebSearchOutcome.noBackend:
    case WebSearchOutcome.misconfig:
    case WebSearchOutcome.providerFail:
    case WebSearchOutcome.unparsed:
      return AnWindow(
          child: Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted)));
  }
}

class _WebHits extends StatelessWidget {
  const _WebHits({required this.hits});

  final List<({String title, String url, String snippet})> hits;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final h in hits.take(30))
        AnInteractive(
          onTap: h.url.isEmpty ? null : () => openExternalUrl(h.url),
          builder: (ctx, states) => Container(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s6),
            decoration: BoxDecoration(
              color: states.isActive ? c.surfaceHover : null,
              borderRadius: BorderRadius.circular(AnRadius.button),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.title.isEmpty ? h.url : h.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.valueReading().copyWith(color: c.ink).weight(AnText.emphasisWeight)),
              if (h.snippet.isNotEmpty)
                Text(h.snippet,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AnText.label.copyWith(color: c.inkMuted)),
              if (h.url.isNotEmpty)
                Text(Uri.tryParse(h.url)?.host ?? h.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkFaint, fontFamily: AnText.mono.fontFamily)),
            ]),
          ),
        ),
    ]);
    if (hits.length <= 10) return rows;
    final t = Translations.of(context);
    return AnFadeCollapse(
        collapsible: true,
        collapsedHeight: 420,
        expandLabel: t.chat.tool.proseExpand,
        collapseLabel: t.chat.tool.proseCollapse,
        fadeColor: context.colors.surface,
        child: rows);
  }
}

enum WebFetchOutcome { summary, empty, raw, jsShell, fail }

/// Classify a WebFetch result off the backend's stable sentence anchors. WebFetch 结局分类。
WebFetchOutcome webFetchOutcome(String result) {
  final out = result.trimLeft();
  if (out.startsWith('Invalid URL') ||
      out.startsWith('Refusing to') ||
      out.startsWith('Cannot resolve') ||
      out.startsWith('URL has no host') ||
      out.startsWith('Failed to fetch')) {
    return WebFetchOutcome.fail;
  }
  if (out.contains('but body was empty')) return WebFetchOutcome.empty;
  if (out.startsWith('Summarisation unavailable')) return WebFetchOutcome.raw;
  if (RegExp(r'almost no readable text \(\d+ chars?\)').hasMatch(out)) {
    return WebFetchOutcome.jsShell;
  }
  return WebFetchOutcome.summary;
}

ToolReceipt? webFetchReceipt(Translations t, ToolCardState s) {
  switch (webFetchOutcome(s.resultText)) {
    case WebFetchOutcome.summary:
      if (s.resultText.isEmpty) return null;
      return (
        text: t.chat.tool.fetchChars(n: '${s.resultText.characters.length}'),
        tone: ToolReceiptTone.none
      );
    case WebFetchOutcome.empty:
      return (text: t.chat.tool.fetchEmpty, tone: ToolReceiptTone.none);
    case WebFetchOutcome.raw:
      return (text: t.chat.tool.fetchRawFallback, tone: ToolReceiptTone.danger);
    case WebFetchOutcome.jsShell:
      return (text: t.chat.tool.fetchJsShell, tone: ToolReceiptTone.danger);
    case WebFetchOutcome.fail:
      return (
        text: s.resultText.trimLeft().startsWith('Refusing to')
            ? t.chat.tool.fetchRefused
            : t.chat.tool.fetchFailed,
        tone: ToolReceiptTone.danger
      );
  }
}

/// WebFetch body — LIVE: the summary being distilled word by word (the progress tee in a
/// MAX-HEIGHT-capped viewport pinned bottom — prose has few newlines, a line-tail would let one
/// paragraph wrap unbounded; a short first delta no longer inflates a mostly-empty fixed panel,
/// WRK-065). SETTLED: the question line (`args.prompt`) over the typeset summary; degraded outcomes
/// land verbatim in a mono window — a raw-fallback page is MACHINE text.
/// WebFetch 体:活=摘要逐词蒸馏(限高贴底视口——短首帧不再撑出大片留白的定高面板);落定=问句行 + 排版
/// 摘要;退化态原样机器窗。
Widget webFetchBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final prompt = state.argsSession.closedStringAt(['prompt']) ?? '';
  final promptLine = prompt.isEmpty
      ? null
      : Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t.chat.tool.fetchAsk} ', style: AnText.label.copyWith(color: c.inkFaint)),
            Expanded(child: Text(prompt, style: AnText.label.copyWith(color: c.inkMuted))),
          ]),
        );
  if (toolLive(state)) {
    if (promptLine == null && state.progressText.trim().isEmpty) return const SizedBox.shrink();
    // The distillation rolls in the family's prose tail (批1: the old hand-rolled Align clamp pinned
    // the paragraph HEAD — the newest words were invisible, the family fixed exactly this).
    // 蒸馏走族六 prose 尾(批1:旧手搓 Align 钳把段落钉头,最新字不可见——族头修的正是它)。
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ?promptLine,
      AnLiveTail(state.progressText, style: AnLiveTailStyle.prose),
    ]);
  }
  final outcome = webFetchOutcome(state.resultText);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ?promptLine,
    switch (outcome) {
      WebFetchOutcome.summary => ProseWindow(markdown: state.resultText),
      _ => AnWindow(
          child: Text(state.resultText,
              style: AnText.code.copyWith(
                  color: outcome == WebFetchOutcome.empty ? c.inkFaint : c.inkMuted))),
    },
  ]);
}

// ── search_tools 翻工具箱 ────────────────────────────────────────────────────

/// The framework-injected cross-cutting fields — boilerplate on EVERY tool, noise in a digest
/// (the full schema keeps them in the escape hatch). 框架注入横切字段,摘要滤除(逃生口保全)。
const _frameworkParams = {'summary', 'danger', 'execution_group'};

/// One line of parameter names off a JSON schema — required starred, framework fields filtered.
/// schema 参数摘要一行——required 加星,框架字段滤除。
String schemaParamDigest(Map<String, dynamic> schema) {
  final props = schema['properties'];
  if (props is! Map) return '';
  final required = {
    if (schema['required'] is List) ...(schema['required'] as List).map((e) => '$e'),
  };
  final parts = <String>[
    for (final key in props.keys)
      if (!_frameworkParams.contains('$key')) required.contains('$key') ? '$key*' : '$key',
  ];
  return parts.join(', ');
}

ToolReceipt? searchToolsReceipt(Translations t, ToolCardState s) {
  final decoded = tryJsonMap(s.resultText);
  final tools = decoded?['tools'];
  if (tools is List) return (text: t.chat.tool.toolsFound(n: '${tools.length}'), tone: ToolReceiptTone.none);
  if (s.resultText.trimLeft().startsWith('No tools matched')) {
    return (text: t.chat.tool.toolsNoMatch, tone: ToolReceiptTone.none);
  }
  return null;
}

/// search_tools settled: one whisper-thin card per hit — mono tool name + the param digest, the
/// description, and a per-card schema disclosure (bounded JSON tree, framework fields INCLUDED
/// there — the escape hatch never edits). search_tools 落定:逐命中极薄卡+schema 逃生口。
Widget searchToolsBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final decoded = tryJsonMap(state.resultText);
  final tools = decoded?['tools'];
  if (tools is! List) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
      child: Text(state.resultText, style: AnText.label.copyWith(color: c.inkMuted)),
    );
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (final e in tools.take(5))
      if (e is Map) _ToolHitCard(hit: e.cast<String, dynamic>()),
  ]);
}

/// One toolbox hit — a whisper-thin card: mono name + the param digest line + the description,
/// with a per-card schema disclosure (bounded JSON tree; the framework fields stay IN the escape
/// hatch — it never edits). 一张工具箱命中薄卡+独立 schema 逃生口。
class _ToolHitCard extends StatefulWidget {
  const _ToolHitCard({required this.hit});

  final Map<String, dynamic> hit;

  @override
  State<_ToolHitCard> createState() => _ToolHitCardState();
}

class _ToolHitCardState extends State<_ToolHitCard> {
  bool _schemaOpen = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final e = widget.hit;
    final params = e['parameters'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${e['name'] ?? ''}', style: AnText.mono.copyWith(color: c.ink)),
          const SizedBox(width: AnSpace.s8),
          if (params is Map)
            Expanded(
              child: Text(
                schemaParamDigest(params.cast<String, dynamic>()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
            ),
        ]),
        if ('${e['description'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text('${e['description']}',
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: AnText.label.copyWith(color: c.inkMuted)),
          ),
        if (params is Map)
          AnDisclosure(
            label: t.chat.tool.toolSchema,
            open: _schemaOpen,
            onToggle: () => setState(() => _schemaOpen = !_schemaOpen),
            child: SizedBox(
                height: AnSize.jsonViewport,
                child: AnJsonTree(data: params, showRoot: false)),
          ),
      ]),
    );
  }
}
