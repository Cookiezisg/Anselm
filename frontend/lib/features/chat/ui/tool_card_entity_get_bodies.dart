import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/status_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/an_badge.dart';
import '../../../core/ui/an_callout.dart';
import '../../../core/ui/an_field.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/an_ref_pill.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import 'tool_card_control_approval.dart';
import 'tool_card_document_skill.dart';
import 'tool_card_entity_get.dart';
import 'tool_card_trigger.dart';

// F06 get bodies (B3.5) — each get tool projects its entity JSON onto the EntityGetBody four-part
// skeleton: identity + vitals + content + raw. Every projection reads only wire-truth fields (census
// §02–07); a parse miss degrades to a raw mono window. F06 get 卡逐工具投影(读线缆事实,解析失败降级)。

Map<String, dynamic>? _json(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

/// The projected parts a get tool fills. get 工具投影的各部件。
typedef GetProjection = ({String name, String? meta, Widget? badges, Widget? kv, List<Widget> content});

/// The generic get body: parse → project onto [EntityGetBody]. A parse miss degrades to a capped mono
/// window (never a throw). get 通用体:解析→投影;解析失败降级 capped 窗。
Widget Function(BuildContext, ToolCardState) getEntityBody({
  required String kind,
  required String Function(Map<String, dynamic> out) idOf,
  required GetProjection Function(BuildContext context, Translations t, Map<String, dynamic> out) project,
}) =>
    (context, state) {
      final out = _json(state.resultText);
      if (out == null) {
        return AnWindow(child: Text(state.resultText, style: AnText.code, maxLines: 40, overflow: TextOverflow.ellipsis));
      }
      final t = Translations.of(context);
      final p = project(context, t, out);
      return EntityGetBody(
        header: ToolEntityHeader(kind: kind, name: p.name, id: idOf(out), meta: p.meta),
        badges: p.badges,
        kv: p.kv,
        content: p.content,
        rawJson: state.resultText,
      );
    };

// ── shared field helpers ──
Map<String, dynamic>? _av(Map<String, dynamic> out) => out['activeVersion'] as Map<String, dynamic>?;

String? _versionMeta(Map<String, dynamic> out) {
  final v = _av(out)?['version'];
  final stamp = fmtStamp(out['updatedAt'] as String?);
  return [if (v != null) 'v$v', if (stamp.isNotEmpty) stamp].join(' · ');
}

/// A `name:type, …` signature line from a schema.Field list. `name:type` 签名行。
String _sig(List? fields) =>
    (fields ?? const []).whereType<Map>().map((f) => '${f['name']}:${f['type']}').join(', ');

AnBadge _envBadge(Translations t, String? env) {
  switch (env) {
    case 'ready':
      return AnBadge(t.chat.tool.envReady, tone: AnTone.ok);
    case 'syncing':
      return AnBadge(t.chat.tool.envBuilding, tone: AnTone.warn);
    case 'failed':
      return AnBadge(t.chat.tool.envFailedShort, tone: AnTone.danger);
    default:
      return AnBadge(t.chat.tool.envPending, tone: AnTone.none);
  }
}

Widget _pillWrap(BuildContext context, List<AnRefPill> pills) =>
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: pills);

/// Parse an agent ToolRef `ref` into its entity kind + id. Format (agent.go): `fn_<id>` / `hd_<id>[.method]`
/// / `mcp:<server>/<tool>` / `doc_<id>`. mcp has no entity panel → id null (inert). ToolRef ref 前缀解析。
({String kind, String? id}) _parseToolRef(String ref) {
  if (ref.startsWith('mcp:')) return (kind: 'mcp', id: null);
  final m = RegExp(r'^(fn|hd|ag|doc)_[0-9a-fA-F]{16}').firstMatch(ref);
  if (m == null) return (kind: 'tool', id: null);
  final kind = switch (m.group(1)) {
    'fn' => 'function',
    'hd' => 'handler',
    'ag' => 'agent',
    'doc' => 'document',
    _ => 'tool',
  };
  return (kind: kind, id: m.group(0));
}

AnRefPill _navPill(BuildContext context, String kind, String label, String? id) => AnRefPill(
      kind: kind,
      label: label,
      id: (id != null && id.isNotEmpty && hasPanelFor(kind)) ? id : null,
      onTap: (id != null && id.isNotEmpty && hasPanelFor(kind))
          ? (target) {
              final loc = panelLocationFor(target.kind, target.id);
              if (loc != null && context.mounted) context.go(loc);
            }
          : null,
    );

