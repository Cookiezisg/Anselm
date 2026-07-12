import 'package:flutter/widgets.dart';

import '../../../core/design/typography.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/an_chip.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import 'tool_card_nav.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_hit_list.dart';

/// F07 searches settled body (WRK-056 §F07.4) — the hits become a [ToolHitList]: a directory of doors,
/// each row tappable to its entity panel (via the registry — no-panel kinds stay inert). Reads the ONE
/// [parseSearchHits] extractor (double-shape, nil-safe); `total > count` (engine path) drives the
/// server-truncated note, `rows > cap` the local escape hatch. The empty result never reaches here
/// (the spec's `hasBodyOf` makes an empty search «receipt IS the card» — no chevron). F07 命中→命中窗:
/// 一排可推开的门,行 tap 跳实体面板(注册表门控);空结果不到此(hasBodyOf 令其回执即卡)。
Widget Function(BuildContext, ToolCardState) searchHitBody({
  required String listKey,
  required int cap,
  required ToolHitRow Function(Translations t, Map<String, dynamic> hit) row,
}) =>
    (context, state) {
      final h = parseSearchHits(state.resultText, listKey);
      if (h == null || h.items.isEmpty) return const SizedBox.shrink();
      final t = Translations.of(context);
      return ToolHitList(
        rows: h.items.map((hit) => row(t, hit)).toList(),
        cap: cap,
        total: h.total,
        serverTruncated: h.total != null && h.total! > h.count,
        rawJson: state.resultText,
        onRowTap: (kind, id) => goToPanel(context, kind, id),
      );
    };

/// A plain entity hit: glyph + name + description/snippet + tail mono id (tappable to [rowKind]'s
/// panel). Used by the six entity searches + search_documents. 通用实体命中行。
ToolHitRow entityHitRow(String rowKind, Map<String, dynamic> hit) {
  final id = (hit['id'] ?? '').toString();
  final name = (hit['name'] ?? id).toString();
  final snippet = (hit['description'] ?? hit['snippet'])?.toString();
  return ToolHitRow(
    glyph: AnIcons.entityKindGlyph(rowKind),
    title: name,
    subtitle: snippet,
    kind: rowKind,
    id: id.isEmpty ? null : id,
    trailing: id.isEmpty ? null : Text(id, style: AnText.mono),
  );
}

/// search_workflow: the FALLBACK path alone carries `lifecycleState`/`active` (key-probed — engine path
/// omits them, so no fake badge). active → ok badge, else the lifecycle word. workflow 命中:回退独有徽章。
ToolHitRow workflowHitRow(Translations t, Map<String, dynamic> hit) {
  final id = (hit['id'] ?? '').toString();
  final name = (hit['name'] ?? id).toString();
  final ls = hit['lifecycleState']?.toString();
  final active = hit['active'] == true;
  return ToolHitRow(
    glyph: AnIcons.entityKindGlyph('workflow'),
    title: name,
    subtitle: (hit['description'] ?? hit['snippet'])?.toString(),
    kind: 'workflow',
    id: id.isEmpty ? null : id,
    trailing: ls == null
        ? (id.isEmpty ? null : Text(id, style: AnText.mono))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            AnChip(active ? t.chat.tool.wfActive : ls, tone: active ? AnTone.ok : AnTone.none),
          ]),
  );
}

/// search_triggers: the FALLBACK path alone carries `kind`/`refCount`/`listening` (key-probed). trigger 命中。
ToolHitRow triggerHitRow(Translations t, Map<String, dynamic> hit) {
  final id = (hit['id'] ?? '').toString();
  final name = (hit['name'] ?? id).toString();
  final kind = hit['kind']?.toString();
  final refCount = hit['refCount'];
  final listening = hit['listening'];
  final badges = <Widget>[
    if (kind != null) AnChip(kind, tone: AnTone.none),
    if (refCount is int) AnChip(t.chat.tool.refCount(n: '$refCount'), tone: AnTone.none),
    if (listening == true) AnChip(t.chat.tool.trgListening, tone: AnTone.ok),
  ];
  return ToolHitRow(
    glyph: AnIcons.entityKindGlyph('trigger'),
    title: name,
    subtitle: (hit['description'] ?? hit['snippet'])?.toString(),
    kind: 'trigger',
    id: id.isEmpty ? null : id,
    trailing: badges.isEmpty
        ? (id.isEmpty ? null : Text(id, style: AnText.mono))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            for (final b in badges) Padding(padding: const EdgeInsets.only(left: 4), child: b),
          ]),
  );
}

/// search_blocks: each hit's kind VARIES (function/handler/mcp/agent/control/approval); the nav target
/// is `entityId` (mcp has no panel → inert). name + snippet, tail = the wireable `ref`. block 命中:逐 hit kind。
ToolHitRow blockHitRow(Map<String, dynamic> hit) {
  final kind = (hit['kind'] ?? '').toString();
  final entityId = (hit['entityId'] ?? '').toString();
  final ref = (hit['ref'] ?? '').toString();
  final name = (hit['name'] ?? ref).toString();
  return ToolHitRow(
    glyph: AnIcons.entityKindGlyph(kind),
    title: name,
    subtitle: hit['snippet']?.toString(),
    kind: kind.isEmpty ? null : kind,
    id: entityId.isEmpty ? null : entityId,
    trailing: ref.isEmpty ? null : Text(ref, style: AnText.mono),
  );
}

/// list_documents: the folder level — name + path (mono, position order preserved by the wire). 文档树一层。
ToolHitRow documentListRow(Map<String, dynamic> hit) {
  final id = (hit['id'] ?? '').toString();
  final name = (hit['name'] ?? id).toString();
  return ToolHitRow(
    glyph: AnIcons.entityKindGlyph('document'),
    title: name,
    subtitle: (hit['path'] ?? hit['description'])?.toString(),
    kind: 'document',
    id: id.isEmpty ? null : id,
  );
}

/// list_attachments: filename + mime · size. Attachments have NO panel → inert (informational). 附件清单(惰性)。
ToolHitRow attachmentListRow(Map<String, dynamic> hit) {
  final filename = (hit['filename'] ?? hit['id'] ?? '?').toString();
  final mime = (hit['mime'] ?? '').toString();
  final size = hit['sizeBytes'];
  final sub = [if (mime.isNotEmpty) mime, if (size is int) formatBytes(size)].join(' · ');
  return ToolHitRow(
    glyph: AnIcons.attach,
    title: filename,
    subtitle: sub.isEmpty ? null : sub,
    // 'attachment' has no panel — an inert, informational row. 无面板→惰性。
    kind: 'attachment',
    id: (hit['id'] ?? '').toString(),
  );
}
