import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/code_diff.dart';
import 'an_button.dart';
import 'an_code_surface.dart';
import 'an_term_viewport.dart';
import 'an_tooltip.dart';
import 'icons.dart';
import 'syntax_highlighter.dart';
import 'text_measure.dart';

/// E3 — the version-diff primitive (WRK-040 G5.3 · WRK-066 拍板修订). A single-frame UNIFIED diff (not
/// side-by-side, not char-level): old→new line-by-line LCS ([lineDiff]), added lines on a soft-green
/// ground, deleted on soft-red, stacked in one frame (GitHub unified style). Inline syntax colour goes
/// through the ONE [highlightCode] tokenizer — a diff NEVER starts a second highlighter (唯一高亮源 铁律).
///
/// THE BAR IS ISOMORPHIC WITH [AnCodeEditor]'s (WRK-066 拍板 #3): left = copy (copies [after]) + wrap
/// toggle, right-pinned = **+N −N** counts (a diff shows counts where the editor shows the language
/// label). The LIVE face (拍板: two-act surgery) renders − [before] then + [after] as tinted tail
/// segments inside the SAME shell with the SAME bar — a settled unified diff mid-stream would lie (an
/// in-flight replace reads as a pure deletion). live→settled swaps the face, never the shell.
///
/// v1 = a single TEXT field's diff. [before] null/'' = the earliest version → all-context, uncoloured.
/// Three columns per row `[line-no | sign | code]`. Long lines scroll horizontally (or soft-wrap when
/// the bar's wrap is on). Frame + white-island chrome reuse [AnCodeSurface]; [bare] drops the frame.
///
/// PERFORMANCE: no virtualization + per-row [IntrinsicWidth] — targets SHORT single fields (WRK-040 §9).
///
/// E3——版本 diff 原语(WRK-066 拍板修订)。单框 unified diff;行内着色只走唯一 highlightCode。**bar 与
/// AnCodeEditor 同构**(拍板 #3):左 copy(复制 after)+wrap,右钉 +N −N(diff 显计数,编辑器显语言标)。
/// live 脸=两幕手术(− before 尾段 → + after 尾段,同壳同 bar)——半途渲落定 diff 会撒谎。换脸不换壳。
class AnVersionDiff extends StatefulWidget {
  const AnVersionDiff({
    required this.after,
    this.before,
    this.lang,
    this.range,
    this.note,
    this.bare = false,
    this.reading = false,
    this.live = false,
    this.maxHeight,
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

  /// CONTENT-tier rows (mono 13/1.6, [AnText.codeReading]) — the entity version tab's diff, read
  /// inside the 15 content page. Machine windows (the Edit tool card) keep [AnText.code] 12.
  /// 内容档行(13/1.6):实体版本 tab 的 diff;机器窗(Edit tool 卡)守 12。
  final bool reading;

  /// LIVE two-act face (WRK-066 拍板 · 统一向落定对齐): while args stream, the rows render EXACTLY like
  /// the settled unified diff (same gutter/sign/code columns, row style, paddings, bar, scroll/wrap) —
  /// only the ROW ORDER differs: all − [before] lines, then all + [after] lines (no LCS mid-stream —
  /// diffing half-arrived text would lie). live→settled changes nothing but the interleaving.
  /// 活两幕脸(拍板·统一向落定对齐):行渲染与落定 unified 完全同构(同行号/符号/代码三列、同行高内距、
  /// 同 bar、同滚动/wrap),仅行序不同——先全部 −旧、再全部 +新(流中不做 LCS,半截文本上 diff 会撒谎)。
  final bool live;

  /// Bounded viewport for BOTH faces (an [AnSize] tier) — the code family's zero-jump contract:
  /// transcript consumers pass the SAME tier live+settled. live defaults to [AnSize.codeViewport]
  /// (a transcript row never owns an unbounded wall — 复审 #6). 双脸同钳;live 兜底 codeViewport。
  final double? maxHeight;

  @override
  State<AnVersionDiff> createState() => _AnVersionDiffState();
}

class _AnVersionDiffState extends State<AnVersionDiff> {
  bool _wrap = false;
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _copyTimer;

  TextStyle get _rowStyle => widget.reading ? AnText.codeReading : AnText.code;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    // The COPY payload is the NEW text — what lands after the change applies. 复制载荷=after(改后全文)。
    Clipboard.setData(ClipboardData(text: widget.after)).then((_) {
      if (!mounted) return;
      setState(() {
        _copied = true;
        _copyFailed = false;
      });
      _resetCopy();
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _copyFailed = true;
        _copied = false;
      });
      _resetCopy();
    });
  }

  void _resetCopy() {
    _copyTimer?.cancel();
    _copyTimer = Timer(AnMotion.dwell, () {
      if (mounted) {
        setState(() {
          _copied = false;
          _copyFailed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final syntax = context.syntax;
    final t = context.t;

    final (:rows, :added, :removed, :lastLn) = _assembleRows();
    // Live empty guard (复审 #29): nothing streamed yet → no bar-only empty shell. 空流不渲空壳。
    if (widget.live && rows.isEmpty) return const SizedBox.shrink();

    // Gutter width: a SINGLE fixed width for every row (per-row ConstrainedBox-floor would let rows with
    // different digit counts diverge and misalign the sign/code columns). Measured from the largest line
    // number so 5+ digits don't clip, floored at AnSize.trail. 行号列统一固定宽。
    final gutterW = _gutterWidth(context, lastLn);

    final rowsColumn = Padding(
      padding: const EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final r in rows) _row(context, c, syntax, t, r, gutterW)],
      ),
    );

    final body = _wrap
        // Wrap mode: rows soft-wrap, no horizontal scroller (the bar's wrap toggle, editor-isomorphic).
        // wrap 模式:行软折、去横滚(bar 的 wrap 钮,与编辑器同构)。
        ? rowsColumn
        : LayoutBuilder(
            builder: (ctx, constraints) {
              final minW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
              // Horizontal scroll for long lines; rows fill at least the viewport. 长行横滚;行至少填满视口。
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minW),
                  child: IntrinsicWidth(child: rowsColumn),
                ),
              );
            },
          );

    final framed = Semantics(
      container: true,
      label: t.a11y.diff(added: added, removed: removed),
      child: AnCodeSurface(
        bare: widget.bare,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final column = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.bare) _bar(context, c, t, added, removed),
                // LIVE: the bounded stick-to-bottom viewport (the code family's one law — the newest
                // + line stays visible while streaming, 复审 #6; white-face fades per 拍板 #1).
                // SETTLED: content-height when unbounded, scroll when bounded.
                // live=有界贴底视口(最新 + 行流入期恒可见;白面渐隐);settled=无界内容高/有界纵滚。
                if (widget.live)
                  AnStickViewport(
                      maxHeight: widget.maxHeight ?? AnSize.codeViewport,
                      fadeColor: c.surface,
                      child: body)
                // The settled zero-jump clamp sits on the BODY — mirroring the live viewport position
                // (bar OUTSIDE the clamp) so the settle only un-pins and the total height is identical
                // across faces (批2 复审: the whole-frame clamp made settle 32px shorter). In a bounded
                // host the Flexible keeps the crop silent-safe. 落定钳在 body(与 live 视口同位,bar 在
                // 钳外):两脸总高全等(批2 复审:整框钳曾令落定矮 32px);有界宿主经 Flexible 静默安全。
                else if (constraints.maxHeight.isFinite)
                  Flexible(
                      child: widget.maxHeight == null
                          ? SingleChildScrollView(child: body)
                          : ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                              child: SingleChildScrollView(child: body)))
                else if (widget.maxHeight != null)
                  ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                      child: SingleChildScrollView(child: body))
                else
                  body,
              ],
            );
            // FILL the available width — else a loose parent lets the right-pinned counts stop short of
            // the frame edge. 撑满可用宽,右锚计数贴框边。
            return constraints.maxWidth.isFinite
                ? SizedBox(width: constraints.maxWidth, child: column)
                : column;
          },
        ),
      ),
    );
    return framed;
  }

  // Assemble the diff rows + add/remove counts. SETTLED = line-by-line LCS ([lineDiff]). LIVE = the
  // two-act order — every − [before] line then every + [after] line, NO LCS (diffing half-arrived
  // text lies); the rows then flow through the ONE render path, so live and settled share every
  // metric. Kept out of build() so build reads as pure layout.
  // 装配 diff 行+增删计数。落定=逐行 LCS;live=两幕序(先全部 −旧再全部 +新,不做 LCS——半截文本 diff
  // 会撒谎),行走同一条渲染路径,live/落定全度量共享。移出 build 使其纯布局。
  ({List<_DiffRow> rows, int added, int removed, int lastLn}) _assembleRows() {
    final rows = <_DiffRow>[];
    var added = 0;
    var removed = 0;
    var ln = 0;
    final b = widget.before;
    if (widget.live) {
      if (b != null && b.isNotEmpty) {
        for (final line in b.split('\n')) {
          removed++;
          rows.add(_DiffRow(DiffOp.del, null, line));
        }
      }
      if (widget.after.isNotEmpty) {
        for (final line in widget.after.split('\n')) {
          added++;
          rows.add(_DiffRow(DiffOp.add, ++ln, line));
        }
      }
      return (rows: rows, added: added, removed: removed, lastLn: ln);
    }
    if (b == null || b.isEmpty) {
      for (final line in widget.after.split('\n')) {
        rows.add(_DiffRow(DiffOp.context, ++ln, line));
      }
    } else {
      for (final d in lineDiff(b, widget.after)) {
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
    return (rows: rows, added: added, removed: removed, lastLn: ln);
  }

  // The bar — ISOMORPHIC with AnCodeEditor's (WRK-066 拍板 #3): left copy + wrap (+ range/note), a
  // single flexible filler, right-pinned +N −N (the diff's «language label» slot shows counts).
  // 顶栏与编辑器同构:左 copy+wrap(+范围/说明),单一弹性填充,右钉 +N −N(diff 的「语言标」槽=计数)。
  Widget _bar(BuildContext context, AnColors c, Translations t, int added, int removed) {
    final copyTip = _copied ? t.feedback.copied : (_copyFailed ? t.feedback.copyFailed : t.action.copy);
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s12, top: AnSpace.s8),
      child: Row(
        children: [
          AnTooltip(
            message: copyTip,
            child: AnButton.iconOnly(_copied ? AnIcons.check : AnIcons.copy,
                size: AnButtonSize.sm, semanticLabel: copyTip, onPressed: _copy),
          ),
          const SizedBox(width: AnSpace.s4),
          AnTooltip(
            message: t.action.wrap,
            child: AnButton.iconOnly(AnIcons.wrap,
                size: AnButtonSize.sm, semanticLabel: t.action.wrap, onPressed: () => setState(() => _wrap = !_wrap)),
          ),
          if (widget.range != null) ...[
            const SizedBox(width: AnSpace.s8),
            Text(widget.range!, style: AnText.value(mono: true).copyWith(color: c.inkMuted)),
          ],
          const SizedBox(width: AnSpace.s8),
          // ONE flexible filler between the left cluster and the right-pinned counts. 单一弹性填充钉右。
          if (widget.note != null)
            Expanded(
                child: Text(widget.note!,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)))
          else
            const Spacer(),
          if (added > 0 || removed > 0)
            // The container a11y label already speaks the counts — don't read them twice (复审 #49).
            // 容器 a11y 已念计数,不念两遍。
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '+$added', style: AnText.value(mono: true).copyWith(color: c.ok)),
                  const TextSpan(text: ' '),
                  TextSpan(text: '−$removed', style: AnText.value(mono: true).copyWith(color: c.danger)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // Width for the line-number column — the widest line number measured in the ACTIVE row style AND the
  // ambient textScaler, floored at AnSize.trail. 行号列宽(按活动行样式+textScaler 量,floor=trail)。
  double _gutterWidth(BuildContext context, int maxLn) {
    final w = measureText(
      TextSpan(text: '$maxLn', style: _rowStyle),
      textScaler: MediaQuery.textScalerOf(context),
      read: (tp) => tp.width,
    );
    // INCLUDE the left s12 + right s8 inset so the gutter matches AnCodeEditor's. 含内距,与编辑器一致。
    return math.max(AnSize.trail, AnSpace.s12 + w + AnSpace.s8);
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
      // number lands at the same x as AnCodeEditor's gutter. 仅右内距;左内距在行号列内。
      padding: const EdgeInsets.only(right: AnSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // line number (new-file logical; blank for deleted), right-aligned, uniform column width.
          // 行号(删行空、统一列宽、内距同 AnCodeEditor)。
          SizedBox(
            width: gutterW,
            child: Padding(
              padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s8),
              child: Text(r.lineNo?.toString() ?? '', textAlign: TextAlign.right, style: _rowStyle.copyWith(color: c.inkFaint)),
            ),
          ),
          // sign 符号
          SizedBox(
            width: AnSize.iconLg,
            child: Text(sign, textAlign: TextAlign.center, style: _rowStyle.copyWith(color: base)),
          ),
          // code — base colour tinted by the op; token spans keep their syntax colours over it. In wrap
          // mode the code cell flexes and soft-wraps. 代码(基色染、token 覆盖);wrap 模式弹性软折。
          if (_wrap)
            Expanded(
              child: Text.rich(
                TextSpan(style: _rowStyle.copyWith(color: base), children: highlightCode(r.text, lang: widget.lang, colors: syntax)),
              ),
            )
          else
            Text.rich(
              TextSpan(style: _rowStyle.copyWith(color: base), children: highlightCode(r.text, lang: widget.lang, colors: syntax)),
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
