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
    this.expandBuilder,
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

  /// Lazy disclosure body — built ONLY while open ([AnExpandReveal.builder], C-006). Prefer this
  /// over [expandChild] when the body fetches or is expensive; the two are mutually exclusive by
  /// convention (builder wins). 惰性披露体——仅展开时建(C-006);体要取数/昂贵时用它,builder 优先。
  final WidgetBuilder? expandBuilder;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // ONE sub truth for geometry AND rendering (批6 复审): wire subs arrive with leading '\n'
    // (LLM finalText, backend errors) — untrimmed they paint an empty first line under maxLines:1,
    // and a whitespace-only sub must not switch the row to two-line geometry with a ghost lane.
    // 副行单一真相:线缆 sub 常带首换行——不 trim 则唯一渲染行全空白;纯空白 sub 也绝不能把行切成
    // 双行几何留幽灵道。几何与渲染同源判据。
    final effectiveSub = (sub == null || sub!.trim().isEmpty) ? null : sub!.trim();
    final subStyle = subTone == AnTone.danger
        ? AnText.code.copyWith(color: c.danger)
        : AnText.meta.copyWith(color: c.inkFaint);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AnSize.row),
      // Contents inset s8 from BOTH edges (WRK-070 0718 用户裁「点点/时长要跟着标准的有框间距走」):
      // the row lives in a (hover-visible) phantom frame, so lead dot and right measure retreat from
      // its edges — the same s8 grammar as AnKv's phantom box. 行住假想框:两侧内容各退 s8(同 AnKv)。
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        child: Row(
          crossAxisAlignment: effectiveSub == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
        if (lead != null) ...[
          // Fixed lead cell: dots (7) and glyphs (12) mix in one list — a bare lead drifts the
          // primary's left edge row to row. On a two-line row the cell takes the primary's OWN top
          // pad (s6) and a first-row-height box so the dot centres on the FIRST line — the old s8
          // pad hung the dot above the text (用户 0717 报的红点漂移 bug).
          // 定宽 lead 格:点/字形混列时主文左缘不漂。双行行里 lead 用主文自己的顶距(s6)+首行高盒,
          // 点与**首行**同心——旧 s8 顶距把点吊在文字上方(用户报的红点漂移 bug)。
          Padding(
            padding: effectiveSub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s6),
            child: SizedBox(
              width: AnSize.iconSm,
              height: effectiveSub == null ? null : AnSize.controlSm,
              child: Center(child: lead!),
            ),
          ),
          const SizedBox(width: AnSpace.s6),
        ],
        // The ONE flex region. Inside it primary and every chip are individually Flexible (loose) —
        // under width pressure each ellipsizes; rigid chips overflowed a 280px host (复审 HIGH #2).
        // 唯一弹性区:primary 与每枚 chip 各自 Flexible(loose)——窄时各自裁切;刚性 chips 曾在 280 宿主溢出。
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: effectiveSub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s6),
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
            if (effectiveSub != null)
              Padding(
                padding: const EdgeInsets.only(top: AnSpace.s2, bottom: AnSpace.s4),
                child: Text(effectiveSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle),
              ),
          ]),
        ),
        if (measure != null) ...[
          const SizedBox(width: AnSpace.s8),
          Padding(
            padding: effectiveSub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s8),
            child: Text(measure!, style: AnText.metaTabular().copyWith(color: c.inkMuted)),
          ),
        ],
        if (meta != null) ...[
          const SizedBox(width: AnSpace.s8),
          Padding(
            padding: effectiveSub == null ? EdgeInsets.zero : const EdgeInsets.only(top: AnSpace.s8),
            child: Text(meta!, style: AnText.metaTabular().copyWith(color: c.inkFaint)),
          ),
        ],
      ]),
      ),
    );
    final disclosing = expandChild != null || expandBuilder != null;
    final tappable = onTap == null
        ? row
        // A tappable row SHOWS its hand on hover (WRK-070 B4 用户裁「列表太干,没有可互动的理解」——
        // 左岛行同款浅灰): the wash is the affordance, family-wide for every tappable ledger row.
        // 可点行 hover 浅灰示能(左岛同款)——族级:凡可点的台账行都亮。
        : AnInteractive(
            onTap: onTap,
            expanded: disclosing ? expanded : null,
            builder: (ctx, states) => DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceHover.whenActive(states.isActive),
                borderRadius: BorderRadius.circular(AnRadius.button),
              ),
              child: row,
            ),
          );
    if (!disclosing) return tappable;
    // The disclosure body insets EQUALLY from both edges (WRK-070 0718 用户裁「左边有退右边没退——
    // 两边都按假想边框退同样的距离」): the body lives in the same phantom frame as the row, so both
    // sides take the frame inset (s8); the old left-only lead-gutter indent read lopsided. The
    // offset lives in the primitive (never caller arithmetic, 文法 #4).
    // 披露体两侧等退:与行同住假想框,两侧同取框内距 s8;旧的仅左 lead 沟缩进读作偏斜。偏移原语自持。
    const indent = EdgeInsetsDirectional.only(
        start: AnSpace.s8, end: AnSpace.s8, bottom: AnSpace.s4);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      tappable,
      // expandBuilder rides the LAZY reveal (C-006): a collapsed row never builds its body — a run
      // list where every row carried an eagerly-built dossier card would fetch for rows nobody
      // opened. expandBuilder 走惰性揭示(C-006):收起的行绝不建体——每行都急建卷宗卡的 run 列表会替
      // 没人点开的行取数。
      if (expandBuilder != null)
        AnExpandReveal.builder(
          open: expanded,
          childBuilder: (ctx) => Padding(padding: indent, child: expandBuilder!(ctx)),
        )
      else
        AnExpandReveal(
          open: expanded,
          child: Padding(padding: indent, child: expandChild!),
        ),
    ]);
  }
}
