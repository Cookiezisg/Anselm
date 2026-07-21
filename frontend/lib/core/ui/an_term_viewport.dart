import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_edge_fade.dart';
import 'an_follow_pill.dart';
import 'an_interactive.dart';
import 'term_fold.dart';

/// A BOUNDED, STICK-TO-BOTTOM scroll region (WRK-056 #6, R10 base layer) — height-capped at [maxHeight],
/// initially pinned to the bottom (terminal/log semantics: the newest output is what you want), with a
/// top edge-fade when content scrolled off above and a «回到最新» floater when the user scrolled up.
/// Short content (≤ maxHeight) shows in full with no scroll, no fades, no floater. Reused by
/// [AnTermViewport] and (later) the nested-transcript frame. reduced motion: the return-to-latest jumps.
///
/// [fill] (WRK-061 W0): instead of capping, EXPAND to the parent's full height (the right island's
/// full-page terminal). The parent must give bounded height; [maxHeight] is ignored.
///
/// 有界贴底滚动区(R10 底座):限高 + 初始钉底 + 顶缘渐隐(上方有内容)+ 「回到最新」浮标(用户上滚时)。
/// 短内容全显无滚动。AnTermViewport 与嵌套 transcript 帧复用。reduced:回到最新跳底。
/// [fill](WRK-061 W0):不限高、撑满父高(右岛整页终端);父须给有界高,此时 [maxHeight] 失效。
class AnStickViewport extends StatefulWidget {
  const AnStickViewport({
    required this.child,
    this.maxHeight = 320,
    this.fill = false,
    this.header,
    this.fadeColor,
    super.key,
  });

  /// The scrollable content (usually a Column of lines). 可滚内容。
  final Widget child;
  final double maxHeight;

  /// Expand to the parent's height instead of capping at [maxHeight]. 撑满父高而非限高。
  final bool fill;

  /// An optional pinned header row above the scroll region (e.g. copy actions). 可选钉头行。
  final Widget? header;

  /// The edge-fade blend colour — MUST match the hosting surface (AnEdgeFade's contract). Default =
  /// the white window surface (the grey well is retired — WRK-066 族一; every viewport host is the
  /// one white-framed window). 渐隐融色——须配宿主底色;默认白窗面(灰井退役,族一)。
  final Color? fadeColor;

  @override
  State<AnStickViewport> createState() => _AnStickViewportState();
}

