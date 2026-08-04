import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';
import '../../../core/run/run_nav.dart';
import 'tool_hit_list.dart';

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
  final n = o['count'] is int
      ? o['count'] as int
      : (o['edges'] as List?)?.length ?? 0;
  return n == 0
      ? (text: t.chat.tool.relNoEdges, tone: ToolReceiptTone.none)
      : (text: t.chat.tool.relCount(n: '$n'), tone: ToolReceiptTone.none);
}

/// get_relations body — each edge as a navigable `fromName (kind) → toName (kind)` row. get_relations 体。
Widget relationsBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final edges =
      (_obj(state.resultText)?['edges'] as List?)?.whereType<Map>().toList() ??
      const [];
  if (edges.isEmpty) {
    return Text(
      t.chat.tool.relNoEdges,
      style: AnText.meta.copyWith(color: c.inkFaint),
    );
  }
  return AnWindow(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in edges)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Wrap(
              spacing: AnGap.inline,
              runSpacing: AnGap.stackTight,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                toolNavPill(
                  context,
                  kind: '${e['fromKind']}',
                  label: '${e['fromName'] ?? e['fromId']}',
                  id: e['fromId'] as String?,
                ),
                Text(
                  t.chat.tool.relArrow,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
                toolNavPill(
                  context,
                  kind: '${e['toKind']}',
                  label: '${e['toName'] ?? e['toId']}',
                  id: e['toId'] as String?,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ── capability_check_workflow: the runnability report ──

/// The capability receipt — ok → 结构可运行; else red `{n} 问题` (auto-expand). 能力体检回执。
ToolReceipt? capabilityReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null || o['ok'] is! bool) return null;
  if (o['ok'] == true) {
    final warns = (o['warnings'] as List?)?.length ?? 0;
    return warns > 0
        ? (text: _capWarningsText(t, warns), tone: ToolReceiptTone.warn)
        : (text: t.chat.tool.capRunnable, tone: ToolReceiptTone.none);
  }
  final probs = (o['problems'] as List?)?.length ?? 0;
  return (text: _capProblemsText(t, probs), tone: ToolReceiptTone.danger);
}

String _capProblemsText(Translations t, int count) => count == 1
    ? t.chat.tool.capProblem(n: '$count')
    : t.chat.tool.capProblems(n: '$count');

String _capWarningsText(Translations t, int count) => count == 1
    ? t.chat.tool.capWarning(n: '$count')
    : t.chat.tool.capWarnings(n: '$count');

bool capabilityFailed(String output) => _obj(output)?['ok'] == false;

/// capability_check_workflow body — a runnable/structural/resolved flag row + a problems (red) list +
/// a warnings (amber) list. capability 体检体。
Widget capabilityBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) {
    return Text(
      state.resultText,
      style: AnText.code.copyWith(color: c.inkMuted),
    );
  }
  final problems =
      (o['problems'] as List?)?.map((e) => '$e').toList() ?? const [];
  final warnings =
      (o['warnings'] as List?)?.map((e) => '$e').toList() ?? const [];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: AnGap.inline,
        runSpacing: AnGap.stackTight,
        children: [
          AnChip(
            o['ok'] == true
                ? t.chat.tool.capRunnable
                : _capProblemsText(t, problems.length),
            tone: o['ok'] == true ? AnTone.ok : AnTone.danger,
          ),
          if (o['structurallyValid'] == true)
            AnChip(t.chat.tool.capStructural, tone: AnTone.none),
          if (o['resolved'] == true)
            AnChip(t.chat.tool.capResolved, tone: AnTone.none),
        ],
      ),
      for (final p in problems)
        _issue(context, p, c.danger, t.chat.tool.capProblemsLabel),
      for (final w in warnings)
        _issue(context, w, c.warn, t.chat.tool.capWarningsLabel),
    ],
  );
}

Widget _issue(
  BuildContext context,
  String text,
  Color color,
  String tag,
) => Padding(
  padding: const EdgeInsets.only(top: AnSpace.s4),
  // Text.rich, not RichText — RichText ignores the ambient textScaler, so a11y scaling never
  // reached these lines (A-099). Text.rich 继承环境 textScaler,a11y 缩放才生效。
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$tag  ',
          style: AnText.meta.copyWith(color: color),
        ),
        TextSpan(
          text: text,
          style: AnText.code.copyWith(color: context.colors.inkMuted),
        ),
      ],
    ),
  ),
);

// ── mcp lifecycle (F13): install / uninstall / reconnect → a ServerStatus card ──

