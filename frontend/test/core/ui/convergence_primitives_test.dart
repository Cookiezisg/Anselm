import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_code_block.dart';
import 'package:anselm/core/ui/an_code_surface.dart';
import 'package:anselm/core/ui/an_divider.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/core/ui/an_floating_bar.dart';
import 'package:anselm/core/ui/an_form_field.dart';
import 'package:anselm/core/ui/an_sunken_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The six convergence primitives extracted from hand-stitched feature chrome (housecleaning): each is a
// thin, static wrapper, so the contract is structural — renders its slots, honors its variants.
// 六个从 feature 手缝收敛出的原语:各是薄静态封装,契约在结构——渲染各槽、遵各变体。

Widget _host(Widget child) => MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  group('AnSunkenPanel', () {
    testWidgets('header rides above the child', (t) async {
      await t.pumpWidget(_host(const AnSunkenPanel(header: Text('HDR'), child: Text('BODY'))));
      expect(find.text('HDR'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
      expect(t.getTopLeft(find.text('HDR')).dy, lessThan(t.getTopLeft(find.text('BODY')).dy));
    });
    testWidgets('no header → just the child', (t) async {
      await t.pumpWidget(_host(const AnSunkenPanel(child: Text('ONLY'))));
      expect(find.text('ONLY'), findsOneWidget);
    });
  });

  group('AnFloatingBar', () {
    testWidgets('lays its children out', (t) async {
      await t.pumpWidget(_host(const AnFloatingBar(children: [Text('L'), Text('R')])));
      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });
  });

  group('AnDivider', () {
    testWidgets('horizontal is a hairline-tall full-bleed rule', (t) async {
      await t.pumpWidget(_host(const AnDivider()));
      expect(t.getSize(find.byType(AnDivider)).height, AnSize.hairline);
    });
    testWidgets('vertical defaults to a controlSm-tall stroke', (t) async {
      await t.pumpWidget(_host(const Row(mainAxisSize: MainAxisSize.min, children: [AnDivider.vertical()])));
      expect(t.getSize(find.byType(AnDivider)).height, AnSize.controlSm);
    });
    testWidgets('vertical honors a custom length', (t) async {
      await t.pumpWidget(_host(const Row(mainAxisSize: MainAxisSize.min, children: [AnDivider.vertical(length: 12)])));
      expect(t.getSize(find.byType(AnDivider)).height, 12);
    });
  });

  group('AnFormField', () {
    testWidgets('label + desc above the control', (t) async {
      await t.pumpWidget(_host(const AnFormField(label: 'LBL', desc: 'DSC', child: Text('CTRL'))));
      expect(find.text('LBL'), findsOneWidget);
      expect(find.text('DSC'), findsOneWidget);
      expect(find.text('CTRL'), findsOneWidget);
      expect(t.getTopLeft(find.text('LBL')).dy, lessThan(t.getTopLeft(find.text('CTRL')).dy));
    });
    testWidgets('labelTrailing rides the label baseline', (t) async {
      await t.pumpWidget(_host(const AnFormField(label: 'city', labelTrailing: Text('string'), child: Text('IN'))));
      expect(find.text('city'), findsOneWidget);
      expect(find.text('string'), findsOneWidget);
    });
  });

  group('AnCodeBlock', () {
    testWidgets('frames mono text in an AnCodeSurface', (t) async {
      await t.pumpWidget(_host(const AnCodeBlock('exit 0')));
      expect(find.text('exit 0'), findsOneWidget);
      expect(find.byType(AnCodeSurface), findsOneWidget);
    });
    testWidgets('bare still renders the text', (t) async {
      await t.pumpWidget(_host(const AnCodeBlock('bare', bare: true)));
      expect(find.text('bare'), findsOneWidget);
    });
  });

  group('AnEdgeFade', () {
    testWidgets('fromTop is opaque at the top edge', (t) async {
      await t.pumpWidget(
          _host(const SizedBox(height: 40, child: AnEdgeFade(fromTop: true, color: Color(0xFFFFFFFF)))));
      final box = t.widget<DecoratedBox>(
          find.descendant(of: find.byType(AnEdgeFade), matching: find.byType(DecoratedBox)));
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(g.begin, Alignment.topCenter);
      expect(g.colors.first, const Color(0xFFFFFFFF)); // opaque at the begin edge
    });
    testWidgets('fromTop:false flips to the bottom edge', (t) async {
      await t.pumpWidget(
          _host(const SizedBox(height: 40, child: AnEdgeFade(fromTop: false, color: Color(0xFFFFFFFF)))));
      final box = t.widget<DecoratedBox>(
          find.descendant(of: find.byType(AnEdgeFade), matching: find.byType(DecoratedBox)));
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(g.begin, Alignment.bottomCenter);
    });
  });
}