// ── function / handler (env-bearing code entities) ──
GetProjection _fnProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final av = _av(out);
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (av != null && (av['inputs'] != null || av['outputs'] != null))
      AnKvRow(t.chat.tool.kvSignature, '${_sig(av['inputs'] as List?)} → ${_sig(av['outputs'] as List?)}', mono: true),
    if (av?['dependencies'] is List && (av!['dependencies'] as List).isNotEmpty)
      AnKvRow(t.chat.tool.kvDeps, (av['dependencies'] as List).join(', '), mono: true),
    if (av?['pythonVersion'] != null) AnKvRow('Python', '${av!['pythonVersion']}'),
    if (out['updatedAt'] != null) AnKvRow(t.chat.tool.kvUpdated, fmtStamp(out['updatedAt'] as String?), meta: true),
  ];
  final code = av?['code'] as String?;
  final envErr = av?['envError'] as String?;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: [
      _envBadge(t, av?['envStatus'] as String?),
      if (out['tags'] is List)
        for (final tag in (out['tags'] as List)) AnBadge('$tag', tone: AnTone.none),
    ]),
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      if (envErr != null && envErr.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: AnSpace.s2), child: Text(envErr, style: AnText.mono.copyWith(color: context.colors.danger))),
      if (code != null && code.isNotEmpty) EntityCodeWindow(code: code, lang: 'python'),
    ],
  );
}

GetProjection _handlerProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final av = _av(out);
  final methods = (av?['methods'] as List?)?.whereType<Map>().toList() ?? const [];
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (av?['dependencies'] is List && (av!['dependencies'] as List).isNotEmpty)
      AnKvRow(t.chat.tool.kvDeps, (av['dependencies'] as List).join(', '), mono: true),
    if (av?['pythonVersion'] != null) AnKvRow('Python', '${av!['pythonVersion']}'),
    if (methods.isNotEmpty) AnKvRow(t.chat.tool.kvMethods, methods.map((m) => '${m['name']}').join(', '), mono: true),
  ];
  final runtime = out['runtimeState'] as String? ?? av?['runtimeState'] as String?;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: [
      _envBadge(t, av?['envStatus'] as String?),
      if (runtime != null) AnBadge(runtime, tone: runtime == 'crashed' ? AnTone.danger : (runtime == 'running' ? AnTone.ok : AnTone.none)),
    ]),
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      if (av?['initBody'] is String && (av!['initBody'] as String).isNotEmpty)
        EntityCodeWindow(code: av['initBody'] as String, lang: 'python', label: '__init__'),
    ],
  );
}

// ── agent (prompt + mounted capabilities) ──
GetProjection _agentProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final av = _av(out);
  final tools = (av?['tools'] as List?)?.whereType<Map>().toList() ?? const [];
  final knowledge = (av?['knowledge'] as List?) ?? const [];
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (av != null && (av['inputs'] != null || av['outputs'] != null))
      AnKvRow(t.chat.tool.kvSignature, '${_sig(av['inputs'] as List?)} → ${_sig(av['outputs'] as List?)}', mono: true),
    if (av?['modelOverride'] != null) AnKvRow(t.chat.tool.kvModel, '${av!['modelOverride']}', mono: true),
  ];
  final prompt = av?['prompt'] as String?;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: av == null ? AnCallout(t.chat.tool.noActiveVersion, severity: AnCalloutSeverity.warn) : null,
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      if (tools.isNotEmpty)
        _pillWrap(context, [
          // An agent ToolRef is {ref, name} — the KIND + id live encoded in `ref` (fn_/hd_/mcp:/doc_),
          // not as separate keys. Parse it so the pill gets the right glyph + navigation (mcp has no
          // panel → inert). agent ToolRef 只有 {ref,name},kind+id 编在 ref 前缀里,解析出来给对图标+导航。
          for (final m in tools)
            () {
              final r = _parseToolRef('${m['ref'] ?? ''}');
              return _navPill(context, r.kind, '${m['name']}', r.id);
            }(),
        ]),
      if (knowledge.isNotEmpty)
        _pillWrap(context, [for (final d in knowledge) _navPill(context, 'document', '$d', '$d')]),
      if (prompt != null && prompt.isNotEmpty) EntityCodeWindow(code: prompt, lang: 'markdown'),
    ],
  );
}

// ── workflow (lifecycle + graph summary) ──
GetProjection _workflowProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final ls = out['lifecycleState'] as String?;
  final graph = out['activeVersion']?['graphParsed'] as Map<String, dynamic>?;
  final nodes = (graph?['nodes'] as List?)?.length ?? 0;
  final edges = (graph?['edges'] as List?)?.length ?? 0;
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (out['concurrency'] != null) AnKvRow(t.chat.tool.kvConcurrency, '${out['concurrency']}'),
    if (graph != null) AnKvRow(t.chat.tool.kvGraph, t.chat.tool.wfGraphCounts(nodes: '$nodes', edges: '$edges')),
  ];
  final attention = out['needsAttention'] == true;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: [
      if (ls != null) AnBadge(ls, tone: ls == 'active' ? AnTone.ok : (ls == 'draining' ? AnTone.warn : AnTone.none)),
    ]),
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      if (attention && (out['attentionReason'] as String?)?.isNotEmpty == true)
        AnCallout('${out['attentionReason']}', severity: AnCalloutSeverity.warn),
    ],
  );
}

