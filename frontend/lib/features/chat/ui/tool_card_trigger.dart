import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';

/// F04 create/edit_trigger — the TriggerConfigCard (WRK-056 §trigger): one of FOUR faces by kind
/// (cron / webhook / fsnotify / sensor). Config is a whole-set replace, so the card always renders the
/// full new config. create returns `listening:false` (create doesn't attach a listener — an active
/// workflow reference starts it); edit is a hot-update on a live trigger. trigger 四 kind 配置脸。
Widget triggerConfigBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;

  Map<String, dynamic>? args, result;
  try {
    final d = jsonDecode(state.argsText);
    if (d is Map<String, dynamic>) args = d;
  } catch (_) {}
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) result = d;
  } catch (_) {}

  final kind = (args?['kind'] ?? '').toString();
  final config = (args?['config'] as Map?) ?? const {};
  final id = (result?['id'] ?? '').toString();

  final rows = <Widget>[
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    ..._faceOf(context, t, c, kind, config, id),
  ];

  // Create never listens — a note; edit hot-updates a live trigger. 创建不监听→注记。
  final listening = result?['listening'] == true;
  if (!listening && state.toolName.startsWith('create_')) {
    rows.add(Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Text(t.chat.tool.trgCreateNote, style: AnText.meta.copyWith(color: c.inkFaint)),
    ));
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
}

/// The trigger config faces as a Column, from an ALREADY-parsed kind + config (get_trigger's JSON).
/// Shared by F04 build + F06 get. 从已解析 kind+config 渲四 kind 脸(F04 建 + F06 get 共享)。
Widget triggerConfigFaces(BuildContext context, String kind, Map config, String id) {
  final t = Translations.of(context);
  final c = context.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: _faceOf(context, t, c, kind, config, id),
  );
}

List<Widget> _faceOf(BuildContext context, Translations t, AnColors c, String kind, Map config, String id) {
  switch (kind) {
    case 'cron':
      final expr = (config['expression'] ?? '').toString();
      return [
        // The expression carries the visual weight (no display type tier — emphasis via weight). cron 表达式加重。
        Text(expr, style: AnText.codeReading.copyWith(color: c.ink).weight(AnText.emphasisWeight)),
      ];
    case 'webhook':
      final path = (config['path'] ?? '').toString();
      final hasSecret = config['secret'] != null && '${config['secret']}'.isNotEmpty;
      final algo = (config['signatureAlgo'] ?? '').toString();
      return [
        // The full, ready-to-copy webhook URL (id from the result). 完整可复制 URL。
        if (id.isNotEmpty && path.isNotEmpty)
          AnChip('POST /api/v1/webhooks/$id/$path',
              look: AnChipLook.outlined, mono: true, copyValue: 'POST /api/v1/webhooks/$id/$path')
        else if (path.isNotEmpty)
          Text('/$path', style: AnText.mono.copyWith(color: c.inkMuted)),
        if (hasSecret || algo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Wrap(spacing: AnGap.inline, children: [
              // The secret value is NEVER shown — only that it's set. 密钥值绝不显、只显有无。
              if (hasSecret) AnChip(t.chat.tool.trgSecret, look: AnChipLook.outlined, icon: AnIcons.approval),
              if (algo.isNotEmpty) AnChip(algo, tone: AnTone.none),
            ]),
          ),
      ];
    case 'fsnotify':
      final path = (config['path'] ?? '').toString();
      final events = (config['events'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final pattern = (config['pattern'] ?? '').toString();
      return [
        Text(path, style: AnText.mono.copyWith(color: c.inkMuted)),
        if (events.isNotEmpty || pattern.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s2, children: [
              for (final e in events) AnChip(e, tone: AnTone.none),
              if (pattern.isNotEmpty) Text(pattern, style: AnText.mono.copyWith(color: c.inkFaint)),
            ]),
          ),
      ];
    case 'sensor':
      final targetKind = (config['targetKind'] ?? '').toString();
      final targetId = (config['targetId'] ?? '').toString();
      final method = (config['method'] ?? '').toString();
      final interval = config['intervalSec'];
      final condition = (config['condition'] ?? '').toString();
      final output = (config['output'] ?? '').toString();
      return [
        Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (targetKind.isNotEmpty && targetId.isNotEmpty)
            AnRefPill(kind: targetKind, label: method.isEmpty ? targetId : '$targetId.$method()', id: targetId),
          if (interval != null) AnChip(t.chat.tool.trgEvery(n: '$interval'), tone: AnTone.none),
        ]),
        if (condition.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text('${t.chat.tool.trgCondition} · $condition', style: AnText.mono.copyWith(color: c.inkMuted)),
          ),
        if (output.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text('${t.chat.tool.trgOutput} · $output', style: AnText.mono.copyWith(color: c.inkFaint)),
          ),
      ];
    default:
      // Raw JSON goes to the bounded tree like everywhere else (批5 顺手关 A-005). JSON 走有界树。
      return [AnWindow(child: SizedBox(height: AnSize.jsonViewport, child: AnJsonTree(data: config, showRoot: false)))];
  }
}


/// The trigger collapsed-row receipt: the kind + its listening state. create → `未监听` (expected — an
/// active workflow reference starts it); edit on a live trigger → `热更新已生效` (its config took effect
/// at once). trigger 回执:kind + 监听态。
ToolReceipt? triggerReceipt(Translations t, ToolCardState state) {
  Map<String, dynamic>? out;
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) out = d;
  } catch (_) {}
  if (out == null) return null;
  final listening = out['listening'] == true;
  return listening
      ? (text: t.chat.tool.trgHotUpdate, tone: ToolReceiptTone.warn)
      : (text: t.chat.tool.trgNotListening, tone: ToolReceiptTone.none);
}
