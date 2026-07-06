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
import '../../../core/ui/an_field.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';
import 'tool_hit_list.dart';

// F17 conversation (B3.7) — the «thin card» family (constitution #9: restraint IS perfection). manage
// echoes the updated status; list/search render conversations as a mini-rail of tappable doors (a
// [ToolHitList], NOT a JSON corpse). The real stage is OFF the card — rename plays through the
// autoname typewriter in the head/rail. F17 薄卡:manage 状态回显 / list·search 迷你 rail 命中门。

/// The soft-fail sentence when there's no conversation in context. ctx 无对话时的软失败句。
const _manageSoftFail = 'manage_conversation is only available inside a conversation';

Map<String, dynamic>? _json(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

String _shortId(String id) => id.length > 12 ? '${id.substring(0, 12)}…' : id;

void _navConversation(BuildContext context, String kind, String id) {
  final loc = panelLocationFor(kind, id);
  if (loc != null && context.mounted) context.go(loc);
}

/// The manage_conversation verb — dispatched by ACTION (5 pairs + fallback). Settled reads
/// `output.action` (the wire truth); live reads `args.action` (partial). A soft-fail (no conversation
/// in context, still a succeeded result) degrades to the neutral «已调用». manage 动词:action 分派 + 软失败降级。
String manageConversationVerb(Translations t, ToolCardState s, {required bool live}) {
  // Soft-fail: a succeeded string, not a real action → neutral. 软失败→中性。
  if (s.phase != ToolCardPhase.argsStreaming && s.resultText.startsWith(_manageSoftFail)) {
    return live ? t.chat.tool.calling : t.chat.tool.called;
  }
  String? action;
  if (s.phase != ToolCardPhase.argsStreaming) action = _json(s.resultText)?['action'] as String?;
  action ??= argString(s.argsText, 'action');
  switch (action) {
    case 'archive':
      return live ? t.chat.tool.cvArchiving : t.chat.tool.cvArchived;
    case 'unarchive':
      return live ? t.chat.tool.cvUnarchiving : t.chat.tool.cvUnarchived;
    case 'pin':
      return live ? t.chat.tool.cvPinning : t.chat.tool.cvPinned;
    case 'unpin':
      return live ? t.chat.tool.cvUnpinning : t.chat.tool.cvUnpinned;
    case 'rename':
      return live ? t.chat.tool.cvRenaming : t.chat.tool.cvRenamed;
    default:
      return live ? t.chat.tool.cvManaging : t.chat.tool.cvManaged;
  }
}

/// manage_conversation body — a dense status echo (`archived` / `pinned` / `title`, from the OUTPUT,
/// never guessed) + the archive product-fact. A soft-fail shows the raw sentence (so «已归档对话» is
/// never a lie). manage 体:状态回显 + 归档产品事实;软失败原文。
Widget manageConversationBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  if (state.resultText.startsWith(_manageSoftFail)) {
    return ToolWindow(child: Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted)));
  }
  final o = _json(state.resultText);
  if (o == null) {
    return ToolWindow(child: Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 20, overflow: TextOverflow.ellipsis));
  }
  final rows = <AnKvRow>[
    if ((o['title'] as String?)?.isNotEmpty == true) AnKvRow(t.chat.tool.cvStatusTitle, '${o['title']}', wrap: true),
    AnKvRow(t.chat.tool.cvStatusArchived, o['archived'] == true ? '✓' : '—'),
    AnKvRow(t.chat.tool.cvStatusPinned, o['pinned'] == true ? '✓' : '—'),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    AnKv(rows: rows, dense: true),
    // archive is a no-op on the live thread — an honest product fact. 归档产品事实。
    if (o['action'] == 'archive')
      Padding(padding: const EdgeInsets.only(top: AnSpace.s6), child: Text(t.chat.tool.cvAutoUnarchive, style: AnText.meta.copyWith(color: c.inkFaint))),
  ]);
}