class _AnStickViewportState extends State<AnStickViewport> {
  final _scroll = ScrollController();
  bool _above = false; // content scrolled off above → top fade 上方有内容
  bool _below = false; // not at the bottom → show «回到最新» 未到底

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Pin to bottom after first layout (terminal semantics). 首帧后钉底。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pinToBottom(jump: true),
    );
  }

  @override
  void didUpdateWidget(AnStickViewport old) {
    super.didUpdateWidget(old);
    // New content while pinned → follow to bottom. 钉底时新内容→跟随。
    if (!_below) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pinToBottom(jump: true),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pinToBottom({required bool jump}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (jump || AnMotionPref.reduced(context)) {
      _scroll.jumpTo(max);
    } else {
      _scroll.animateTo(max, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
    _onScroll();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final off = _scroll.offset;
    final above = off > 1.0;
    final below = off < max - 1.0;
    if (above != _above || below != _below) {
      setState(() {
        _above = above;
        _below = below;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final region = Stack(
      children: [
        // In fill mode the scroll region must PAINT the full parent height too (a short log still owns
        // the page), hence the stretching SizedBox. fill 下滚动区须占满父高(短日志也占整页)。
        SizedBox(
          height: widget.fill ? double.infinity : null,
          child: SingleChildScrollView(
            controller: _scroll,
            child: widget.child,
          ),
        ),
        if (_above)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: AnSpace.s16,
            child: AnEdgeFade(
              fromTop: true,
              color: widget.fadeColor ?? c.surface,
            ),
          ),
        if (_below) ...[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: AnSpace.s16,
            child: AnEdgeFade(
              fromTop: false,
              color: widget.fadeColor ?? c.surface,
            ),
          ),
          Positioned(
            bottom: AnSpace.s4,
            right: AnSpace.s4,
            child: _backToLatest(context),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.header != null) widget.header!,
        if (widget.fill)
          Expanded(child: region)
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: region,
          ),
      ],
    );
  }

  Widget _backToLatest(BuildContext context) => AnFollowPill.jump(
    label: Translations.of(context).chat.tool.backToLatest,
    onTap: () => _pinToBottom(jump: false),
  );
}

/// A BOUNDED SCROLLBACK TERMINAL window (WRK-056 #6, R10 terminal layer) — the settled Bash body's
/// output as a real terminal: [termFold] folds cursor rewrites, [ansiSpans] themes colors, and the view
/// is bounded ([maxHeight]) + stick-to-bottom ([AnStickViewport]). For a huge (MB-scale) log only the
/// last [initialCharCap] chars materialize; a «显示更早 N 行» button at the top lazily reveals the rest
/// (the whole text is in memory, the viewport stays bounded — a look-at-everything escape hatch that
/// never dumps an unbounded wall into the transcript). [fill] passes through to [AnStickViewport]:
/// expand to the parent's height (the right island's full-page terminal, WRK-061) instead of capping.
/// 有界回滚终端窗:折叠+ANSI+钉底+懒加载更早。[fill] 透传:撑满父高(右岛整页终端)而非限高。
class AnTermViewport extends StatefulWidget {
  const AnTermViewport({
    required this.text,
    this.maxHeight = 320,
    this.fill = false,
    this.initialCharCap = 6000,
    this.header,
    this.fadeColor,
    super.key,
  });

  final String text;
  final double maxHeight;

  /// Expand to the parent's height instead of capping at [maxHeight]. 撑满父高而非限高。
  final bool fill;

  final int initialCharCap;

  /// An optional pinned header (copy actions). 可选钉头(复制)。
  final Widget? header;

  /// Edge-fade blend colour — pass the hosting surface when it isn't the default white window
  /// surface (WRK-066 族一). 渐隐融色——宿主非默认白窗面时传底色(族一)。
  final Color? fadeColor;

  @override
  State<AnTermViewport> createState() => _AnTermViewportState();
}

class _AnTermViewportState extends State<AnTermViewport> {
  bool _showAll = false;

  // Memoize the rendered lines (C-034): termFold is O(visible) and ansiSpans runs per line — the Column
  // is NOT lazy, so every line re-folded + re-coloured every build. A settled terminal re-renders on the
  // 1s ticker / inside live turns with the SAME text, and «show earlier» materializes an MB-scale log.
  // Cache the finished line widgets on (visible text, theme colors); rebuild only when either changes.
  // 渲染行记忆化:termFold O(visible)+ansiSpans 逐行,Column 非 lazy 故每行每 build 重折重染;按(可见文本,主题色)
  // 缓存成品行 widget,text/主题变才重建。
  String? _renderedFor;
  AnColors? _renderedColors;
  List<Widget>? _renderedLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = widget.text.length > widget.initialCharCap;
    // Materialize the tail only (unless the user asked for all). 只物化尾部(除非请求全量)。
    final visible = (over && !_showAll)
        ? widget.text.substring(widget.text.length - widget.initialCharCap)
        : widget.text;
    if (_renderedFor != visible || !identical(_renderedColors, c)) {
      _renderedFor = visible;
      _renderedColors = c;
      final lines = termFold(visible);
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      final base = AnText.code.copyWith(color: c.inkMuted);
      _renderedLines = [
        for (final line in lines)
          Text.rich(
            TextSpan(children: ansiSpans(line, c, base: base)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
      ];
    }
    final hiddenChars = over && !_showAll
        ? widget.text.length - widget.initialCharCap
        : 0;

    return AnStickViewport(
      maxHeight: widget.maxHeight,
      fill: widget.fill,
      header: widget.header,
      fadeColor: widget.fadeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hiddenChars > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s4),
              child: AnInteractive(
                onTap: () => setState(() => _showAll = true),
                builder: (ctx, states) => Text(
                  Translations.of(
                    context,
                  ).chat.tool.showEarlier(n: '${(hiddenChars / 60).round()}'),
                  style: AnText.meta.copyWith(
                    color: states.isActive ? c.accent : c.inkFaint,
                  ),
                ),
              ),
            ),
          ..._renderedLines!,
        ],
      ),
    );
  }
}
