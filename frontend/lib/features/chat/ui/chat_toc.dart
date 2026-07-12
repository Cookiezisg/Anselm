import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/messages/transcript_nav.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/chat_providers.dart';
import '../state/transcript_jump_provider.dart';

/// The full anchor list of one conversation — loops the keyset pages so the 场次条 offers EVERY
/// scene, any depth (a navigation aid must not silently truncate; the page cap is a runaway
/// backstop far above any real thread). Re-fetched each open via invalidate.
///
/// 一个对话的全量锚点——循环 keyset 分页,场次条给出**任意深度**的每一场(导航辅助不得静默截断;
/// 页数上限是远超真实线程的失控兜底)。每次打开经 invalidate 重拉。
final transcriptAnchorsProvider =
    FutureProvider.autoDispose.family<List<TranscriptAnchor>, String>((ref, conversationId) async {
  final repo = ref.watch(chatRepositoryProvider);
  final out = <TranscriptAnchor>[];
  String? cursor;
  for (var page = 0; page < 40; page++) {
    final p = await repo.listAnchors(conversationId, cursor: cursor, limit: 50);
    out.addAll(p.items);
    if (p.isLastPage || p.nextCursor == null) break;
    cursor = p.nextCursor;
  }
  return out;
});

/// The 场次条 (scene strip) — a 目录 button in the chat head opening an anchored overlay drawer:
/// pending human gates ride the top in amber (they outrank everything — the run is WAITING), then
/// the newest-first scene timeline where user turns are the primary anchors, consecutive machine
/// actions stay folded as「⚙ N 项操作」cluster rows, and dangerous calls / compaction marks /
/// abnormal terminals surface individually. Tapping an anchor fires [transcriptJumpProvider] (the
/// transcript re-anchors, any depth) and the drawer closes itself.
///
/// 场次条——chat 头带目录钮,开锚定覆盖抽屉:待决人闸琥珀置顶(压过一切——run 在**等人**),下接
/// newest-first 场次时间线:user 回合是主锚,连续机器动作保持「⚙ N 项操作」折叠簇行,危险调用/压缩
/// 标记/异常终态逐条露出。点锚发 [transcriptJumpProvider](transcript 任意深度重锚),抽屉自收。
class TranscriptToc extends ConsumerStatefulWidget {
  const TranscriptToc({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<TranscriptToc> createState() => _TranscriptTocState();
}

class _TranscriptTocState extends ConsumerState<TranscriptToc> {
  final AnPopoverController _pop = AnPopoverController();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_pop.isOpen) {
      // Anchors are a journal projection — re-read on every open so the strip is never stale.
      // 锚点是日志投影——每次打开重读,场次条永不过期。
      ref.invalidate(transcriptAnchorsProvider(widget.conversationId));
    }
    _pop.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AnPopover(
      controller: _pop,
      alignEnd: false,
      anchor: AnTooltip(
        message: t.chat.toc.button,
        child: AnButton.iconOnly(
          AnIcons.listBulleted,
          onPressed: _toggle,
          semanticLabel: t.chat.toc.button,
        ),
      ),
      overlayBuilder: (context, _) => _TocPanel(
        conversationId: widget.conversationId,
        onJump: (a) {
          _pop.close();
          if (a.messageId.isNotEmpty) {
            ref
                .read(transcriptJumpProvider(widget.conversationId).notifier)
                .request(a.messageId, blockId: a.blockId);
          }
        },
      ),
    );
  }
}

class _TocPanel extends ConsumerWidget {
  const _TocPanel({required this.conversationId, required this.onJump});

  final String conversationId;
  final ValueChanged<TranscriptAnchor> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final anchors = ref.watch(transcriptAnchorsProvider(conversationId));
    return ConstrainedBox(
      // Taller than a command menu on purpose: a NAVIGATION surface earns its height — more
      // scenes visible per glance, deeper anchors reachable without scrolling. 比命令菜单高是
      // 有意的:导航面配得上高度——一眼更多场次、更深锚点免滚可达。
      constraints: const BoxConstraints(maxHeight: 560, maxWidth: 340, minWidth: 280),
      child: AnMenuSurface(
        children: switch (anchors) {
          AsyncData(value: final rows) when rows.isEmpty => [
              Padding(
                padding: const EdgeInsets.all(AnSpace.s16),
                child: Text(t.chat.toc.empty, style: AnText.label.copyWith(color: c.inkFaint)),
              ),
            ],
          AsyncData(value: final rows) => _list(context, rows),
          AsyncError() => [
              Padding(
                padding: const EdgeInsets.all(AnSpace.s16),
                child: Text(t.chat.transcriptErrorHint,
                    style: AnText.label.copyWith(color: c.inkFaint)),
              ),
            ],
          _ => const [
              Padding(
                padding: EdgeInsets.all(AnSpace.s16),
                child: Center(child: AnSpinner()),
              ),
            ],
        },
      ),
    );
  }

  List<Widget> _list(BuildContext context, List<TranscriptAnchor> rows) {
    final t = Translations.of(context);
    // Gates outrank the timeline (the run is WAITING on a human). 人闸压过时间线(run 在等人)。
    final gates = rows.where((a) => a.kind == 'gate').toList(growable: false);
    final timeline = rows.where((a) => a.kind != 'gate').toList(growable: false);
    return [
      if (gates.isNotEmpty) ...[
        _section(context, t.chat.toc.gates),
        for (final a in gates) _row(context, a),
      ],
      for (final a in timeline) _row(context, a),
    ];
  }

  Widget _section(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s6, AnSpace.s12, AnSpace.s2),
        child: Text(label,
            style: AnText.meta.copyWith(color: context.colors.inkFaint)),
      );

  Widget _row(BuildContext context, TranscriptAnchor a) {
    final c = context.colors;
    final t = Translations.of(context);
    final (icon, color, label) = switch (a.kind) {
      'gate' => (AnIcons.ask, c.warn, a.title),
      'danger' => (AnIcons.danger, c.danger, a.title),
      'tools' => (AnIcons.gear, c.inkFaint, t.chat.toc.toolCluster(n: a.count)),
      'compaction' => (AnIcons.archive, c.inkFaint, a.title.isEmpty ? t.chat.toc.compaction : a.title),
      'abnormal' => (AnIcons.error, c.warn, a.title.isEmpty ? t.chat.toc.abnormal : a.title),
      'user' => (AnIcons.chat, c.inkMuted, a.title),
      // Unknown kinds render honestly by title, never invisibly. 未知 kind 按 title 诚实渲,绝不隐身。
      _ => (AnIcons.circle, c.inkFaint, a.title),
    };
    final jumpable = a.messageId.isNotEmpty;
    final base = AnText.label.copyWith(color: a.kind == 'user' ? c.ink : c.inkMuted);
    return AnMenuRow(
      onTap: jumpable ? () => onJump(a) : null,
      builder: (context, active) => Row(children: [
        Icon(icon, size: AnSize.iconSm, color: color),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // User rows carry the emphasis weight — they are the primary anchors. user 行走加粗档(主锚)。
            style: a.kind == 'user' ? base.weight(AnText.emphasisWeight) : base,
          ),
        ),
        const SizedBox(width: AnSpace.s8),
        Text(AnCastRow.timeLabel(context, a.at), style: AnText.meta.copyWith(color: c.inkFaint)),
      ]),
    );
  }
}