/// A conversation hit row: a pin/chat glyph + title (id fallback) + snippet (search) + tail (archived
/// badge · relative-ish time / ×N chunks). Tappable → /chat/:id. 对话命中行。
ToolHitRow conversationHitRow(BuildContext context, Translations t, Map<String, dynamic> h, {required bool isSearch}) {
  final id = '${h['conversationId'] ?? ''}';
  final title = (h['title'] as String?)?.isNotEmpty == true ? '${h['title']}' : _shortId(id);
  final pinned = h['pinned'] == true;
  final archived = h['archived'] == true;
  final trailing = <Widget>[];
  if (archived) trailing.add(AnBadge(t.chat.tool.cvArchivedBadge, tone: AnTone.none));
  if (isSearch) {
    final chunks = h['matchedChunks'];
    if (chunks is int && chunks > 0) trailing.add(Text(t.chat.tool.cvChunks(n: '$chunks'), style: AnText.meta));
  } else {
    final at = fmtStamp(h['lastMessageAt'] as String?);
    if (at.isNotEmpty) trailing.add(Text(at, style: AnText.meta));
  }
  return ToolHitRow(
    glyph: pinned ? AnIcons.pin : AnIcons.chat,
    title: title,
    subtitle: isSearch ? h['snippet'] as String? : null,
    trailing: trailing.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: [
            for (final w in trailing) Padding(padding: const EdgeInsets.only(left: AnSpace.s4), child: w),
          ]),
    kind: 'conversation',
    id: id.isEmpty ? null : id,
  );
}

/// list_conversations / search_conversations body — a [ToolHitList] mini-rail. list caps at 50 (a
/// `nextCursor` → «还有更多页»); search caps at 20 (`total > hits` → «显示前 N · 共 M 命中»). The empty
/// result never reaches here (hasBodyOf makes it «receipt IS the card»). list/search 迷你 rail 命中门。
Widget Function(BuildContext, ToolCardState) conversationHitBody({required bool isSearch}) => (context, state) {
      final o = _json(state.resultText);
      if (o == null) return const SizedBox.shrink();
      final listKey = isSearch ? 'hits' : 'conversations';
      final items = (o[listKey] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
      if (items.isEmpty) return const SizedBox.shrink();
      final t = Translations.of(context);
      final hitList = ToolHitList(
        rows: [for (final h in items) conversationHitRow(context, t, h, isSearch: isSearch)],
        cap: isSearch ? 20 : 50,
        rawJson: state.resultText,
        onRowTap: (kind, id) => _navConversation(context, kind, id),
      );
      // The «server has more» note (constitution #4: truncation must be stated). 服务端更多注记。
      final total = o['total'];
      String? moreNote;
      if (isSearch) {
        if (total is int && total > items.length) moreNote = t.chat.tool.cvShownOfTotal(n: '${items.length}', total: '$total');
      } else if (o['nextCursor'] != null) {
        moreNote = t.chat.tool.cvMorePages;
      }
      if (moreNote == null) return hitList;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        hitList,
        Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(moreNote, style: AnText.meta.copyWith(color: context.colors.inkFaint))),
      ]);
    };

/// list_conversations receipt — `N 条` / `N+ 条` (nextCursor) / `无对话`. list 回执。
ToolReceipt? listConversationsReceipt(Translations t, String output) {
  final o = _json(output);
  if (o == null) return null;
  final count = o['count'];
  if (count is! int) return null;
  if (count == 0) return (text: t.chat.tool.cvEmpty, tone: ToolReceiptTone.none);
  final more = o['nextCursor'] != null;
  return (text: more ? t.chat.tool.cvCountMore(n: '$count') : t.chat.tool.cvCount(n: '$count'), tone: ToolReceiptTone.none);
}

/// search_conversations receipt — `N 命中` / `无匹配`. search 回执(用「命中」不用「条」)。
ToolReceipt? searchConversationsReceipt(Translations t, String output) {
  final o = _json(output);
  if (o == null) return null;
  final total = o['total'];
  if (total is! int) return null;
  return total == 0
      ? (text: t.chat.tool.cvNoMatch, tone: ToolReceiptTone.none)
      : (text: t.chat.tool.cvHits(n: '$total'), tone: ToolReceiptTone.none);
}

/// Whether the list/search body has hits (empty → «receipt IS the card»). 有无命中(空=回执即卡)。
bool conversationHasBody(String output, {required bool isSearch}) {
  final o = _json(output);
  if (o == null) return false;
  final items = o[isSearch ? 'hits' : 'conversations'];
  return items is List && items.isNotEmpty;
}