// ── control (branch ladder) / approval (form preview) ──
GetProjection _controlProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final av = _av(out);
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: null,
    kv: (out['description'] as String?)?.isNotEmpty == true
        ? AnKv(rows: [AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true)], dense: true)
        : null,
    content: [
      // Reuse the B2.7 decision ladder over the active version's branches. 复用 B2.7 决策梯。
      controlBranchList(context, (av?['branches'] as List?) ?? const []),
    ],
  );
}

GetProjection _approvalProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final av = _av(out);
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (av?['timeout'] != null) AnKvRow(t.chat.tool.apfTimeout, '${av!['timeout']}'),
    if (av?['timeoutBehavior'] != null) AnKvRow(t.chat.tool.apfBehavior, '${av!['timeoutBehavior']}', mono: true),
    if (av?['allowReason'] != null) AnKvRow(t.chat.tool.apfAllowReason, av!['allowReason'] == true ? '✓' : '—'),
  ];
  final template = av?['template'] as String?;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: _versionMeta(out),
    badges: null,
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      // The template is the approver-facing markdown → render it (moustache → inline code). 渲染排版态。
      if (template != null && template.isNotEmpty) ProseWindow(markdown: approvalTemplateToMarkdown(template)),
    ],
  );
}

// ── skill (frontmatter + body) ──
GetProjection _skillProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final fm = out['frontmatter'] as Map<String, dynamic>? ?? const {};
  final allowed = (fm['allowedTools'] as List?)?.map((e) => '$e').toList() ?? const [];
  final rows = <AnKvRow>[
    if ((out['description'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.kvDescription, '${out['description']}', wrap: true),
    if (out['context'] != null) AnKvRow(t.chat.tool.kvContext, '${out['context']}'),
    if (out['source'] != null) AnKvRow(t.chat.tool.kvSource, '${out['source']}'),
  ];
  final body = out['body'] as String?;
  return (
    name: '${out['name'] ?? 'skill'}',
    meta: fmtStamp(out['updatedAt'] as String?),
    badges: allowed.isEmpty
        ? null
        : Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: [
            for (final a in allowed) AnBadge(a, tone: AnTone.warn),
          ]),
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    content: [
      if (allowed.isNotEmpty)
        Text(t.chat.tool.skillPreauthNote, style: AnText.meta.copyWith(color: context.colors.warn)),
      if (body != null && body.isNotEmpty) EntityCodeWindow(code: body, lang: 'markdown'),
    ],
  );
}

// ── trigger (four kind faces + runtime) ──
GetProjection _triggerProj(BuildContext context, Translations t, Map<String, dynamic> out) {
  final listening = out['listening'] == true;
  return (
    name: '${out['name'] ?? out['id']}',
    meta: fmtStamp(out['updatedAt'] as String?),
    badges: AnBadge(listening ? t.chat.tool.trgListening : t.chat.tool.trgNotListening,
        tone: listening ? AnTone.ok : AnTone.none),
    kv: null,
    content: [triggerConfigFaces(context, '${out['kind']}', (out['config'] as Map?) ?? const {}, '${out['id']}')],
  );
}

// ── read_document / read_attachment (string TEMPLATES, not JSON — the #32 template parsers) ──

/// The quoted name in a `… "<name>" …` sentence (first double-quoted span). 句中引号内的名字。
String? _quoted(String s) {
  final a = s.indexOf('"');
  if (a < 0) return null;
  final b = s.indexOf('"', a + 1);
  return b < 0 ? null : s.substring(a + 1, b);
}

