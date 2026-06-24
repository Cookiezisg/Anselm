import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/code_diff.dart';
import 'an_code_surface.dart';
import 'syntax_highlighter.dart';

/// E3 — the version-diff primitive (WRK-040 G5.3). A single-frame UNIFIED diff (not side-by-side, not
/// char-level): old→new line-by-line LCS ([lineDiff]), added lines on a soft-green ground, deleted on
/// soft-red, stacked in one frame (GitHub unified style). Inline syntax colour goes through the ONE
/// [highlightCode] tokenizer — a diff NEVER starts a second highlighter (唯一高亮源 铁律); the diff op
/// just tints the row's BASE colour (add→ok / del→danger / context→muted) while the token spans keep
/// their syntax colours over it (the demo's `.dl.add .ct { color: ok }` + `.cd-*` override).
///
/// v1 = a single TEXT field's diff (Function.code / Agent.prompt / Control.when·emit / Approval.template).
/// Structured multi-field diffs (inputs/outputs JSON) + Handler's multi-part versions are deferred to the
/// entities version-view feature (WRK-040 §7). [before] null/'' = the earliest version (no older text to
/// compare) → the whole text renders as context, uncoloured.
///
/// Three columns per row `[line-no | sign | code]`; the line number is the NEW-file logical line (a
/// deleted line gets no number). The body scrolls HORIZONTALLY for long lines; vertically it's
/// content-height (the parent scrolls) or scrolls within a bounded frame — like AnCodeEditor. Frame +
/// white-island chrome reuse [AnCodeSurface] (shared with AnCodeEditor); [bare] drops the frame for an
/// inline diff.
///
/// PERFORMANCE: no virtualization + a per-row [IntrinsicWidth] speculative layout pass (the cost of
/// stretching every row's tinted background to the widest line, demo `.dl min-width:100%`), so — like
/// AnCodeEditor — this targets SHORT single fields; the [lineDiff] degrade gate caps a runaway diff and
/// huge text should be truncated upstream (WRK-040 §9). 无虚拟化 + 逐行 IntrinsicWidth,面向短字段。
///
/// E3——版本 diff 原语。单框 unified diff(非双栏、非字符级):旧→新逐行 LCS,增行软绿底/删行软红底,同框堆叠。
/// 行内着色**只**走唯一 highlightCode(diff 仅染基色 add→ok/del→danger/ctx→muted,token 保留语法色覆盖其上)。
/// v1 仅单字段文本 diff;before 空=最早版本整段 ctx 不染。三列 [行号|符号|代码],行号=新文件逻辑行(删行无号)。
/// 长行横滚、纵向内容高/有界滚(同 AnCodeEditor);框复用 AnCodeSurface;bare 去框。
class AnVersionDiff extends StatelessWidget {
  const AnVersionDiff({
    required this.after,
    this.before,
    this.lang,
    this.range,
    this.note,
    this.bare = false,
    super.key,
  });

  /// The new text (required). 新文本。
  final String after;

  /// The old text; null/'' = earliest version → all-context, uncoloured. 旧文本;空=最早版本整段 ctx。
  final String? before;

  /// Language key for inline highlighting. 行内高亮语言。
  final String? lang;

  /// Version range label, e.g. "v3 → v4" (mono tabular). 版本范围标签。
  final String? range;

  /// A change note (single line, ellipsized). 变更说明。
  final String? note;

  /// Drop the frame + bar (an inline diff). 无框内联。
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final syntax = context.syntax;
    final t = context.t;

    // Build the row list + counts. 构建行 + 计数。
    final rows = <_DiffRow>[];
    var added = 0;
    var removed = 0;
    var ln = 0;
    final b = before;
    if (b == null || b.isEmpty) {
      for (final line in after.split('\n')) {
        rows.add(_DiffRow(DiffOp.context, ++ln, line));
      }
    } else {
      for (final d in lineDiff(b, after)) {
        switch (d.op) {
          case DiffOp.add:
            added++;
            rows.add(_DiffRow(DiffOp.add, ++ln, d.text));
          case DiffOp.del:
            removed++;
            rows.add(_DiffRow(DiffOp.del, null, d.text)); // deleted line → no new-file number 删行无号
          case DiffOp.context:
            rows.add(_DiffRow(DiffOp.context, ++ln, d.text));
        }
      }
    }

    // Gutter width: a SINGLE fixed width for every row (per-row ConstrainedBox-floor would let rows with
    // different digit counts diverge and misalign the sign/code columns). Measured from the largest line
    // number so 5+ digits don't clip, floored at AnSize.trail. 行号列统一固定宽(按最大行号测、floor=trail;逐行 floor 会错位)。
    final gutterW = _gutterWidth(ln);