/// The MCP server-status receipt. `ready` is the canonical healthy state; `connected`
/// remains a wire-compatibility alias for older stored tool results. `degraded` is callable
/// but deserves a warning, not a false failure. MCP 状态回执：ready 是真实成功态，connected
/// 仅兼容旧回执；degraded 仍可调用但应显示警告，不能误报失败。
ToolReceipt? mcpStatusReceipt(Translations t, String output) {
  final o = _obj(output);
  final status = o?['status'];
  if (status is! String) {
    return _mcpLifecycleErrorLike(output)
        ? (text: t.chat.tool.mcpError, tone: ToolReceiptTone.danger)
        : null;
  }
  final tools = (o!['tools'] as List?)?.length ?? 0;
  return switch (status) {
    'ready' || 'connected' => (
      text: t.chat.tool.mcpToolCount(n: '$tools'),
      tone: ToolReceiptTone.none,
    ),
    'degraded' => (text: t.chat.tool.mcpDegraded, tone: ToolReceiptTone.warn),
    _ => (text: t.chat.tool.mcpDisconnected, tone: ToolReceiptTone.danger),
  };
}

bool mcpStatusFailed(String output) {
  final o = _obj(output);
  final s = o?['status'];
  if (s is String) {
    return s != 'ready' && s != 'connected' && s != 'degraded';
  }
  // Tool execution errors are surfaced as plain text by the loop. Install/reconnect used to
  // remain green because this predicate only understood the successful JSON status shape.
  // 工具执行错误经 loop 以纯文本浮出；此前这里只认成功 JSON，导致安装/重连失败仍显绿。
  return _mcpLifecycleErrorLike(output);
}

bool _mcpLifecycleErrorLike(String output) {
  final text = output.trim();
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  return RegExp(r'\bmcp_[a-z0-9_]+\b').hasMatch(text) ||
      lower.contains('required environment variables missing') ||
      lower.contains('mcp server install failed') ||
      lower.contains('mcp server not found') ||
      lower.contains('mcp server is not connected') ||
      lower.contains('mcp server name already exists') ||
      lower.contains('mcp registry entry not found') ||
      lower.contains('no package with a supported runtime') ||
      (lower.contains('mcp oauth') && lower.contains('failed'));
}

/// mcp lifecycle body — a status badge + tool count + the tool names + the last error (if unhealthy).
/// mcp 生命周期体:状态章 + 工具数 + 工具名 + 末错。
Widget mcpStatusBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) {
    // A failed tool_result already gets the canonical error section from the chassis. Do not render
    // the same plain error a second time in the family body; JSON status failures are still projected
    // below because they are completed tool results with a failed payload, not a failed frame.
    // 失败 tool_result 已由底盘统一渲染错误区；纯文本错误不在族体重复。JSON 状态失败仍保留在下方投影，
    // 因为那是 completed 帧里的失败 payload，而不是 error 帧。
    if (state.phase == ToolCardPhase.failed) return const SizedBox.shrink();
    return Text(
      state.resultText,
      style: AnText.code.copyWith(
        color: _mcpLifecycleErrorLike(state.resultText) ? c.danger : c.inkMuted,
      ),
    );
  }
  final status = o['status'];
  final healthy = status == 'ready' || status == 'connected';
  final degraded = status == 'degraded';
  final tools = (o['tools'] as List?)?.whereType<Map>().toList() ?? const [];
  final lastError = o['lastError'] as String?;
  final connectedAt = o['connectedAt'] as String?;
  final connectedAtLabel = connectedAt == null ? null : fmtStamp(connectedAt);
  final failures = o['consecutiveFailures'] is int
      ? o['consecutiveFailures'] as int
      : 0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: AnGap.inline,
        runSpacing: AnGap.stackTight,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AnChip(
            healthy
                ? t.chat.tool.mcpConnected
                : degraded
                ? t.chat.tool.mcpDegraded
                : t.chat.tool.mcpDisconnected,
            tone: healthy
                ? AnTone.ok
                : degraded
                ? AnTone.warn
                : AnTone.danger,
          ),
          Text(
            t.chat.tool.mcpToolCount(n: '${tools.length}'),
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
          if (!healthy && failures > 0)
            Text(
              t.chat.tool.mcpFailures(n: '$failures'),
              style: AnText.meta.copyWith(color: c.danger),
            ),
        ],
      ),
      if (tools.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s4),
        Wrap(
          spacing: AnGap.inline,
          runSpacing: AnGap.stackTight,
          children: [
            for (final tool in tools.take(20))
              AnChip('${tool['name']}', tone: AnTone.none),
          ],
        ),
      ],
      if (connectedAtLabel != null && connectedAtLabel.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        AnKv(
          rows: [
            AnKvRow(t.chat.tool.mcpConnectedAt, connectedAtLabel, meta: true),
          ],
          dense: true,
        ),
      ],
      if (!healthy && (lastError ?? '').isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        rawMonoWindow(
          context,
          lastError!,
          maxLines: AnCap.monoErrorLines,
          color: c.danger,
        ),
      ],
    ],
  );
}

