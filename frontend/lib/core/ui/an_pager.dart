import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_a11y.dart';
import 'an_button.dart';
import 'an_expand_reveal.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The standard page-number pager (WRK-070 B4;形制照业界标准[Ant Design Pagination 定式],用户 0718
/// 复核拍板): **few pages (≤ [_AnPagerState.foldThreshold]) show EVERY number and NO jump field**
/// («‹ 1 2 3 ›» — 很少就不需要跳转); many pages fold to «‹ 1 … cur-1 cur cur+1 … last ›» AND grow
/// the quick-jump field. The current page is emphasised (that IS the «你在第几页»); the last number
/// IS the total. **A single page renders NOTHING** (拍板:没有多页就不要显示).
///
/// The jump field is a QUIET CELL (0718 拍板「Page 太大」): a compact 24 box, «#» glyph placeholder
/// (the word moved to the field's screen-reader name — the WORD was what forced the old 76px box),
/// width sized to the digits. While it holds a legal number an ↵ confirmer slides out on its right
/// (Enter still commits — the button answers «输完数字,然后呢» for the mouse).
///
/// Zero copy in core: the a11y words arrive via [AnPagerStrings]. Ellipses/# are text glyphs.
/// Hosts should CENTER it under the list (标准摆位居中,消费方负责).
///
/// 标准翻页器(Ant 定式):少页全列无跳转;多页开窗折 … + 跳页小格(24 盒「#」占位,词转读屏名;合法数字
/// 滑出 ↵ 确认钮,回车照旧直达);当前页加重即「在哪页」;末号即总页数;单页不渲。core 零文案;宿主居中。
class AnPagerStrings {
  const AnPagerStrings({
    required this.prevLabel,
    required this.nextLabel,
    required this.jumpHint,
    required this.pageLabel,
    required this.jumpToLabel,
  });

  final String prevLabel;
  final String nextLabel;

  /// The jump field's screen-reader name (e.g. «页码») — the VISIBLE placeholder is the «#» glyph,
  /// which a reader must not be left to guess at. 跳页格读屏名(可见占位是「#」记号,读屏须有词)。
  final String jumpHint;

  /// Screen-reader sentence for one number, e.g. `(n) => '第 $n 页'`. 读屏页句。
  final String Function(int page) pageLabel;

  /// The ↵ confirmer's label, e.g. `(n) => '跳转到第 $n 页'`. ↵ 确认钮读屏句。
  final String Function(int page) jumpToLabel;
}

class AnPager extends StatefulWidget {
  const AnPager({
    required this.page,
    required this.pageCount,
    required this.onPage,
    required this.strings,
    super.key,
  });

  /// Current page, 1-based. 当前页(1 起)。
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;
  final AnPagerStrings strings;

  @override
  State<AnPager> createState() => _AnPagerState();
}

