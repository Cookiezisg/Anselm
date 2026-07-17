import 'package:flutter/widgets.dart';

import '../../../../core/design/tokens.dart';

/// The IMAGINARY-FRAME law (WRK-070 §A#1) — every block in a sidestage stage logically lives in a frame.
/// A REAL frame (AnWindow / AnCard / AnCodeEditor / AnLayerDiff / a tinted ribbon) fills the body width at
/// X=0 and never indents twice. BARE content (a caption / tombstone / count line) wears an IMAGINARY frame
/// whose inset is the AnKv row's OWN ([kStageFrameInset] = h:s8), so its left edge lands on the SAME line
/// as a sibling KV key. An ICON-led row seats its glyph in a fixed GUTTER cell (icon 沟) so icons align to
/// icons and text to text whatever the glyph's size. Both are derived from existing primitives — zero new
/// magic numbers.
///
/// 假想框律:侧幕舞台每个块逻辑上住在框里。真框(AnWindow/AnCard/AnCodeEditor/AnLayerDiff/着色丝带)占满体宽、
/// 贴 X=0、绝不二次缩进;裸内容(caption/墓碑/计数句)配假想框,内距 = AnKv 行自己的(h:s8),左缘与 KV 键同起点。
/// icon 行把字形坐进定宽沟格,icon 对 icon、文字对文字。全从既有原语派生,零新魔法数。

/// The imaginary frame's horizontal inset — the AnKv row's own [AnSpace.s8], so bare text lands its left
/// edge on the SAME vertical line as a neighbouring KV key. 假想框水平内距(=AnKv 键 h:s8)。
const double kStageFrameInset = AnSpace.s8;

/// Wrap BARE content (a caption / tombstone / honesty line) in the imaginary frame so its left edge aligns
/// with a neighbouring AnKv key (X=8), never顶格 against a full-width real frame. [top]/[bottom] carry any
/// inter-block gap that used to ride a SizedBox / EdgeInsets.only. 假想框:裸内容归框,左缘对齐 KV 键。
Widget stageFramed(Widget child, {double top = 0, double bottom = 0}) => Padding(
      padding: EdgeInsets.fromLTRB(kStageFrameInset, top, kStageFrameInset, bottom),
      child: child,
    );

/// An ICON-GUTTER row («icon 沟文法») — [lead] (an Icon / status dot / any glyph) seated in a fixed
/// [AnSize.iconSm] gutter cell and optically centred (the [AnLedgerRow] lead idiom: an 8px or 12px glyph
/// lands on the SAME centre), an [AnGap.inline] gap, then [child] in the shared text column. A null [lead]
/// leaves the gutter EMPTY so a no-icon line still lands its text on that column. Single-line rows only —
/// [CrossAxisAlignment.center] is the first-line centre, so the glyph sits mid-line with no start-drift
/// (the AnLedgerRow 红点漂移 fix, single-line case); the [child] owns its own maxLines / ellipsis.
///
/// 图标沟行:lead 坐进定宽 iconSm 沟格、光学居中(8/12px 字形同心),AnGap.inline 间距,child 落共享文字列;
/// 无 lead 空沟对齐。仅单行(center=首行中线,字形不漂——红点漂移同款修法);child 自持省略。
Widget stageGutterRow({Widget? lead, required Widget child}) => Row(
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
