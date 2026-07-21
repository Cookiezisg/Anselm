import 'package:flutter/widgets.dart';

import '../../../../core/design/tokens.dart';

/// The IMAGINARY-FRAME law (WRK-070 §A#1) — every block in a sidestage stage logically lives in a frame.
/// A REAL frame (AnWindow / AnCard / AnCodeEditor / AnLayerDiff / a tinted ribbon) fills the body width at
/// X=0 and never indents twice. BARE content (a caption / tombstone / count line) wears an IMAGINARY frame
/// whose inset is the AnKv row's OWN ([kStageFrameInset] = h:s8), so its left edge lands on the SAME line
/// as a sibling KV key. An ICON-led row seats its glyph in a fixed GUTTER cell (icon 沟) that ITSELF lives in
/// the imaginary frame (the cell starts at X=8, not顶格 against the island edge) so icons align to icons and
/// text to text whatever the glyph's size, all on the X=8 frame line. Both are derived from existing
/// primitives — zero new magic numbers.
///
/// 假想框律:侧幕舞台每个块逻辑上住在框里。真框(AnWindow/AnCard/AnCodeEditor/AnLayerDiff/着色丝带)占满体宽、
/// 贴 X=0、绝不二次缩进;裸内容(caption/墓碑/计数句/chips/梯)配假想框,内距 = AnKv 行自己的(h:s8),左缘与
/// KV 键同起点(X=8)。icon 行把字形坐进定宽沟格、沟格自己也住在假想框(从 X=8 起),icon 对 icon、文字对
/// 文字、全落 X=8 框线。全从既有原语派生,零新魔法数。

/// The imaginary frame's horizontal inset — the AnKv row's own [AnSpace.s8], so bare text lands its left
/// edge on the SAME vertical line as a neighbouring KV key. 假想框水平内距(=AnKv 键 h:s8)。
const double kStageFrameInset = AnSpace.s8;

/// Wrap BARE content (a caption / tombstone / honesty line) in the imaginary frame so its left edge aligns
/// with a neighbouring AnKv key (X=8), never顶格 against a full-width real frame. [top]/[bottom] carry any
/// inter-block gap that used to ride a SizedBox / EdgeInsets.only. 假想框:裸内容归框,左缘对齐 KV 键。
Widget stageFramed(Widget child, {double top = 0, double bottom = 0}) =>
    Padding(
      padding: EdgeInsets.fromLTRB(
        kStageFrameInset,
        top,
        kStageFrameInset,
        bottom,
      ),
      child: child,
    );

/// An ICON-GUTTER row («icon 沟文法») — [lead] (an Icon / status dot / any glyph) seated in a fixed
/// [AnSize.iconSm] gutter cell and optically centred (the [AnLedgerRow] lead idiom: an 8px or 12px glyph
/// lands on the SAME centre), an [AnGap.inline] gap, then [child] in the shared text column. A null [lead]
/// leaves the gutter EMPTY so a no-icon line still lands its text on that column. Single-line rows only —
/// [CrossAxisAlignment.center] is the first-line centre, so the glyph sits mid-line with no start-drift
/// (the AnLedgerRow 红点漂移 fix, single-line case); the [child] owns its own maxLines / ellipsis.
///
/// The GUTTER ITSELF lives in the imaginary frame: when [framed] (the default, for a BODY-level row) the
/// row wears the [kStageFrameInset] leading inset, so the icon cell starts at X=8 — the icon no longer顶格
/// against the island edge, and its text column lands on the SAME X=8 frame line as [stageFramed] bare text
/// and the AnKv key. A row already INSIDE a real frame (e.g. the subagent card's [AnWindow] body, which
/// carries its own content inset) passes [framed]:false so the gutter is NOT double-indented past the card's
/// own header glyph. Leading-only (not [stageFramed]'s symmetric inset) so the [child]'s ellipsising text
/// keeps the full width to the body's right edge.
///
/// 图标沟行:lead 坐进定宽 iconSm 沟格、光学居中(8/12px 字形同心),AnGap.inline 间距,child 落共享文字列;
/// 无 lead 空沟对齐。仅单行(center=首行中线,字形不漂——红点漂移同款修法);child 自持省略。
/// **沟住进假想框**:framed(默认,body 级行)时行带 kStageFrameInset 前导内距——沟格从 X=8 起(不再顶格贴
/// 岛缘),文字列落与 stageFramed 裸文字、AnKv 键同一条 X=8 框线。已在真框内的行(如 subagent 卡 AnWindow
/// 体、自带内距)传 framed:false 免二次缩进越过卡头字形。只前导(非 stageFramed 对称内距)——child 省略文字保右缘满宽。
Widget stageGutterRow({
  Widget? lead,
  required Widget child,
  bool framed = true,
}) {
  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: AnSize.iconSm,
        child: lead == null ? null : Center(child: lead),
      ),
      const SizedBox(width: AnGap.inline),
      Expanded(child: child),
    ],
  );
  return framed
      ? Padding(
          padding: const EdgeInsets.only(left: kStageFrameInset),
          child: row,
        )
      : row;
}
