import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_nav.dart';
import 'tool_card_skins.dart';

// F12 relations + F13 mcp-mgmt + capability/model config (B7.2) — the ecosystem-tail cards. Each is a
// thin projection of a structured JSON result: get_relations = a dependency edge list; capability_check
// = an ok/problems/warnings report; the mcp lifecycle = a server status card; list_mcp_marketplace = a
// server catalog; get_model_config = a config summary. B7 生态收尾薄卡。

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

// ── get_relations (F12): the dependency neighborhood ──

/// The relations receipt — `{n} 条关系` / 无关系. 关系回执。
ToolReceipt? relationsReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  final n = o['count'] is int ? o['count'] as int : (o['edges'] as List?)?.length ?? 0;
  return n == 0 ? (text: t.chat.tool.relNoEdges, tone: ToolReceiptTone.none) : (text: t.chat.tool.relCount(n: '$n'), tone: ToolReceiptTone.none);
}

/// get_relations body — each edge as a navigable `fromName (kind) → toName (kind)` row. get_relations 体。
Widget relationsBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final edges = (_obj(state.resultText)?['edges'] as List?)?.whereType<Map>().toList() ?? const [];
  if (edges.isEmpty) return Text(t.chat.tool.relNoEdges, style: AnText.meta.copyWith(color: c.inkFaint));
  return ToolWindow(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final e in edges)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
          child: Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            toolNavPill(context, kind: '${e['fromKind']}', label: '${e['fromName'] ?? e['fromId']}', id: e['fromId'] as String?),
            Text(t.chat.tool.relArrow, style: AnText.meta.copyWith(color: c.inkFaint)),
            toolNavPill(context, kind: '${e['toKind']}', label: '${e['toName'] ?? e['toId']}', id: e['toId'] as String?),
          ]),
        ),
    ]),
  );
}

// ── capability_check_workflow: the runnability report ──

/// The capability receipt — ok → 结构可运行; else red `{n} 问题` (auto-expand). 能力体检回执。
ToolReceipt? capabilityReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null || o['ok'] is! bool) return null;
  if (o['ok'] == true) {
    final warns = (o['warnings'] as List?)?.length ?? 0;
    return warns > 0 ? (text: t.chat.tool.capWarnings(n: '$warns'), tone: ToolReceiptTone.warn) : (text: t.chat.tool.capRunnable, tone: ToolReceiptTone.none);
  }
  final probs = (o['problems'] as List?)?.length ?? 0;
  return (text: t.chat.tool.capProblems(n: '$probs'), tone: ToolReceiptTone.danger);
}

bool capabilityFailed(String output) => _obj(output)?['ok'] == false;

/// capability_check_workflow body — a runnable/structural/resolved flag row + a problems (red) list +
/// a warnings (amber) list. capability 体检体。
Widget capabilityBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted));
  final problems = (o['problems'] as List?)?.map((e) => '$e').toList() ?? const [];
  final warnings = (o['warnings'] as List?)?.map((e) => '$e').toList() ?? const [];
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, children: [
      AnBadge(o['ok'] == true ? t.chat.tool.capRunnable : t.chat.tool.capProblems(n: '${problems.length}'), tone: o['ok'] == true ? AnTone.ok : AnTone.danger),
      if (o['structurallyValid'] == true) AnBadge(t.chat.tool.capStructural, tone: AnTone.none),
      if (o['resolved'] == true) AnBadge(t.chat.tool.capResolved, tone: AnTone.none),
    ]),
    for (final p in problems) _issue(context, p, c.danger, t.chat.tool.capProblemsLabel),
    for (final w in warnings) _issue(context, w, c.warn, t.chat.tool.capWarningsLabel),
  ]);
}

Widget _issue(BuildContext context, String text, Color color, String tag) => Padding(
      padding: const EdgeInsets.only(top: AnSpace.s4),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$tag  ', style: AnText.meta.copyWith(color: color)),
          TextSpan(text: text, style: AnText.code.copyWith(color: context.colors.inkMuted)),
        ]),
      ),
    );

// ── mcp lifecycle (F13): install / uninstall / reconnect → a ServerStatus card ──

/// The mcp server-status receipt — connected → tool count; else red 未连接 (auto-expand). mcp 状态回执。
ToolReceipt? mcpStatusReceipt(Translations t, String output) {
  final o = _obj(output);
  final status = o?['status'];
  if (status is! String) return null;
  final connected = status == 'connected';
  final tools = (o!['tools'] as List?)?.length ?? 0;
  return connected
      ? (text: t.chat.tool.mcpToolCount(n: '$tools'), tone: ToolReceiptTone.none)
      : (text: t.chat.tool.mcpDisconnected, tone: ToolReceiptTone.danger);
}