// ── list_mcp_marketplace: the server catalog ──

/// The marketplace receipt — `{n} 个服务器`. 市场回执。
ToolReceipt? marketplaceReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  final n = o['count'] is int
      ? o['count'] as int
      : (o['servers'] as List?)?.length ?? 0;
  return (text: t.chat.tool.marketCount(n: '$n'), tone: ToolReceiptTone.none);
}

/// list_mcp_marketplace body — a server catalog (name + runtime + description + required-env count).
/// list_mcp_marketplace 体:服务器目录。
Widget marketplaceBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final servers =
      (_obj(state.resultText)?['servers'] as List?)
          ?.whereType<Map>()
          .toList() ??
      const [];
  if (servers.isEmpty) {
    return Text(
      t.chat.tool.marketCount(n: '0'),
      style: AnText.meta.copyWith(color: c.inkFaint),
    );
  }
  // The shared hit gate (批6 A-049: a marketplace IS a directory listing — the hand-rolled rows and
  // their indent arithmetic retire; the gate carries its own window, the outer AnWindow is removed
  // with it — leaf law). 共享命中门(市场=目录枚举;手搓行+缩进算术退役;门自带窗,外窗随撤防套窗)。
  return ToolHitList(
    rows: [
      for (final srv in servers)
        ToolHitRow(
          glyph: AnIcons.mcp,
          title: '${srv['name']}',
          subtitle: srv['description'] as String?,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((srv['runtime'] as String?)?.isNotEmpty ?? false)
                AnChip('${srv['runtime']}', tone: AnTone.none),
              if (((srv['env'] as List?)
                          ?.where((e) => e is Map && e['required'] == true)
                          .length ??
                      0) >
                  0) ...[
                const SizedBox(width: AnSpace.s6),
                AnChip(
                  t.chat.tool.mcpEnvRequired(
                    n: '${(srv['env'] as List).where((e) => e is Map && e['required'] == true).length}',
                  ),
                  tone: AnTone.warn,
                ),
              ],
            ],
          ),
        ),
    ],
    cap: 30,
    total: servers.length,
    rawJson: state.resultText,
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

String _modelConfigCompact(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  if (n <= 0) return '—';
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  }
  return '$n';
}

String _modelConfigMedia(Translations t, Map model) {
  final media = <String>[];
  if (model['vision'] == true) media.add(t.chat.tool.modelVision);
  if (model['video'] == true) media.add(t.chat.tool.modelVideo);
  if (model['audio'] == true) media.add(t.chat.tool.modelAudio);
  return media.isEmpty ? '—' : media.join(' · ');
}

String _modelConfigRole(Translations t, String key) => switch (key) {
  'dialogue' => t.chat.tool.modelDialogue,
  'utility' => t.chat.tool.modelUtility,
  'agent' => t.chat.tool.modelAgent,
  'image' => t.chat.tool.modelImage,
  'speech' => t.chat.tool.modelSpeech,
  'video' => t.chat.tool.modelVideoRole,
  _ => key,
};

