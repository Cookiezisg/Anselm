import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_inline_capsule.dart';

/// A CEL expression, DISPLAYED AS A DISCRIMINANT (WRK-061 §7 — the graph-and-logic stages' shared
/// grammar): dotted-path references (`input.total`, `payload.sku`, `normalize.result`) condense into
/// accent capsules — the expression's DATA INLETS made visible — while operators/literals stay mono.
/// While [live], only tokens newer than the previous build fade in (R-13: the animation window is the
/// tail, everything older is static); settled renders whole. Pure text-in, spans-out — the upstream
/// flash (水脉闪 toward the referenced node) is the graph canvas's business, not this primitive's.
///
/// CEL 判别式陈列件——图与判别式舞台的共享文法:点路径引用(`input.total`/`payload.sku`/上游.field)凝成
/// accent 药囊(数据入射口可见),操作符/字面量保持 mono。[live] 期只有比上次新的 token 淡入(R-13 有界:
/// 动画窗=尾部,旧 token 静态);落定整段静渲。纯文本进、span 出——水脉闪归图画布,不在本件。
class AnCelGrow extends StatefulWidget {
  const AnCelGrow({required this.expression, this.live = false, this.compact = false, super.key});

  final String expression;
  final bool live;

  /// Inline-in-prose tier (approval's {{ }} capsules) — smaller capsules, no background. 散文内嵌档。
  final bool compact;

  /// The dotted-path reference token (two+ segments — a data inlet). 点路径引用(两段+=数据入射)。
  static final RegExp referenceRe = RegExp(r'[A-Za-z_]\w*(?:\.\w+)+');

  @override
  State<AnCelGrow> createState() => _AnCelGrowState();
}

class _AnCelGrowState extends State<AnCelGrow> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  int _seenLength = 0; // chars already on stage (the fade boundary) 已在场字符数(淡入边界)

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: AnMotion.mid, value: 1);
    _seenLength = widget.live ? 0 : widget.expression.length;
    if (widget.live && widget.expression.isNotEmpty) _fade.forward(from: 0);
  }

  @override
  void didUpdateWidget(AnCelGrow old) {
    super.didUpdateWidget(old);
    if (old.expression != widget.expression) {
      _seenLength = widget.expression.startsWith(old.expression) ? old.expression.length : 0;
      if (widget.live && !AnMotionPref.reduced(context)) {
        _fade.forward(from: 0);
      } else {
        _fade.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expr = widget.expression;
    final base = (widget.compact ? AnText.meta : AnText.code).copyWith(color: c.inkMuted);
    final spans = <InlineSpan>[];

    void addRun(String text, bool fresh) {
      if (text.isEmpty) return;
      var last = 0;
      for (final m in AnCelGrow.referenceRe.allMatches(text)) {
        if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
        // The ONE inline-capsule shell (批5 A-030 — the hand-rolled [[ref]] pill retires; the
        // compact 2px h-pad folds into the family 4px, 刻意归档). 唯一行内壳;compact 内距归族档。
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnInlineCapsule(m.group(0)!, textStyle: widget.compact ? AnText.meta : AnText.code),
        ));
        last = m.end;
      }
      if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
    }

    // The static prefix renders whole; only the fresh tail rides the fade (R-13). 静前缀+淡尾。
    final boundary = _seenLength.clamp(0, expr.length);
    final staticPart = expr.substring(0, boundary);
    final freshPart = expr.substring(boundary);
    addRun(staticPart, false);
    final staticText = Text.rich(TextSpan(children: List.of(spans)), softWrap: true);
    if (freshPart.isEmpty) return staticText;

    final freshSpans = <InlineSpan>[];
    final keep = spans.length;
    addRun(freshPart, true);
    final tail = spans.sublist(keep);
    freshSpans.addAll(tail);
    spans.removeRange(keep, spans.length);
    return Text.rich(TextSpan(children: [
      ...spans,
      WidgetSpan(
        child: FadeTransition(
          opacity: _fade,
          child: Text.rich(TextSpan(children: freshSpans), softWrap: true),
        ),
      ),
    ]));
  }
}
