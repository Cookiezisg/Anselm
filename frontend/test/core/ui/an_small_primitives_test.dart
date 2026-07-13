import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_heat_bar.dart';
import 'package:anselm/core/ui/an_hover_surface.dart';
import 'package:anselm/core/ui/an_pop_surface.dart';
import 'package:anselm/core/ui/an_quote_bar.dart';
import 'package:anselm/core/ui/an_toned_panel.dart';
import 'package:anselm/core/ui/an_wash_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WRK-066 P6 — the five box/quote primitives extracted from the chat feature layer to clear the ratchet
/// (hand-rolled BoxDecoration → An* primitives). These lock each one's contract.
/// 五个从 chat feature 抽出的盒/引用原语(清棘轮:手搓 BoxDecoration→原语),锁契约。
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  BoxDecoration? decoOf(WidgetTester t, Finder f) {
    final c = t.widget<Container>(find.descendant(of: f, matching: find.byType(Container)).first);
    return c.decoration as BoxDecoration?;
  }

  testWidgets('AnHeatBar width scales with fraction and floors at 0.15', (tester) async {
    await tester.pumpWidget(host(const Row(mainAxisSize: MainAxisSize.min, children: [
      AnHeatBar(fraction: 1.0),
      AnHeatBar(fraction: 0.5),
      AnHeatBar(fraction: 0.0), // floored → 0.15 归底
    ])));
    final widths = tester.widgetList<Container>(find.byType(Container)).map((c) => c.constraints?.maxWidth).toList();
    // full > half, and the zero one is floored (not 0). 满>半,零被托到底不为 0。
    expect(widths[0]! > widths[1]!, isTrue);
    expect(widths[2], closeTo(AnSize.heatBar * 0.15, 0.01)); // 0.0 → 0.15 floor
    expect(widths[0], closeTo(AnSize.heatBar, 0.01)); // 1.0 → full
  });

  testWidgets('AnQuoteBar renders its child under a left rule', (tester) async {
    await tester.pumpWidget(host(const AnQuoteBar(child: Text('quoted'))));
    expect(find.text('quoted'), findsOneWidget);
    final deco = decoOf(tester, find.byType(AnQuoteBar))!;
    expect(deco.border, isA<Border>());
    expect((deco.border! as Border).left.width, AnSize.quoteBar); // the quote-bar rule 引用条宽
  });

  testWidgets('AnHoverSurface fills surfaceHover only when active', (tester) async {
    await tester.pumpWidget(host(const AnHoverSurface(active: true, child: Text('a'))));
    expect(decoOf(tester, find.byType(AnHoverSurface))!.color, AnColors.light.surfaceHover);

    await tester.pumpWidget(host(const AnHoverSurface(active: false, child: Text('b'))));
    expect(decoOf(tester, find.byType(AnHoverSurface))!.color, isNull); // transparent at rest 静息透明
  });

  testWidgets('AnTonedPanel carries the tone border at the card radius on surface', (tester) async {
    await tester.pumpWidget(host(AnTonedPanel(borderColor: AnColors.light.danger, child: const Text('gate'))));
    expect(find.text('gate'), findsOneWidget);
    final deco = decoOf(tester, find.byType(AnTonedPanel))!;
    expect(deco.color, AnColors.light.surface); // white panel 白面
    expect((deco.border! as Border).top.color, AnColors.light.danger); // the semantic tone edge tone 边
    expect(deco.borderRadius, BorderRadius.circular(AnRadius.card)); // card-16, not chip-12 机器窗圆角
  });

  testWidgets('AnPopSurface is the floating white island: surface + chip radius + line hairline + shadowPop',
      (tester) async {
    await tester.pumpWidget(host(const AnPopSurface(child: Text('pop'))));
    expect(find.text('pop'), findsOneWidget);
    final deco = tester
        .widget<DecoratedBox>(
            find.descendant(of: find.byType(AnPopSurface), matching: find.byType(DecoratedBox)).first)
        .decoration as BoxDecoration;
    expect(deco.color, AnColors.light.surface); // white island 白岛
    expect(deco.borderRadius, BorderRadius.circular(AnRadius.chip)); // chip radius
    expect((deco.border! as Border).top.color, AnColors.light.line); // hairline line border
    expect(deco.boxShadow, AnColors.light.shadowPop); // the pop lift 浮起
  });

  testWidgets('AnWashHighlight renders its child; reduced-motion collapses to the end (no wash)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AnTheme.light(),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: AnWashHighlight(child: Text('landed')))),
      ),
    ));
    expect(find.text('landed'), findsOneWidget);
    // Reduced motion → the tween starts (and stays) at the end state (wash=0, fully faded). 降级=终态无洗。
    final deco = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(AnWashHighlight), matching: find.byType(DecoratedBox)).first)
        .decoration as BoxDecoration;
    expect(deco.color!.a, closeTo(0, 0.001)); // fully faded 全淡出
  });
}