/// get_model_config body — the tool card is the durable projection of the real config, not just a
/// count. It omits apiKeyId and encrypted values while keeping defaults, masked key health, endpoints,
/// and model capabilities visible without trusting prose generated by the model.
/// get_model_config 体:卡片是真实配置投影,不是只报数量;不泄 apiKeyId/密文,但完整呈现可诊断事实。
Widget modelConfigBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) {
    return Text(
      state.resultText,
      style: AnText.code.copyWith(color: c.inkMuted),
    );
  }
  final defaults = o['defaultModels'];
  final keys = (o['apiKeys'] as List?)?.whereType<Map>().toList() ?? const [];
  final available =
      (o['availableModels'] as List?)?.whereType<Map>().toList() ?? const [];
  final keyNames = <String, String>{
    for (final key in keys)
      if ('${key['id'] ?? ''}'.isNotEmpty &&
          '${key['displayName'] ?? ''}'.isNotEmpty)
        '${key['id']}': '${key['displayName']}',
  };
  final defaultRows = <AnKvRow>[];
  if (defaults is Map) {
    for (final entry in defaults.entries) {
      final value = entry.value;
      final modelId = value is Map ? '${value['modelId'] ?? '—'}' : '$value';
      final keyName = value is Map ? keyNames['${value['apiKeyId']}'] : null;
      defaultRows.add(
        AnKvRow(
          _modelConfigRole(t, '${entry.key}'),
          keyName == null || keyName.isEmpty || modelId == 'not configured'
              ? modelId
              : '$modelId · $keyName',
          mono: true,
        ),
      );
    }
  }
  final keyRows = [
    for (final key in keys)
      <String, String>{
        'name': '${key['displayName'] ?? t.chat.tool.modelUnnamedKey}',
        'provider': '${key['provider'] ?? '—'}',
        'masked': '${key['keyMasked'] ?? '—'}',
        'status': '${key['testStatus'] ?? '—'}',
      },
  ];
  final modelRows = [
    for (final model in available.take(50))
      <String, String>{
        'model': '${model['modelId'] ?? model['displayName'] ?? '—'}',
        'provider': '${model['provider'] ?? '—'}',
        'context': _modelConfigCompact(model['contextWindow']),
        'output': _modelConfigCompact(model['maxOutput']),
        'media': _modelConfigMedia(t, model),
      },
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (defaultRows.isNotEmpty) ...[
        AnFieldSection(
          label: t.chat.tool.modelDefaults,
          child: AnKv(dense: true, rows: defaultRows),
        ),
        const SizedBox(height: AnSpace.s6),
      ],
      AnFieldSection(
        label: t.chat.tool.modelConfigKeysSection,
        child: keys.isEmpty
            ? Text(t.chat.tool.modelNoKeys, style: AnText.meta)
            : AnThinTable(
                columns: [
                  AnTableColumn('name', label: t.chat.tool.modelKeyName),
                  AnTableColumn(
                    'provider',
                    label: t.chat.tool.modelKeyProvider,
                  ),
                  AnTableColumn('masked', label: t.chat.tool.modelKeyMasked),
                  AnTableColumn('status', label: t.chat.tool.modelKeyStatus),
                ],
                rows: keyRows,
              ),
      ),
      if (keys.any((key) => '${key['baseUrl'] ?? ''}'.isNotEmpty)) ...[
        const SizedBox(height: AnSpace.s6),
        AnFieldSection(
          label: t.chat.tool.modelEndpoints,
          child: AnKv(
            dense: true,
            rows: [
              for (final key in keys)
                if ('${key['baseUrl'] ?? ''}'.isNotEmpty)
                  AnKvRow(
                    '${key['displayName'] ?? t.chat.tool.modelUnnamedKey}',
                    '${key['baseUrl']}',
                    mono: true,
                  ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AnSpace.s8),
      AnFieldSection(
        label: t.chat.tool.modelConfigModelsSection,
        child: modelRows.isEmpty
            ? Text(t.chat.tool.modelNoModels, style: AnText.meta)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnThinTable(
                    columns: [
                      AnTableColumn('model', label: t.chat.tool.modelModel),
                      AnTableColumn(
                        'provider',
                        label: t.chat.tool.modelKeyProvider,
                      ),
                      AnTableColumn('context', label: t.chat.tool.modelContext),
                      AnTableColumn('output', label: t.chat.tool.modelOutput),
                      AnTableColumn('media', label: t.chat.tool.modelMedia),
                    ],
                    rows: modelRows,
                  ),
                  if (available.length > 50)
                    Padding(
                      padding: const EdgeInsets.only(top: AnSpace.s4),
                      child: Text(
                        t.chat.tool.modelMore(n: '${available.length - 50}'),
                        style: AnText.meta,
                      ),
                    ),
                  for (final model in available.take(50))
                    if ((model['nativeOptions'] as List?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: AnSpace.s4),
                        child: Wrap(
                          spacing: AnGap.inline,
                          runSpacing: AnSpace.s4,
                          children: [
                            AnChip(
                              '${model['modelId'] ?? '—'} · ${t.chat.tool.modelOptions}',
                              tone: AnTone.none,
                            ),
                            for (final option
                                in (model['nativeOptions'] as List)
                                    .whereType<Map>())
                              AnChip(
                                '${option['label'] ?? option['key'] ?? '—'}',
                                look: AnChipLook.outlined,
                                mono: true,
                              ),
                          ],
                        ),
                      ),
                ],
              ),
      ),
    ],
  );
}
