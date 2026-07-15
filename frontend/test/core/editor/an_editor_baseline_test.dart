// The ROOT of list-marker / task-checkbox alignment in the editor: [AnTextComponent]'s OUTER RenderBox must
// report the SuperText's real first-line alphabetic baseline. Without it, a parent Row with
// CrossAxisAlignment.baseline top-aligns the text (the ~2px-high bullet/numeral bug). These lock the proxy
// (_AnBaselineProxy) forwarding + the baseline-aligned list Row. 锁定 AnTextComponent 外 box 上报真基线 + 列表行基线对齐。
//
// NOTE: RenderBox.getDistanceToBaseline may only be called by a box's parent DURING layout, so we read it
// through [_BaselineProbe] — a proxy that captures its child's baseline in its own performLayout (a legal
// caller). getDistanceToBaseline 只能由父在布局中调用,故用探针 RenderObject 在自身 performLayout 里合法取值。
import 'package:anselm/core/editor/an_editor_text_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class _BaselineProbe extends SingleChildRenderObjectWidget {
  const _BaselineProbe({required this.onBaseline, required Widget super.child});
  final ValueChanged<double?> onBaseline;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBaselineProbe(onBaseline);

  @override
  void updateRenderObject(BuildContext context, _RenderBaselineProbe renderObject) =>
      renderObject.onBaseline = onBaseline;
}

class _RenderBaselineProbe extends RenderProxyBox {
  _RenderBaselineProbe(this.onBaseline);
  ValueChanged<double?> onBaseline;

  @override
  void performLayout() {
    super.performLayout(); // lays out the child, so its baseline is queryable
    onBaseline(child?.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true));
  }
}

void main() {
  testWidgets('outer box forwards the SuperText paragraph baseline; a raw SuperText reports none', (tester) async {
    // Three children built from the SAME span/style: the proxied AnTextComponent, a RAW SuperText (which drops
    // the baseline — the exact defect), and a plain RichText of the identical span (its RenderParagraph = the
    // ground-truth baseline). 同一 span 三件:代理版 AnTextComponent、裸 SuperText(丢基线=缺陷)、同 span 的 RichText(真值)。
    const style = TextStyle(fontSize: 20, height: 1.6);
    TextStyle sb(Set<Attribution> _) => style;
    double? anBaseline;
    double? rawSuperTextBaseline;
    double? paragraphBaseline;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          final span = AttributedText('Hg').computeInlineSpan(context, sb, const []);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BaselineProbe(
                onBaseline: (b) => anBaseline = b,
                child: AnTextComponent(text: AttributedText('Hg'), textStyleBuilder: sb),
              ),
              _BaselineProbe(
                onBaseline: (b) => rawSuperTextBaseline = b,
                child: SuperText(richText: span, textDirection: TextDirection.ltr),
              ),
              _BaselineProbe(
                onBaseline: (b) => paragraphBaseline = b,
                child: RichText(text: span, textDirection: TextDirection.ltr),
              ),
            ],
          );
        }),
      ),
    ));

    // The defect: SuperText's own render box reports no alphabetic baseline (→ Row baseline falls back to top).
    expect(rawSuperTextBaseline, isNull, reason: 'raw SuperText drops the baseline — the defect the proxy fixes');
    // The fix: the proxied component reports a real baseline, EQUAL to the paragraph it wraps (offset-free).
    expect(anBaseline, isNotNull, reason: 'AnTextComponent (via _AnBaselineProxy) reports a real baseline');
    expect(anBaseline, closeTo(paragraphBaseline!, 0.01), reason: 'and it equals the paragraph first-line baseline');
  });

  testWidgets('AnTextComponent still reports a baseline when the text is empty', (tester) async {
    // The most likely null-baseline regression: a brand-new empty list item / task with no text. 空文本电极。
    double? baseline;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _BaselineProbe(
          onBaseline: (b) => baseline = b,
          child: AnTextComponent(
            text: AttributedText(''),
            textStyleBuilder: (_) => const TextStyle(fontSize: 20, height: 1.6),
            highlightWhenEmpty: true,
          ),
        ),
      ),
    ));
    expect(baseline, isNotNull);
  });

  testWidgets('a baseline Row seats a short marker below a taller AnTextComponent (baseline engaged)', (tester) async {
    // Distinct line-box heights so TOP-align and BASELINE-align diverge. Under baseline alignment the short
    // marker is pushed DOWN so its baseline meets the taller body's baseline (marker top > 0). If the body
    // reported no baseline, the Row would top-align everything and the marker top would be ~0 — so `> 5` only
    // holds when the Row genuinely aligned by baseline. 记号与正文行盒不同高→基线对齐把矮记号下压(top>0);
    // 若正文不报基线则退化顶对齐、记号 top≈0,故 `>5` 仅在真按基线对齐时成立。
    const marker = TextStyle(fontSize: 16, height: 1.0);
    const body = TextStyle(fontSize: 16, height: 3.0);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('9.', style: marker),
              Expanded(child: AnTextComponent(text: AttributedText('Body'), textStyleBuilder: (_) => body)),
            ],
          ),
        ),
      ),
    ));
    expect(tester.getTopLeft(find.text('9.')).dy, greaterThan(5.0));
  });
}