bool mcpStatusFailed(String output) {
  final s = _obj(output)?['status'];
  return s is String && s != 'connected';
}

/// mcp lifecycle body — a status badge + tool count + the tool names + the last error (if disconnected).
/// mcp 生命周期体:状态章 + 工具数 + 工具名 + 末错。
Widget mcpStatusBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted));
  final connected = o['status'] == 'connected';
  final tools = (o['tools'] as List?)?.whereType<Map>().toList() ?? const [];
  final lastError = o['lastError'] as String?;
  final failures = o['consecutiveFailures'] is int ? o['consecutiveFailures'] as int : 0;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      AnBadge(connected ? t.chat.tool.mcpConnected : t.chat.tool.mcpDisconnected, tone: connected ? AnTone.ok : AnTone.danger),
      Text(t.chat.tool.mcpToolCount(n: '${tools.length}'), style: AnText.meta.copyWith(color: c.inkFaint)),
      if (!connected && failures > 0) Text(t.chat.tool.mcpFailures(n: '$failures'), style: AnText.meta.copyWith(color: c.danger)),
    ]),
    if (tools.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s4),
      Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, children: [for (final tool in tools.take(20)) AnBadge('${tool['name']}', tone: AnTone.none)]),
    ],
    if (!connected && (lastError ?? '').isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      ToolWindow(child: Text(lastError!, style: AnText.code.copyWith(color: c.danger), maxLines: 12, overflow: TextOverflow.ellipsis)),
    ],
  ]);
}

// ── list_mcp_marketplace: the server catalog ──

/// The marketplace receipt — `{n} 个服务器`. 市场回执。
ToolReceipt? marketplaceReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  final n = o['count'] is int ? o['count'] as int : (o['servers'] as List?)?.length ?? 0;
  return (text: t.chat.tool.marketCount(n: '$n'), tone: ToolReceiptTone.none);
}

/// list_mcp_marketplace body — a server catalog (name + runtime + description + required-env count).
/// list_mcp_marketplace 体:服务器目录。
Widget marketplaceBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final servers = (_obj(state.resultText)?['servers'] as List?)?.whereType<Map>().toList() ?? const [];
  if (servers.isEmpty) return Text(t.chat.tool.marketCount(n: '0'), style: AnText.meta.copyWith(color: c.inkFaint));
  return ToolWindow(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final srv in servers.take(30))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(AnIcons.mcp, size: AnSize.iconSm, color: c.inkFaint),
              const SizedBox(width: AnSpace.s6),
              Flexible(child: Text('${srv['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.reading.weight(AnText.emphasisWeight).copyWith(color: c.ink))),
              if ((srv['runtime'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(width: AnSpace.s6),
                AnBadge('${srv['runtime']}', tone: AnTone.none),
              ],
              if (((srv['env'] as List?)?.where((e) => e is Map && e['required'] == true).length ?? 0) > 0) ...[
                const SizedBox(width: AnSpace.s6),
                AnBadge(t.chat.tool.mcpEnvRequired(n: '${(srv['env'] as List).where((e) => e is Map && e['required'] == true).length}'), tone: AnTone.warn),
              ],
            ]),
            if ((srv['description'] as String?)?.isNotEmpty ?? false)
              Padding(padding: const EdgeInsets.only(left: AnSize.iconSm + AnSpace.s6), child: Text('${srv['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkMuted))),
          ]),
        ),
    ]),
  );
}

// ── get_model_config: the model/keys/available summary ──

/// The model-config receipt — `{n} 个可用模型`. 模型配置回执。
ToolReceipt? modelConfigReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  final n = (o['availableModels'] as List?)?.length ?? 0;
  return (text: t.chat.tool.modelAvail(n: '$n'), tone: ToolReceiptTone.none);
}

/// get_model_config body — default models (per-role) + api-key count + available-model chips.
/// get_model_config 体:默认模型 + 密钥数 + 可用模型。
Widget modelConfigBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted));
  final defaults = o['defaultModels'];
  final keys = (o['apiKeys'] as List?)?.length ?? 0;
  final avail = (o['availableModels'] as List?)?.map((e) => e is Map ? '${e['id'] ?? e['name'] ?? e}' : '$e').toList() ?? const [];
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (defaults is Map && defaults.isNotEmpty) ...[
      Text(t.chat.tool.modelDefaults, style: AnText.meta.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s2),
      for (final e in defaults.entries)
        Text('${e.key}: ${e.value}', style: AnText.code.copyWith(color: c.inkMuted)),
      const SizedBox(height: AnSpace.s6),
    ],
    Text(t.chat.tool.modelKeys(n: '$keys'), style: AnText.meta.copyWith(color: c.inkFaint)),
    if (avail.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, children: [for (final m in avail.take(30)) AnBadge(m, tone: AnTone.none)]),
    ],
  ]);
}
