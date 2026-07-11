import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// The ROW family's LEDGER ROW head (WRK-066「同轨」族四) — the ONE run/hit/node line: a left [lead]
/// (status dot / kind glyph — ALWAYS left, 文法 rule), a [primary] (mono id or text), trailing [chips]
/// (chip family), a right-muted [meta] (time / elapsed / count), optional [onTap]. Converges the four
/// hand-rolled layouts (RunLedger rows / FlowrunNodeList rows / web hits / tool-box cards) so every
/// ledger in the app reads identically.
///
/// 行族「台账/命中行」当家件(「同轨」族四)——唯一的运行/命中/节点行:左 lead(状态点/kind 字形,**一律居左**,
/// 文法定案)、primary(mono id 或文本)、尾随 chips(芯片族)、右灰 meta(时刻/耗时/计数)、可点。收敛四套
/// 手搓排布(RunLedger 行/FlowrunNodeList 行/web 命中/工具箱卡),全 App 台账同一张脸。
class AnLedgerRow extends StatelessWidget {
  const AnLedgerRow({
    required this.primary,
    this.lead,
    this.chips = const [],
    this.meta,
    this.mono = true,
    this.onTap,
    super.key,
  });

  /// Left slot: status dot / kind glyph — always LEFT (the census found one-left-one-right drift).
  /// 左槽:状态点/字形——一律居左(普查抓到过一左一右)。
  final Widget? lead;

  final String primary;

  /// Mono primary (ids); false = text primary (titles). 等宽主文(id);false=文本(标题)。
  final bool mono;

  /// Trailing chip-family credentials. 尾随芯片族凭据。
  final List<Widget> chips;

  /// Right-aligned muted metadata (time / elapsed / ×N). 右灰元数据。
  final String? meta;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AnSize.row),
      child: Row(children: [
        if (lead != null) ...[lead!, const SizedBox(width: AnSpace.s6)],
        Flexible(
          child: Text(primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (mono ? AnText.mono : AnText.body).copyWith(color: c.inkMuted)),
        ),
        for (final chip in chips) ...[const SizedBox(width: AnSpace.s6), chip],
        if (meta != null) ...[
          const Spacer(),
          const SizedBox(width: AnSpace.s8),
          Text(meta!, style: AnText.metaTabular().copyWith(color: c.inkFaint)),
        ],
      ]),
    );
    if (onTap == null) return row;
    return AnInteractive(onTap: onTap, builder: (ctx, states) => row);
  }
}
