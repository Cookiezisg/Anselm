import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_expand_reveal.dart';
import 'an_interactive.dart';

/// The ROW family's LEDGER ROW head (WRK-066「同轨」族四) — the ONE run/hit/node line: a left [lead]
/// (status dot / kind glyph — ALWAYS left, 文法), a [primary] (mono id or text), trailing [chips]
/// (chip family), a right-muted [meta] whose right edge lands on ONE vertical line across rows
/// (右缘铁线, 拍板 #4), an optional [expandChild] disclosure body. Flex discipline (复审两案后立法):
/// the LEFT CLUSTER is the row's only flex region — primary AND every chip are individually
/// shrinkable, so a narrow host ellipsizes instead of overflowing, and the meta never moves off
/// the right edge. 行族台账/命中行当家件:lead 恒左、meta 右缘铁线、expandChild 披露体。弹性纪律
/// (两案后立法):左簇是唯一弹性区——primary 与每枚 chip 都可收缩,窄宿主裁切绝不溢出,meta 恒贴右缘。
class AnLedgerRow extends StatelessWidget {
  const AnLedgerRow({
    required this.primary,
    this.lead,
    this.chips = const [],
    this.meta,
    this.mono = true,
    this.onTap,
    this.expandChild,
    this.expanded = false,
    super.key,
  });

  /// Left slot: status dot / kind glyph — always LEFT. 左槽(状态点/字形,一律居左)。
  final Widget? lead;

  final String primary;

  /// Mono primary (ids); false = text primary (titles). 等宽主文(id);false=文本(标题)。
  final bool mono;

  /// Trailing chip-family credentials — each shrinkable (never overflow the row). 尾随芯片(可缩不溢)。
  final List<Widget> chips;

  /// Right-aligned muted metadata (time / elapsed / ×N) — flush on the iron line. 右灰元数据(铁线)。
  final String? meta;

  final VoidCallback? onTap;

  /// Disclosure body under the row (codex 族四 signature) — shown when [expanded]. 行下披露体。
  final Widget? expandChild;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AnSize.row),
      child: Row(children: [
        if (lead != null) ...[lead!, const SizedBox(width: AnSpace.s6)],
        // The ONE flex region. Inside it primary and every chip are individually Flexible (loose) —
        // under width pressure each ellipsizes; rigid chips overflowed a 280px host (复审 HIGH #2).
        // 唯一弹性区:primary 与每枚 chip 各自 Flexible(loose)——窄时各自裁切;刚性 chips 曾在 280 宿主溢出。
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (mono ? AnText.mono : AnText.body).copyWith(color: c.inkMuted)),
            ),
            for (final chip in chips) ...[
              const SizedBox(width: AnSpace.s6),
              Flexible(child: chip),
            ],
          ]),
        ),
        if (meta != null) ...[
          const SizedBox(width: AnSpace.s8),
          Text(meta!, style: AnText.metaTabular().copyWith(color: c.inkFaint)),
        ],
      ]),
    );
    final tappable = onTap == null
        ? row
        : AnInteractive(onTap: onTap, expanded: expandChild != null ? expanded : null, builder: (ctx, states) => row);
    if (expandChild == null) return tappable;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      tappable,
      AnExpandReveal(open: expanded, child: expandChild!),
    ]);
  }
}
