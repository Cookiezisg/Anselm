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
import 'an_interactive.dart';
import 'an_term_viewport.dart';
import 'icons.dart';
import 'syntax_highlighter.dart';
import 'text_measure.dart';

/// E3 — the version-diff primitive (WRK-040 G5.3 · WRK-066 拍板修订 · WRK-077 VT). A single-frame UNIFIED
/// diff (not side-by-side, not char-level): old→new line-by-line LCS ([lineDiff]), added lines on a
/// soft-green ground, deleted on soft-red, stacked in one frame (GitHub unified style). Inline syntax
/// colour goes through the ONE [highlightCode] tokenizer — a diff NEVER starts a second highlighter
/// (唯一高亮源 铁律).
///
/// THE BAR IS ISOMORPHIC WITH [AnCodeEditor]'s (WRK-066 拍板 #3): left = copy (copies [after]) + wrap
/// toggle, right-pinned = **+N −N** counts (a diff shows counts where the editor shows the language
/// label). The LIVE face (拍板: two-act surgery) renders − [before] then + [after] as tinted tail
/// segments inside the SAME shell with the SAME bar — a settled unified diff mid-stream would lie (an
/// in-flight replace reads as a pure deletion). live→settled swaps the face, never the shell.
///
/// v1 = a single TEXT field's diff. [before] null/'' = the earliest version → all-context, uncoloured.
/// Three columns per row `[line-no | sign | code]`. Long lines scroll horizontally (or soft-wrap when
/// the bar's wrap is on — [wrap] seeds it). Frame + white-island chrome reuse [AnCodeSurface]; [bare]
/// drops the frame.
///
/// HUNK MODE ([hunks], WRK-077 VT): unchanged stretches beyond [diffContextLines] fold into ONE tappable
/// «… N unchanged lines» marker ([unchangedGaps]) — the reader sees the CHANGES, not the file. Each gap
/// reveals on tap; [onHunksChanged] (when wired) puts the whole-file escape under the rows, so the mode
/// is the CALLER's state and a second entrance (a row ⋯ menu) can drive the same truth.
///
/// PERFORMANCE (WRK-077 VT — the old «no virtualization + per-row IntrinsicWidth, targets SHORT fields»
/// ceiling is gone): rows are SLIVERS, so a bounded host builds + [highlightCode]s only the VISIBLE
/// window ([SliverFixedExtentList] at one measured line height when every row is one line;
/// [SliverList] under wrap, where a wrapped row's height is genuinely unknown). Content-height hosts
/// still lay out every row (`shrinkWrap` — no viewport, no laziness possible) but that is now the
/// SMALL case: hunk mode keeps it small. The horizontal extent is ONE measurement — mono advance ×
/// longest line — instead of the per-row [IntrinsicWidth] double layout, and the LCS itself is memoized
/// so a wrap flip / gap reveal never re-diffs.
///
/// E3——版本 diff 原语(WRK-066 拍板修订 · WRK-077 VT)。单框 unified diff;行内着色只走唯一 highlightCode。
/// **bar 与 AnCodeEditor 同构**(拍板 #3):左 copy(复制 after)+wrap,右钉 +N −N。live 脸=两幕手术(− before
/// 尾段 → + after 尾段,同壳同 bar);换脸不换壳。**hunk 模式**(VT):未变更长段折成一条可点「省略 N 行」,
/// 上下文 3 行;整份逃生口在行下(受控于调用方,故 ⋯ 菜单可作第二入口)。**性能**:行改 sliver(有界宿主只建
/// 只高亮可见窗;非 wrap 用等高档 SliverFixedExtentList、wrap 用 SliverList),横向宽=等宽字符宽×最长行**一次
/// 量出**(逐行 IntrinsicWidth 已删),LCS 记忆化(翻 wrap/展 gap 不重跑 diff)。
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
    this.wrap = false,
    this.hunks = false,
    this.onHunksChanged,
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

  /// INITIAL soft-wrap state (the bar's wrap toggle owns it from then on) — 1:1 [AnCodeEditor.wrap].
  /// A FULL-WIDTH reading host (the entity version tab) seeds it TRUE: full width only pays off if the
  /// long lines are actually readable to their end, and a diff row can't be re-flowed by the reader.
  /// 初始软换行(其后归 bar 的 wrap 钮),与 AnCodeEditor.wrap 同构;全宽阅读宿主(实体版本 tab)默认开——
  /// 全宽的意义正是把长行读完。
  final bool wrap;

  /// HUNK mode: fold unchanged stretches beyond [diffContextLines] into tappable gap markers. Ignored
  /// on the [live] face (a streaming two-act body has no hunks to compute) and inert when the diff has
  /// no changes at all (the earliest version renders whole — see [unchangedGaps]).
  /// hunk 模式:未变更长段折成可点标记(上下文 3 行);live 脸忽略;全无变更时不折(最早版本整段渲)。
  final bool hunks;

  /// The whole-file escape under the rows — a CONTROLLED hand for [hunks]. Non-null wires the
  /// «show all (N lines)» / «only changes» toggle row and hands the new value back, so the mode lives
  /// in the CALLER's state and a second entrance (the version row's ⋯ menu) drives the SAME truth.
  /// Null = no toggle row (a consumer that never leaves its chosen mode).
  /// 整份逃生口(hunks 的受控手):非空即渲「展开全部/只显变更」切换行并回调,模式归调用方状态,故第二入口
  /// (版本行 ⋯ 菜单)与它同一真相;为空则不渲切换行。
  final ValueChanged<bool>? onHunksChanged;

  /// Bounded viewport for BOTH faces (an [AnSize] tier) — the code family's zero-jump contract:
  /// transcript consumers pass the SAME tier live+settled. live defaults to [AnSize.codeViewport]
  /// (a transcript row never owns an unbounded wall — 复审 #6). A bound is ALSO what makes the row
  /// slivers lazy: without one there is no viewport to be lazy inside. 双脸同钳;live 兜底 codeViewport;
  /// 有钳才有视口、才有惰性。
  final double? maxHeight;

  @override
  State<AnVersionDiff> createState() => _AnVersionDiffState();
}