class _AnPagerState extends State<AnPager> {
  final TextEditingController _jump = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Controller listener, not onChanged: the ↵ confirmer must also retract on the programmatic
    // clear after a submit (onChanged only fires on user edits). 控制器监听而非 onChanged:提交后的
    // 程序化清空也要收回 ↵ 钮(onChanged 只响应用户编辑)。
    _jump.addListener(_onJumpChanged);
  }

  void _onJumpChanged() => setState(() {});

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  /// The digits currently in the jump field, or null when they don't parse — the ↵ confirmer's
  /// existence condition. 跳页格里的合法数字(解析不出=null),即 ↵ 钮的存在条件。
  int? get _jumpTarget => int.tryParse(_jump.text.trim());

  /// Up to this many pages every number shows and the jump field stays hidden (Ant 定式);
  /// beyond it the strip folds and the quick jumper appears. 折叠阈:≤7 全列免跳转,>7 开窗+跳页。
  static const int foldThreshold = 7;

  /// The number strip: ALL pages when few; folded «1 … cur±1 … last» when many (gaps = one `…`
  /// sentinel, null). 页码带:少页全列;多页开窗,豁口折一枚 … 哨兵。
  List<int?> _strip() {
    final n = widget.pageCount;
    final cur = widget.page;
    if (n <= foldThreshold) return [for (var p = 1; p <= n; p++) p];
    final keep = <int>{1, n, cur - 1, cur, cur + 1}
      ..removeWhere((p) => p < 1 || p > n);
    final sorted = keep.toList()..sort();
    final out = <int?>[];
    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) out.add(null);
      out.add(p);
      prev = p;
    }
    return out;
  }

  void _go(int page) {
    final clamped = page.clamp(1, widget.pageCount);
    if (clamped != widget.page) widget.onPage(clamped);
  }

  void _jumpSubmit(String raw) {
    final p = int.tryParse(raw.trim());
    _jump.clear();
    if (p != null) _go(p);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 1) return const SizedBox.shrink();
    final c = context.colors;
    final s = widget.strings;
    // ‹ and › + the jump field are fixed anchors; the number strip is the flexible middle that
    // horizontally SCROLLS when the host is too narrow (a control must never overflow its container
    // — the project's «no in-grid overflow» law). In the run table's 720 column it never scrolls.
    // ‹ › 与跳页固定;数字带是可横滚的柔性中段(宿主过窄即滚,绝不溢出);720 列下从不滚。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnButton.iconOnly(
          AnIcons.chevronLeft,
          size: AnButtonSize.sm,
          semanticLabel: s.prevLabel,
          onPressed: widget.page > 1 ? () => _go(widget.page - 1) : null,
        ),
        const SizedBox(width: AnSpace.s4),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in _strip())
                  if (p == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AnSpace.s4,
                      ),
                      child: Text(
                        '…',
                        style: AnText.meta.copyWith(color: c.inkFaint),
                      ),
                    )
                  else
                    Semantics(
                      button: true,
                      selected: AnA11y.selected(p == widget.page),
                      label: s.pageLabel(p),
                      child: AnInteractive(
                        onTap: p == widget.page ? null : () => _go(p),
                        builder: (context, states) => Container(
                          height: AnSize.controlSm,
                          constraints: const BoxConstraints(
                            minWidth: AnSize.controlSm,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AnSpace.s4,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p == widget.page
                                ? c.surfaceHover
                                : c.surfaceHover.whenActive(states.isActive),
                            borderRadius: BorderRadius.circular(
                              AnRadius.button,
                            ),
                          ),
                          child: ExcludeSemantics(
                            child: Text(
                              '$p',
                              style:
                                  (p == widget.page
                                          ? AnText.metaTabular().weight(
                                              AnText.emphasisWeight,
                                            )
                                          : AnText.metaTabular())
                                      .copyWith(
                                        color: p == widget.page
                                            ? c.ink
                                            : c.inkMuted,
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AnSpace.s4),
        AnButton.iconOnly(
          AnIcons.chevronRight,
          size: AnButtonSize.sm,
          semanticLabel: s.nextLabel,
          onPressed: widget.page < widget.pageCount
              ? () => _go(widget.page + 1)
              : null,
        ),
        // The quick jumper exists only when the strip folds (很少就不需要跳转,Ant 同律). 折叠才有跳页。
        if (widget.pageCount > foldThreshold) ...[
          const SizedBox(width: AnSpace.s8),
          SizedBox(
            width: AnSize.pagerJumpW,
            child: AnInput(
              controller: _jump,
              // «#» glyph, compact 24 box (0718 拍板「Page 太大」): the WORD forced the old 76px box —
              // the sign hands the width back to the digits; the word lives on as the reader name.
              // 「#」记号+24 紧凑盒:词曾定宽,记号把宽还给数字;词转读屏名。
              placeholder: '#',
              tabular: true,
              compact: true,
              semanticLabel: s.jumpHint,
              onSubmitted: _jumpSubmit,
            ),
          ),
          // The ↵ confirmer slides out while the field holds a legal number (0718 拍板:「输完数字,
          // 然后呢」的出口——回车党不受影响,鼠标党有了确认器;非法输入无钮,收起即出树不可聚焦).
          AnExpandReveal(
            open: _jumpTarget != null,
            axis: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: AnSpace.s4),
              child: AnButton.iconOnly(
                AnIcons.enter,
                size: AnButtonSize.sm,
                semanticLabel: s.jumpToLabel(
                  (_jumpTarget ?? 1).clamp(1, widget.pageCount),
                ),
                onPressed: () => _jumpSubmit(_jump.text),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
