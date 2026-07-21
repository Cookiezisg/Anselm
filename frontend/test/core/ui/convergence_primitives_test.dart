import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_code_block.dart';
import 'package:anselm/core/ui/an_window.dart';
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
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  group('AnWindow 单体窗约束直通 (批4 复审 HIGH)', () {
    testWidgets(
      'a tight-height host bounds the inner viewport — 40-line reverse tail neither overflows nor loses the bottom pin',
      (t) async {
        Widget tail(String text) => SizedBox(
          height: 220,
          child: AnWindow(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ClipRect(
                child: SingleChildScrollView(
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(text),
                ),
              ),
            ),
          ),
        );
        // Long tail: the interposing content Column used to hand the body UNBOUNDED height here —
        // RenderFlex overflow + top-anchored text (探针实证). 长尾:夹层 Column 曾给无界高→溢出+钉头。
        await t.pumpWidget(
          _host(tail(List.generate(40, (i) => 'line $i').join('\n'))),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // Short tail stays bottom-pinned (the live «钉在前沿» semantics). 短尾贴底。
        await t.pumpWidget(_host(tail('short tail')));
        await t.pumpAndSettle();
        final windowBottom = t.getBottomLeft(find.byType(AnWindow)).dy;
        final textBottom = t.getBottomLeft(find.text('short tail')).dy;
        expect(
          windowBottom - textBottom,
          lessThan(24),
        ); // within the card inset of the bottom edge
        expect(
          textBottom - t.getTopLeft(find.byType(AnWindow)).dy,
          greaterThan(150),
        ); // not top-anchored 非钉头
      },
    );
  });

  group('AnSunkenPanel', () {
    testWidgets(
      'child-only (header slot retired with ToolWindow, WRK-066 批4)',
      (t) async {
        await t.pumpWidget(_host(const AnSunkenPanel(child: Text('ONLY'))));
        expect(find.text('ONLY'), findsOneWidget);
      },
    );
  });

  group('AnFloatingBar', () {
    testWidgets('lays its children out', (t) async {
      await t.pumpWidget(
        _host(const AnFloatingBar(children: [Text('L'), Text('R')])),
      );
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
      await t.pumpWidget(
        _host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [AnDivider.vertical()],
          ),
        ),
      );
      expect(t.getSize(find.byType(AnDivider)).height, AnSize.controlSm);
    });
    testWidgets('vertical honors a custom length', (t) async {
      await t.pumpWidget(
        _host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [AnDivider.vertical(length: 12)],
          ),
        ),
      );
      expect(t.getSize(find.byType(AnDivider)).height, 12);
    });
  });

  group('AnFormField', () {
    testWidgets('label + desc above the control', (t) async {
      await t.pumpWidget(
        _host(
          const AnFormField(label: 'LBL', desc: 'DSC', child: Text('CTRL')),
        ),
      );
      expect(find.text('LBL'), findsOneWidget);
      expect(find.text('DSC'), findsOneWidget);
      expect(find.text('CTRL'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('LBL')).dy,
        lessThan(t.getTopLeft(find.text('CTRL')).dy),
      );
    });
    testWidgets('labelTrailing rides the label baseline', (t) async {
      await t.pumpWidget(
        _host(
          const AnFormField(
            label: 'city',
            labelTrailing: Text('string'),
            child: Text('IN'),
          ),
        ),
      );
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
        _host(
          const SizedBox(
            height: 40,
            child: AnEdgeFade(fromTop: true, color: Color(0xFFFFFFFF)),
          ),
        ),
      );
      final box = t.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AnEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(g.begin, Alignment.topCenter);
      expect(
        g.colors.first,
        const Color(0xFFFFFFFF),
      ); // opaque at the begin edge
    });
    testWidgets('fromTop:false flips to the bottom edge', (t) async {
      await t.pumpWidget(
        _host(
          const SizedBox(
            height: 40,
            child: AnEdgeFade(fromTop: false, color: Color(0xFFFFFFFF)),
          ),
        ),
      );
      final box = t.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AnEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(g.begin, Alignment.bottomCenter);
    });
  });
}