class _AnVersionDiffState extends State<AnVersionDiff> {
  late bool _wrap;
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _copyTimer;

  /// Gap starts the reader has opened. Keyed by [DiffGap.start] (the run's identity) so a revealed gap
  /// survives every rebuild AND the row list's virtualization — the same externalized-open-set
  /// discipline the sidestage accordion runs on. 已展开的 gap(按 start 记键):跨重建与虚拟化保持。
  final Set<int> _revealed = <int>{};

  // Memoized assembly — the LCS is the expensive half and must NOT re-run for a wrap flip, a gap
  // reveal, a copy-feedback tick or any parent rebuild. Keyed by the exact inputs that change it.
  // 装配记忆化:LCS 是贵的一半,翻 wrap/展 gap/复制反馈/父重建都绝不重跑;按真输入记键。
  String? _memoAfter;
  String? _memoBefore;
  bool? _memoLive;
  List<_DiffRow> _rows = const [];
  List<DiffGap> _gaps = const [];
  int _added = 0;
  int _removed = 0;
  int _lastLn = 0;

  TextStyle get _rowStyle => widget.reading ? AnText.codeReading : AnText.code;

  @override
  void initState() {
    super.initState();
    _wrap = widget.wrap;
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    // The COPY payload is the NEW text — what lands after the change applies. 复制载荷=after(改后全文)。
    Clipboard.setData(ClipboardData(text: widget.after)).then(
      (_) {
        if (!mounted) return;
        setState(() {
          _copied = true;
          _copyFailed = false;
        });
        _resetCopy();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _copyFailed = true;
          _copied = false;
        });
        _resetCopy();
      },
    );
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

    _ensureAssembled();
    // Live empty guard (复审 #29): nothing streamed yet → no bar-only empty shell. 空流不渲空壳。
    if (widget.live && _rows.isEmpty) return const SizedBox.shrink();

    // Gutter width: a SINGLE fixed width for every row (per-row ConstrainedBox-floor would let rows with
    // different digit counts diverge and misalign the sign/code columns). Measured from the largest line
    // number so 5+ digits don't clip, floored at AnSize.trail. 行号列统一固定宽。
    final gutterW = _gutterWidth(context, _lastLn);
    // ONE metric read for BOTH axes: the mono advance (→ horizontal extent) and the line box (→ the
    // fixed row extent). 一次量出双轴度量:等宽字符宽(横向)+ 行盒高(等高档行高)。
    final (:charW, :lineH) = measureText(
      TextSpan(text: '0', style: _rowStyle),
      textScaler: MediaQuery.textScalerOf(context),
      read: (tp) => (charW: tp.width, lineH: tp.height),
    );

    final (:items, :maxLen) = _items();
    final rowsRegion = _rowsRegion(
      context,
      c,
      syntax,
      t,
      items: items,
      gutterW: gutterW,
      // Mono advance × longest line + the fixed columns + the row's right inset — ONE arithmetic
      // instead of laying every row out twice (the retired per-row IntrinsicWidth). CJK/emoji in a
      // mono face are double-advance and count as one here: the only cost is a slightly short scroll
      // extent on such a line, never a layout error (the code cell CLIPS, it cannot overflow).
      // 内容宽=字符宽×最长行+定宽列+右内距,一次算术(逐行 IntrinsicWidth 已删);全角字按 1 宽计,极端全角
      // 行只会横滚略短(代码格是裁切、不会溢出报错)。
      contentW: gutterW + AnSize.iconLg + maxLen * charW + AnSpace.s12,
      rowExtent: lineH,
    );

    final framed = Semantics(
      container: true,
      label: t.a11y.diff(added: _added, removed: _removed),
      child: AnCodeSurface(
        bare: widget.bare,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final column = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.bare) _bar(context, c, t, _added, _removed),
                // LIVE: the bounded stick-to-bottom viewport (the code family's one law — the newest
                // + line stays visible while streaming, 复审 #6; white-face fades per 拍板 #1).
                // SETTLED: content-height when unbounded, scroll when bounded.
                // live=有界贴底视口(最新 + 行流入期恒可见;白面渐隐);settled=无界内容高/有界纵滚。
                if (widget.live)
                  AnStickViewport(
                    maxHeight: widget.maxHeight ?? AnSize.codeViewport,
                    fadeColor: c.surface,
                    child: rowsRegion,
                  )
                // The settled zero-jump clamp sits on the BODY — mirroring the live viewport position
                // (bar OUTSIDE the clamp) so the settle only un-pins and the total height is identical
                // across faces (批2 复审: the whole-frame clamp made settle 32px shorter). In a bounded
                // host the Flexible keeps the crop silent-safe. 落定钳在 body(与 live 视口同位,bar 在
                // 钳外):两脸总高全等(批2 复审:整框钳曾令落定矮 32px);有界宿主经 Flexible 静默安全。
                else if (constraints.maxHeight.isFinite)
                  Flexible(
                    child: widget.maxHeight == null
                        ? rowsRegion
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: widget.maxHeight!,
                            ),
                            child: rowsRegion,
                          ),
                  )
                else if (widget.maxHeight != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                    child: rowsRegion,
                  )
                else
                  rowsRegion,
                // The whole-file escape rides BELOW the scroll region (never inside it — a control the
                // reader must scroll 3000 rows to find is not an affordance), in the kit's expand-all
                // grammar (AnFadeCollapse's toggle / AnLedgerList's escape row).
                // 整份逃生口在滚动区之下(不在其内:要滚 3000 行才找得到的控件不算示能),走套件展开全部文法。
                if (_showFoldToggle) _foldToggle(context, c, t),
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

  // Assemble the diff rows + add/remove counts, ONCE per (before, after, live). SETTLED = line-by-line
  // LCS ([lineDiff]). LIVE = the two-act order — every − [before] line then every + [after] line, NO LCS
  // (diffing half-arrived text lies); the rows then flow through the ONE render path, so live and
  // settled share every metric. Also folds the hunk gaps here (index arithmetic over the same ops) and
  // drops the reveal set, whose keys belong to the OLD sequence.
  // 装配 diff 行+增删计数,按 (before,after,live) 只跑一次。落定=逐行 LCS;live=两幕序(先全部 −旧再全部
  // +新,不做 LCS——半截文本 diff 会撒谎),行走同一条渲染路径,live/落定全度量共享。hunk gap 同处算出;
  // 内容一换即清展开集(旧键已失效)。
  void _ensureAssembled() {
    if (_memoAfter == widget.after &&
        _memoBefore == widget.before &&
        _memoLive == widget.live) {
      return;
    }
    _memoAfter = widget.after;
    _memoBefore = widget.before;
    _memoLive = widget.live;

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
    } else if (b == null || b.isEmpty) {
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
            rows.add(
              _DiffRow(DiffOp.del, null, d.text),
            ); // deleted line → no new-file number 删行无号
          case DiffOp.context:
            rows.add(_DiffRow(DiffOp.context, ++ln, d.text));
        }
      }
    }
    _rows = rows;
    _added = added;
    _removed = removed;
    _lastLn = ln;
    _gaps = widget.live
        ? const []
        : unchangedGaps([for (final r in rows) r.op]);
    _revealed.clear();
  }

  bool get _folding => widget.hunks && _gaps.isNotEmpty;

  /// The escape row exists only when the caller wired the mode AND there is something to fold — a
  /// «show all» under an already-whole diff is a dead affordance. 有可折之物且调用方接了手才渲。
  bool get _showFoldToggle => widget.onHunksChanged != null && _gaps.isNotEmpty;

  // The render list: rows, with each unfolded gap standing in for the run it swallows. The longest
  // RENDERED line comes out with it (folded mode gets the tighter scroll extent it earned).
  // 渲染项:行 + 未展开的 gap 标记;顺带带出最长渲染行(折叠态自然得到更紧的横滚范围)。
  ({List<_Item> items, int maxLen}) _items() {
    final items = <_Item>[];
    var maxLen = 0;
    var gi = 0;
    var i = 0;
    while (i < _rows.length) {
      if (_folding && gi < _gaps.length && _gaps[gi].start == i) {
        final gap = _gaps[gi];
        gi++;
        if (!_revealed.contains(gap.start)) {
          items.add(_Item.gap(gap));
          i += gap.count;
          continue;
        }
      }
      final row = _rows[i];
      items.add(_Item.row(row));
      if (row.text.length > maxLen) maxLen = row.text.length;
      i++;
    }
    return (items: items, maxLen: maxLen);
  }

  // ONE rows region for every face. Horizontal scroller OUTSIDE (long lines), vertical sliver viewport
  // INSIDE (laziness) — and BOTH stay mounted across every mode flip: wrap only flips the horizontal
  // physics + the row width, never the structure (RI 军规: a conditional wrapper would unmount and
  // remount every row and lose the reading position).
  //
  // `shrinkWrap` is the honest laziness switch, decided from the height the LayoutBuilder actually
  // hands us: content that fits sizes to itself (no dead space under a 3-line diff — a greedy viewport
  // would leave a void) and is small enough that laziness buys nothing; content taller than the clamp
  // fills the clamp and goes LAZY. An unbounded host has no viewport at all, so it can only shrink-wrap.
  //
  // 一条行区服务所有脸:横滚在外(长行)、纵向 sliver 视口在内(惰性);翻 wrap 只改横向 physics 与行宽,
  // 结构恒挂(RI 军规:条件包装会卸载重挂每一行、丢掉阅读位置)。shrinkWrap = 诚实的惰性开关,按
  // LayoutBuilder 真给的高判:装得下就贴自身高(矮 diff 下不留死空白,贪心视口会留)、且惰性无收益;高过
  // 钳高就填满钳高并转惰性;无界宿主没有视口,只能 shrinkWrap。
  Widget _rowsRegion(
    BuildContext context,
    AnColors c,
    SyntaxColors syntax,
    Translations t, {
    required List<_Item> items,
    required double gutterW,
    required double contentW,
    required double rowExtent,
  }) {
    // Vertical breathing OUTSIDE the rows (inside it would paint the pad with a row's tint). 呼吸内距在行外。
    const pad = EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s12);
    final contentH = items.length * rowExtent + pad.vertical;
    return LayoutBuilder(
      builder: (ctx, cons) {
        final viewportW = cons.maxWidth.isFinite ? cons.maxWidth : 0.0;
        final bounded = cons.maxHeight.isFinite;
        final fits = !bounded || contentH <= cons.maxHeight;
        final delegate = SliverChildBuilderDelegate(
          (ctx, i) => _item(ctx, c, syntax, t, items[i], gutterW),
          childCount: items.length,
          addAutomaticKeepAlives:
              false, // a diff row owns no state to keep 行无状态可保
          addSemanticIndexes:
              false, // rows carry their own merged label 行自带合并语义
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // wrap → the rows already fit; the scroller stays mounted and merely stops scrolling (so it
          // also stops eating horizontal drags). wrap 时行已装得下,滚动器恒挂、只停滚(不再吞横向拖拽)。
          physics: _wrap ? const NeverScrollableScrollPhysics() : null,
          child: SizedBox(
            // Rows fill at least the viewport (tints span the frame); non-wrap grows to the content.
            // 行至少填满视口(底色贯满框);非 wrap 撑到内容宽。
            width: _wrap ? viewportW : math.max(viewportW, contentW),
            child: CustomScrollView(
              shrinkWrap: fits,
              // NEVER the ambient primary controller: a vertical ScrollView with no controller claims
              // it by default, and the host page already owns that controller (two positions on one
              // controller asserts). 绝不认领环境 primary 控制器(纵向无控制器的 ScrollView 默认认领,
              // 而宿主页已持有它——一个控制器两个 position 会断言)。
              primary: false,
              // A bounded region always KEEPS its physics: `fits` is exact for one-line rows but only a
              // lower bound under wrap, and a mis-estimate must degrade to «scrollable» — never to
              // «clipped with no way down». Unbounded = the host page owns the scroll.
              // 有界区恒保留 physics:fits 在等高行下精确、wrap 下只是下界,估错须退化为「可滚」而非
              // 「裁掉且无法下探」;无界时滚动权归宿主页。
              physics: bounded ? null : const NeverScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: pad,
                  // Every non-wrap row is exactly one measured line box → the cheapest sliver tier
                  // (O(1) extent maths, no child layout to know where row 2500 is). Under wrap a row's
                  // height depends on how the text reflows, which only layout knows → SliverList.
                  //
                  // This IS a slot-type swap, so the RI verdict is spelled out rather than assumed: it
                  // fires only on an explicit user mode flip that already re-lays out every row and
                  // re-measures the horizontal extent; the Scrollable + Viewport + SliverPadding above it
                  // all stay mounted (so the scroll POSITION survives); virtualization bounds the
                  // re-inflation to the visible window; and a diff row subscribes to nothing (no
                  // provider, no future) — the three costs the ban exists to prevent are all absent.
                  //
                  // 非 wrap 每行恰一个量出的行盒 → 最便宜档(O(1) 定位,不必布局就知第 2500 行在哪);
                  // wrap 下行高取决于文本怎么折,只有布局知道 → SliverList。此处确是换槽类型,故 RI 裁决
                  // 写明而非默认:它只在用户显式翻模式时发生(那一下本就重排每一行、重量横向宽),其上的
                  // Scrollable + Viewport + SliverPadding 全部恒挂(滚动位置得以保住),虚拟化把重建限在
                  // 可见窗内,且 diff 行不订阅任何东西(无 provider、无 future)——军规要防的三种代价此处皆无。
                  sliver: _wrap
                      ? SliverList(delegate: delegate)
                      : SliverFixedExtentList(
                          itemExtent: rowExtent,
                          delegate: delegate,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // The bar — ISOMORPHIC with AnCodeEditor's (WRK-066 拍板 #3): left copy + wrap (+ range/note), a
  // single flexible filler, right-pinned +N −N (the diff's «language label» slot shows counts).
  // 顶栏与编辑器同构:左 copy+wrap(+范围/说明),单一弹性填充,右钉 +N −N(diff 的「语言标」槽=计数)。
  Widget _bar(
    BuildContext context,
    AnColors c,
    Translations t,
    int added,
    int removed,
  ) {
    final copyTip = _copied
        ? t.feedback.copied
        : (_copyFailed ? t.feedback.copyFailed : t.action.copy);
    return Padding(
      padding: const EdgeInsets.only(
        left: AnSpace.s12,
        right: AnSpace.s12,
        top: AnSpace.s8,
      ),
      child: Row(
        children: [
          AnButton.iconOnly(
            _copied ? AnIcons.check : AnIcons.copy,
            size: AnButtonSize.sm,
            semanticLabel: copyTip,
            onPressed: _copy,
          ),
          const SizedBox(width: AnSpace.s4),
          AnButton.iconOnly(
            AnIcons.wrap,
            size: AnButtonSize.sm,
            semanticLabel: t.action.wrap,
            onPressed: () => setState(() => _wrap = !_wrap),
          ),
          if (widget.range != null) ...[
            const SizedBox(width: AnSpace.s8),
            Text(
              widget.range!,
              style: AnText.value(mono: true).copyWith(color: c.inkMuted),
            ),
          ],
          const SizedBox(width: AnSpace.s8),
          // ONE flexible filler between the left cluster and the right-pinned counts. 单一弹性填充钉右。
          if (widget.note != null)
            Expanded(
              child: Text(
                widget.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
            )
          else
            const Spacer(),
          if (added > 0 || removed > 0)
            // The container a11y label already speaks the counts — don't read them twice (复审 #49).
            // 容器 a11y 已念计数,不念两遍。
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '+$added',
                      style: AnText.value(mono: true).copyWith(color: c.ok),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: '−$removed',
                      style: AnText.value(mono: true).copyWith(color: c.danger),
                    ),
                  ],
                ),
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
    // INCLUDE the left s12 + right s8 inset so the gutter matches AnCodeEditor's; CEIL the measured
    // advance so a sub-pixel shortfall can't clip the last digit. 含内距(与编辑器一致);量出的宽向上取整,
    // 免得差一个亚像素把末位数字裁掉。
    return math.max(AnSize.trail, AnSpace.s12 + w.ceilToDouble() + AnSpace.s8);
  }

  Widget _item(
    BuildContext context,
    AnColors c,
    SyntaxColors syntax,
    Translations t,
    _Item item,
    double gutterW,
  ) {
    final gap = item.gap;
    return gap == null
        ? _row(context, c, syntax, t, item.row!, gutterW)
        : _gapRow(context, c, t, gap, gutterW);
  }

  // A folded run, standing in the SAME three-column grid (empty gutter · ⋯ where the sign goes · the
  // count where the code goes) and exactly one line box tall, so the fixed-extent tier holds. Tapping
  // reveals just this run. 折叠段:同三列网格(空行号列 · 符号位 ⋯ · 代码位计数),恰一个行盒高(等高档成立);
  // 点它只展开这一段。
  Widget _gapRow(
    BuildContext context,
    AnColors c,
    Translations t,
    DiffGap gap,
    double gutterW,
  ) {
    return Semantics(
      button: true,
      child: AnInteractive(
        onTap: () => setState(() => _revealed.add(gap.start)),
        builder: (context, states) {
          final active = states.isActive;
          return Container(
            color: c.surfaceHover.whenActive(active),
            padding: const EdgeInsets.only(right: AnSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: gutterW),
                SizedBox(
                  width: AnSize.iconLg,
                  child: Text(
                    '⋯',
                    textAlign: TextAlign.center,
                    style: _rowStyle.copyWith(color: c.inkFaint),
                  ),
                ),
                Expanded(
                  child: Text(
                    t.diff.folded(n: gap.count),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: _rowStyle.copyWith(
                      color: active ? c.ink : c.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // The whole-file escape, in the kit's expand-all grammar (AnFadeCollapse's toggle row / AnLedgerList's
  // escape row): a full-width centred label that hands the new mode back to the caller.
  // 整份逃生口,走套件展开全部文法(AnFadeCollapse 开关行 / AnLedgerList 逃生行):整宽居中标签,回调给调用方。
  Widget _foldToggle(BuildContext context, AnColors c, Translations t) {
    return Semantics(
      button: true,
      child: AnInteractive(
        onTap: () => widget.onHunksChanged!(!widget.hunks),
        builder: (context, states) => SizedBox(
          height: AnSize.row,
          child: Center(
            child: Text(
              widget.hunks
                  ? t.diff.showAll(n: _rows.length)
                  : t.diff.onlyChanges,
              style: AnText.label.copyWith(
                color: states.contains(WidgetState.hovered)
                    ? c.ink
                    : c.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AnColors c,
    SyntaxColors syntax,
    Translations t,
    _DiffRow r,
    double gutterW,
  ) {
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
              padding: const EdgeInsets.only(
                left: AnSpace.s12,
                right: AnSpace.s8,
              ),
              child: Text(
                r.lineNo?.toString() ?? '',
                textAlign: TextAlign.right,
                // A line NUMBER must never wrap: a two-line gutter both misaligns the code beside it
                // and breaks the fixed-extent tier's one-line-per-row premise (the second line would
                // be squeezed out). 行号绝不换行:双行行号既错开旁边的代码,也打破等高档「每行一行」的前提。
                maxLines: 1,
                softWrap: false,
                style: _rowStyle.copyWith(color: c.inkFaint),
              ),
            ),
          ),
          // sign 符号
          SizedBox(
            width: AnSize.iconLg,
            child: Text(
              sign,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: _rowStyle.copyWith(color: base),
            ),
          ),
          // code — base colour tinted by the op; token spans keep their syntax colours over it. The cell
          // is ALWAYS the flex child (RI 军规: wrap must not swap the slot's shape) and only its text
          // parameters flip — wrap soft-wraps inside the viewport width, non-wrap paints one line inside
          // the measured content width and CLIPS (so no arithmetic slip can ever RenderFlex-overflow).
          // 代码格恒为弹性子(RI 军规:翻 wrap 不换槽形),只翻文本参数——wrap 在视口宽内软折,非 wrap 在
          // 量出的内容宽内单行绘制并裁切(故任何量测偏差都不会触发溢出报错)。
          Expanded(
            child: Text.rich(
              TextSpan(
                style: _rowStyle.copyWith(color: base),
                children: highlightCode(
                  r.text,
                  lang: widget.lang,
                  colors: syntax,
                ),
              ),
              softWrap: _wrap,
              maxLines: _wrap ? null : 1,
              overflow: TextOverflow.clip,
            ),
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

/// One render item: a diff row, or a folded run standing in for the lines it swallows. 渲染项:行 或 折叠段。
class _Item {
  const _Item.row(this.row) : gap = null;
  const _Item.gap(this.gap) : row = null;
  final _DiffRow? row;
  final DiffGap? gap;
}

class _DiffRow {
  const _DiffRow(this.op, this.lineNo, this.text);
  final DiffOp op;
  final int?
  lineNo; // new-file line number; null for a deleted line 新文件行号(删行 null)
  final String text;
}
