import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_expand_reveal.dart';
import 'an_interactive.dart';

/// The ROW family's LEDGER ROW head (WRK-066「同轨」族四) — the ONE run/hit/node line: a left [lead]
/// (status dot / kind glyph — ALWAYS left, 文法; seated in a fixed [AnSize.iconSm] cell so primaries
/// align across rows whatever the marker's size), a [primary] (mono id or text), trailing [chips]
/// (chip family), an optional [sub] second line under the primary ([subTone] danger = the error-code
/// voice), a right-muted tabular [measure] (elapsed / duration) and a [meta] whose right edge lands
/// on ONE vertical line across rows (右缘铁线, 拍板 #4 — measure sits just left of it), an optional
/// [expandChild] disclosure body (indented to the primary's left edge — the lead-cell offset lives
/// HERE, not as caller arithmetic). Flex discipline (复审两案后立法): the LEFT CLUSTER is the row's
/// only flex region — primary AND every chip are individually shrinkable, so a narrow host
/// ellipsizes instead of overflowing, and the meta never moves off the right edge.
///
/// 行族台账/命中行当家件:lead 恒左(定宽 iconSm 格,主文跨行对齐)、primary 下可挂 [sub] 副行
/// (subTone danger=错误码声)、右簇 [measure](tabular 耗时)+[meta](右缘铁线,拍板 #4;measure 居其左)、
/// expandChild 披露体(缩进=lead 格宽,由原语自持、非调用方算术)。弹性纪律(两案后立法):左簇是唯一
/// 弹性区——primary 与每枚 chip 都可收缩,窄宿主裁切绝不溢出,meta 恒贴右缘。
class AnLedgerRow extends StatelessWidget {
  const AnLedgerRow({
    required this.primary,
    this.lead,
    this.chips = const [],
    this.sub,
    this.subTone = AnTone.none,
    this.measure,
    this.meta,
    this.mono = true,
    this.onTap,
    this.expandChild,
    this.expanded = false,
    super.key,
  });

  /// Left slot: status dot / kind glyph — always LEFT, seated in a fixed-width cell. 左槽(定宽格)。
  final Widget? lead;

  final String primary;

  /// Mono primary (ids, inkMuted); false = text primary (titles, full ink — the family's existing
  /// title verdict). 等宽主文(id,muted);false=文本标题(全墨,族内既有裁决)。
  final bool mono;

  /// Trailing chip-family credentials — each shrinkable (never overflow the row). 尾随芯片(可缩不溢)。
  final List<Widget> chips;

  /// A second line under the primary (a sub-text / an error code) — left-aligned WITH the primary
  /// (the lead cell offset is structural, never caller arithmetic). 主文下副行(与主文左对齐,
  /// 缩进结构派生非调用方算术)。
  final String? sub;

  /// none = muted meta voice; danger = the error-code voice (mono red). 副行声调。
  final AnTone subTone;

  /// Right-cluster tabular measurement (elapsed / duration), just LEFT of the meta iron line.
  /// 右簇 tabular 计量(耗时),居铁线之左。
  final String? measure;

  /// Right-aligned muted metadata (time / ×N) — flush on the iron line. 右灰元数据(铁线)。
  final String? meta;

  final VoidCallback? onTap;

  /// Disclosure body under the row (codex 族四 signature) — shown when [expanded]. 行下披露体。
  final Widget? expandChild;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subStyle = subTone == AnTone.danger
        ? AnText.code.copyWith(color: c.danger)
        : AnText.meta.copyWith(color: c.inkFaint);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AnSize.row),
      child: Row(crossAxisAlignment: sub == null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        if (lead != null) ...[
          // Fixed lead cell: dots (7) and glyphs (12) mix in one list — a bare lead drifts the
          // primary's left edge row to row. 定宽 lead 格:点/字形混列时主文左缘不漂。
          Padding(
            padding: sub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s8),
            child: SizedBox(width: AnSize.iconSm, child: Center(child: lead!)),
          ),
          const SizedBox(width: AnSpace.s6),
        ],
        // The ONE flex region. Inside it primary and every chip are individually Flexible (loose) —
        // under width pressure each ellipsizes; rigid chips overflowed a 280px host (复审 HIGH #2).
        // 唯一弹性区:primary 与每枚 chip 各自 Flexible(loose)——窄时各自裁切;刚性 chips 曾在 280 宿主溢出。
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: sub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s6),
              child: Row(children: [
                Flexible(
                  child: Text(primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono ? AnText.mono.copyWith(color: c.inkMuted) : AnText.body.copyWith(color: c.ink)),
                ),
                for (final chip in chips) ...[
                  const SizedBox(width: AnSpace.s6),
                  Flexible(child: chip),
                ],
              ]),
            ),
            if (sub != null && sub!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AnSpace.s2, bottom: AnSpace.s4),
                child: Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle),
              ),
          ]),
        ),
        if (measure != null) ...[
          const SizedBox(width: AnSpace.s8),
          Padding(
            padding: sub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s8),
            child: Text(measure!, style: AnText.metaTabular().copyWith(color: c.inkMuted)),
          ),
        ],
        if (meta != null) ...[
          const SizedBox(width: AnSpace.s8),
          Padding(
            padding: sub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s8),
            child: Text(meta!, style: AnText.metaTabular().copyWith(color: c.inkFaint)),
          ),
        ],
      ]),
    );
    final tappable = onTap == null
        ? row
        : AnInteractive(onTap: onTap, expanded: expandChild != null ? expanded : null, builder: (ctx, states) => row);
    if (expandChild == null) return tappable;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      tappable,
      AnExpandReveal(
        open: expanded,
        // The disclosure body indents to the primary's left edge — the lead-cell offset lives in
        // the primitive (its OWN structural constant), never as caller arithmetic (文法 #4 targets
        // feature-layer sums). 披露体缩进到主文左缘——偏移量原语自持,非调用方算术。
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AnSize.iconSm + AnSpace.s6, bottom: AnSpace.s4),
          child: expandChild!,
        ),
      ),
    ]);
  }
}