    final body = LayoutBuilder(
      builder: (ctx, constraints) {
        final minW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        // Horizontal scroll for long lines; rows fill at least the viewport (demo .body overflow-x +
        // .dl min-width:100%). Vertical breathing room (top s8 / bottom s12) sits on the white surface
        // INSIDE IntrinsicWidth + OUTSIDE the rows, so the gap carries no row tint (demo .body padding).
        // 长行横滚;行至少填满视口。纵向呼吸(上 s8/下 s12)在白底上、行 tint 外。
        final scroller = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minW),
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final r in rows) _row(context, c, syntax, t, r, gutterW)],
                ),
              ),
            ),
          ),
        );
        return scroller;
      },
    );

    return Semantics(
      container: true,
      label: t.a11y.diff(added: added, removed: removed),
      child: AnCodeSurface(
        bare: bare,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final column = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!bare) _cap(c, t, added, removed),
                // Content-height when unbounded (parent scrolls); scroll the body when bounded. 无界=内容高;有界=纵滚。
                if (constraints.maxHeight.isFinite)
                  Flexible(child: SingleChildScrollView(child: body))
                else
                  body,
              ],
            );
            // FILL the available width (a diff is a block element, demo .vd display:block). Without
            // this a LOOSE parent (e.g. the gallery's Align(centerLeft)) lets the Column shrink to
            // content width, so the bar's right-pinned +N/−N stops short of the frame edge instead of
            // hugging it. 撑满可用宽:否则 loose 父下缩成内容宽、右锚计数不贴框边。
            return constraints.maxWidth.isFinite
                ? SizedBox(width: constraints.maxWidth, child: column)
                : column;
          },
        ),
      ),
    );
  }

  // Top bar: range (mono tabular) + note (ellipsized) + +N/−N counts. 顶栏:范围 + 说明 + 增删计数。
  Widget _cap(AnColors c, Translations t, int added, int removed) {
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s12, top: AnSpace.s8),
      // ONE flexible filler between the left (range/note) and the right-pinned counts — note fills it
      // (ellipsized) when present, else a Spacer. Two flex children (a Flexible note AND a Spacer) split
      // the slack and leave the counts short of the right edge. 单一弹性填充把计数钉右(两个 flex 子件会分摊、计数到不了右缘)。
      child: Row(
        children: [
          if (range != null) ...[
            Text(range!, style: AnText.value(mono: true).copyWith(color: c.inkMuted)),
            const SizedBox(width: AnSpace.s8),
          ],
          if (note != null)
            Expanded(child: Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)))
          else
            const Spacer(),
          if (added > 0 || removed > 0)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '+$added', style: AnText.value(mono: true).copyWith(color: c.ok)),
                const TextSpan(text: ' '),
                TextSpan(text: '−$removed', style: AnText.value(mono: true).copyWith(color: c.danger)),
              ]),
            ),
        ],
      ),
    );
  }

  // Width for the line-number column — the widest line number measured in the code style, floored at
  // AnSize.trail (so it can't clip a 5+ digit number, and stays uniform across rows). 行号列宽(测最大号、floor trail)。
  double _gutterWidth(int maxLn) {
    final tp = TextPainter(
      text: TextSpan(text: '$maxLn', style: AnText.code),
      textDirection: TextDirection.ltr,
    )..layout();
    // INCLUDE the left s12 + right s8 inset in the column width, so the gutter matches AnCodeEditor's
    // (whose `ConstrainedBox(minWidth: trail)` wraps a `Padding(left s12, right s8)` — the trail floor
    // is the WHOLE column incl padding). Otherwise the number sits a cell too far right. 含左 s12+右 s8,与 AnCodeEditor 一致。
    return math.max(AnSize.trail, AnSpace.s12 + tp.width + AnSpace.s8);
  }

  Widget _row(BuildContext context, AnColors c, SyntaxColors syntax, Translations t, _DiffRow r, double gutterW) {
    final Color? bg;
    final Color base;
    final String sign;
    final String? a11yPrefix;
    switch (r.op) {
      case DiffOp.add:
        bg = c.okSoft;
        base = c.ok;
        sign = '+';
        a11yPrefix = t.diff.added;
      case DiffOp.del:
        bg = c.dangerSoft;
        base = c.danger;
        sign = '−'; // minus sign (not hyphen) 减号
        a11yPrefix = t.diff.removed;
      case DiffOp.context:
        bg = null;
        base = c.inkMuted;
        sign = ' ';
        a11yPrefix = null;
    }
    final row = Container(
      color: bg,
      // Only a RIGHT inset here — the left inset lives INSIDE the gutter column (left s12) so the line
      // number lands at the same x as AnCodeEditor's gutter (no extra leading cell). 仅右内距;左内距在行号列内。
      padding: const EdgeInsets.only(right: AnSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // line number (new-file logical; blank for deleted), right-aligned, uniform column width;
          // left s12 + right s8 inset matches AnCodeEditor's gutter. 行号(删行空、统一列宽、内距同 AnCodeEditor)。
          SizedBox(
            width: gutterW,
            child: Padding(
              padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s8),
              child: Text(r.lineNo?.toString() ?? '', textAlign: TextAlign.right, style: AnText.code.copyWith(color: c.inkFaint)),
            ),
          ),
          // sign 符号
          SizedBox(
            width: AnSize.iconLg,
            child: Text(sign, textAlign: TextAlign.center, style: AnText.code.copyWith(color: base)),
          ),
          // code — base colour tinted by the op; token spans keep their syntax colours over it. 代码(基色染、token 覆盖)。
          Text.rich(
            TextSpan(style: AnText.code.copyWith(color: base), children: highlightCode(r.text, lang: lang, colors: syntax)),
            softWrap: false,
            maxLines: 1,
          ),
        ],
      ),
    );
    // Row-level a11y merge: one node per line ("Added: <code>"), the number + sign are decorative. 行级 merge。
    return Semantics(
      label: a11yPrefix == null ? r.text : '$a11yPrefix: ${r.text}',
      excludeSemantics: true,
      child: row,
    );
  }
}

class _DiffRow {
  const _DiffRow(this.op, this.lineNo, this.text);
  final DiffOp op;
  final int? lineNo; // new-file line number; null for a deleted line 新文件行号(删行 null)
  final String text;
}
