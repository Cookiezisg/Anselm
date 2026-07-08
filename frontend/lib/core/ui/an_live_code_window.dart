import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_count_up.dart';
import 'an_sunken_panel.dart';

/// The LIVE CODE WINDOW (WRK-061 §7-1) — code streams in and is released BY WHOLE LINES, never
/// character-by-character (a held, incomplete last line never jitters). Shows the newest [tailLines]
/// lines bottom-anchored, a line-count roll ([AnCountUp]) in the header, and fades in ONLY the newest
/// arrivals (R-13: the animation window is bounded — lines that scroll off the tail become static).
/// Line counting is INCREMENTAL over the text suffix (O(delta) per update, W0 discipline); the tail
/// extraction is O(tail). Plain mono while flowing — highlighting waits for the settle (the editor).
///
/// 活代码窗:代码**整行释放**、绝不逐字(未完的尾行按住不显,不抖)。贴底渲最新 [tailLines] 行,头部行数
/// AnCountUp,只对最新落行淡入(R-13 有界:滑出尾窗即静态)。行数增量统计(每次只扫新后缀,O(delta));
/// 取尾 O(tail)。流动期纯等宽——高亮等落定(编辑器)。
class AnLiveCodeWindow extends StatefulWidget {
  const AnLiveCodeWindow({
    required this.text,
    this.tailLines = 24,
    this.header,
    super.key,
  });

  /// The in-flight code text (the args session's live string). 在途代码全文。
  final String text;

  final int tailLines;

  /// Optional header lead (e.g. the op chip row); the line counter is appended. 头部前导。
  final Widget? header;

  @override
  State<AnLiveCodeWindow> createState() => _AnLiveCodeWindowState();
}

class _AnLiveCodeWindowState extends State<AnLiveCodeWindow> {
  int _scanned = 0; // chars already counted 已统计字符数
  int _lines = 0; // completed (newline-terminated) lines 已完成行数
  int _prevLines = 0; // for the fade window 淡入窗口基准

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void didUpdateWidget(AnLiveCodeWindow old) {
    super.didUpdateWidget(old);
    if (!identical(old.text, widget.text)) {
      if (widget.text.length < _scanned || !_sameProbe(old.text)) {
        // Source replaced (settle snapshot swap) — rescan once. 换源(落定快照)重扫一次。
        _scanned = 0;
        _lines = 0;
      }
      _prevLines = _lines;
      _scan();
    }
  }

  bool _sameProbe(String old) =>
      widget.text.length >= old.length; // append-only heuristic: shrink = replace 只增;缩=换源

  void _scan() {
    final t = widget.text;
    for (var i = _scanned; i < t.length; i++) {
      if (t.codeUnitAt(i) == 0x0a) _lines++;
    }
    _scanned = t.length;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = widget.text;
    // Whole-line release: cut at the LAST newline — the incomplete tail line is withheld. 整行释放。
    final lastNl = t.lastIndexOf('\n');
    final released = lastNl < 0 ? '' : t.substring(0, lastNl);
    // O(tail) extraction of the newest lines. 取尾。
    var idx = released.length;
    for (var remaining = widget.tailLines; remaining > 0 && idx > 0; remaining--) {
      final nl = released.lastIndexOf('\n', idx - 1);
      if (nl < 0) {
        idx = 0;
        break;
      }
      idx = nl;
    }
    final tail = idx <= 0 ? released : released.substring(idx + 1);
    final lines = tail.isEmpty ? const <String>[] : tail.split('\n');
    final firstShownLine = _lines - lines.length; // global index of lines[0] 首显行全局序
    final freshFrom = _prevLines; // lines ≥ this are new this update 本次新落行
    final reduced = AnMotionPref.reduced(context);

    return AnSunkenPanel(
      header: Row(children: [
        if (widget.header != null) Expanded(child: widget.header!) else const Spacer(),
        AnCountUp(_lines, style: AnText.meta.copyWith(color: c.inkFaint)),
        Text(' L', style: AnText.meta.copyWith(color: c.inkFaint)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines.length; i++)
            _LineFade(
              // Key by GLOBAL line index: existing lines keep state (no re-fade), new ones fade once.
              // 按全局行序 key:旧行不重淡入,新行淡一次。
              key: ValueKey(firstShownLine + i),
              animate: !reduced && (firstShownLine + i) >= freshFrom,
              child: Text(
                lines[i].isEmpty ? ' ' : lines[i],
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: c.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineFade extends StatefulWidget {
  const _LineFade({required this.animate, required this.child, super.key});

  final bool animate;
  final Widget child;

  @override
  State<_LineFade> createState() => _LineFadeState();
}

class _LineFadeState extends State<_LineFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AnMotion.fast, value: widget.animate ? 0 : 1);
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c, child: widget.child);
}