/// read_document — the strict line-ordered template `# name … Path/ID/[Description]/[Tags] … --- …
/// content` (a soft not-found sentence is reframed as a note). One step off the template → the raw
/// window (never a wrong parse). read_document 严格行序模板;not-found 软失败→注记。
Widget readDocumentBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final text = state.resultText;
  if (text.startsWith('Document ') && text.contains('not found')) {
    return AnCallout(text, severity: AnCalloutSeverity.warn);
  }
  if (!text.startsWith('# ')) {
    return AnWindow(child: Text(text, style: AnText.code, maxLines: 40, overflow: TextOverflow.ellipsis));
  }
  final splitIdx = text.indexOf('\n---\n');
  final head = splitIdx >= 0 ? text.substring(0, splitIdx) : text;
  final content = splitIdx >= 0 ? text.substring(splitIdx + 5).trimLeft() : '';
  final lines = head.split('\n');
  final name = lines.first.substring(2).trim();
  String? path, id, desc;
  final tags = <String>[];
  for (final l in lines) {
    if (l.startsWith('Path: ')) {
      path = l.substring(6).trim();
    } else if (l.startsWith('ID: ')) {
      id = l.substring(4).trim();
    } else if (l.startsWith('Description: ')) {
      desc = l.substring(13).trim();
    } else if (l.startsWith('Tags: ')) {
      tags.addAll(l.substring(6).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
  }
  final rows = <AnKvRow>[
    if (path != null) AnKvRow('Path', path, mono: true),
    if (desc != null && desc.isNotEmpty) AnKvRow(t.chat.tool.kvDescription, desc, wrap: true),
    if (tags.isNotEmpty) AnKvRow.tags(t.chat.tool.kvTags, tags),
  ];
  return EntityGetBody(
    header: ToolEntityHeader(kind: 'document', name: name, id: id ?? ''),
    kv: rows.isEmpty ? null : AnKv(rows: rows, dense: true),
    // A document is human-facing prose → render it (unlike code/prompt source). 文档给人看→渲排版态。
    content: [if (content.isNotEmpty) ProseWindow(markdown: content)],
    rawJson: text,
  );
}

/// read_attachment — the SIX string forms (census §attachment): text/document body, media descriptor,
/// extraction-failed placeholder, not-found. The extractable body rides a mono window; the rest are
/// honest notes. read_attachment 六形:可抽取正文→mono 窗;其余→诚实注记。
Widget readAttachmentBody(BuildContext context, ToolCardState state) {
  final text = state.resultText;
  final name = _quoted(text) ?? '';
  // not-found soft failure. 未找到软失败。
  if (text.startsWith('Attachment "') && text.contains('not found')) {
    return AnCallout(text, severity: AnCalloutSeverity.warn);
  }
  // media descriptor — the model can't read it as text (an honest info note). 媒体描述符:不可读为文本。
  if (text.startsWith('Attachment "') && text.contains('this tool cannot')) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      ToolEntityHeader(kind: 'attachment', name: name, id: ''),
      const SizedBox(height: AnSpace.s6),
      AnCallout(text, severity: AnCalloutSeverity.info),
    ]);
  }
  // extraction failed. 抽取失败占位。
  if (text.startsWith('[document "') && text.contains('could not be extracted')) {
    return AnCallout(text, severity: AnCalloutSeverity.warn);
  }
  // extractable text/document body: `Attached … "<name>"(truncated)?:\n<body>`. 可抽取正文。
  if (text.startsWith('Attached ')) {
    final bodyStart = text.indexOf(':\n');
    final body = bodyStart >= 0 ? text.substring(bodyStart + 2) : text;
    return EntityGetBody(
      header: ToolEntityHeader(kind: 'attachment', name: name, id: ''),
      badges: text.contains('truncated')
          ? AnBadge(Translations.of(context).chat.tool.attachTruncated, tone: AnTone.warn)
          : null,
      content: [AnWindow(child: Text(body, style: AnText.code, maxLines: 200, overflow: TextOverflow.ellipsis))],
      rawJson: text,
    );
  }
  return AnWindow(child: Text(text, style: AnText.code, maxLines: 40, overflow: TextOverflow.ellipsis));
}

/// The F06 get body table (WRK-056 §F06). F06 get 体表。
final Map<String, Widget Function(BuildContext, ToolCardState)> f06GetBodies = {
  'get_function': getEntityBody(kind: 'function', idOf: (o) => '${o['id']}', project: _fnProj),
  'get_handler': getEntityBody(kind: 'handler', idOf: (o) => '${o['id']}', project: _handlerProj),
  'get_agent': getEntityBody(kind: 'agent', idOf: (o) => '${o['id']}', project: _agentProj),
  'get_workflow': getEntityBody(kind: 'workflow', idOf: (o) => '${o['id']}', project: _workflowProj),
  'get_control': getEntityBody(kind: 'control', idOf: (o) => '${o['id']}', project: _controlProj),
  'get_approval': getEntityBody(kind: 'approval', idOf: (o) => '${o['id']}', project: _approvalProj),
  'get_skill': getEntityBody(kind: 'skill', idOf: (o) => '${o['name']}', project: _skillProj),
  'get_trigger': getEntityBody(kind: 'trigger', idOf: (o) => '${o['id']}', project: _triggerProj),
};
