import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {double width = 640}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      );

  group('AnTransformBox', () {
    testWidgets('renders title, fields and type chips', (tester) async {
      await tester.pumpWidget(host(const AnTransformBox(
        title: 'fetch_weather',
        inputs: [AnTransformField('city', 'string')],
        outputs: [AnTransformField('temp', 'number'), AnTransformField('desc', 'string')],
        status: AnStatus.done,
        statusLabel: 'env ready',
        meta: 'Python 3.12 · 2 deps',
      )));
      expect(find.text('fetch_weather'), findsOneWidget);
      expect(find.text('city'), findsOneWidget);
      expect(find.text('temp'), findsOneWidget);
      expect(find.text('string'), findsNWidgets(2)); // city + desc type chips
      expect(find.text('env ready'), findsOneWidget);
      expect(find.text('Python 3.12 · 2 deps'), findsOneWidget);
    });

    testWidgets('empty sides render the dashed slot labels', (tester) async {
      await tester.pumpWidget(host(const AnTransformBox(
        title: 'now',
        emptyInputsLabel: 'no inputs',
        emptyOutputsLabel: 'no outputs',
      )));
      expect(find.text('no inputs'), findsOneWidget);
      expect(find.text('no outputs'), findsOneWidget);
    });

    testWidgets('live values render as captions (running phase)', (tester) async {
      await tester.pumpWidget(host(const AnTransformBox(
        title: 'f',
        inputs: [AnTransformField('city', 'string', value: '"Tokyo"')],
        outputs: [AnTransformField('temp', 'number')],
        phase: AnTransformPhase.running,
      )));
      expect(find.text('"Tokyo"'), findsOneWidget);
      // running box shows a breathing status dot even without an explicit status
      expect(find.byType(AnStatusDot), findsOneWidget);
    });

    testWidgets('stress: many long fields inside a narrow host do not overflow', (tester) async {
      await tester.pumpWidget(host(
        AnTransformBox(
          title: 'a_function_with_an_unreasonably_long_name_that_truncates',
          inputs: [for (var i = 0; i < 8; i++) AnTransformField('a_rather_long_input_field_name_$i', 'object')],
          outputs: [for (var i = 0; i < 5; i++) AnTransformField('out_$i', 'array')],
        ),
        width: 420,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('AnFadeCollapse', () {
    testWidgets('collapsible=false renders the child bare (no toggle)', (tester) async {
      await tester.pumpWidget(host(const AnFadeCollapse(
        collapsible: false,
        expandLabel: 'expand',
        collapseLabel: 'collapse',
        child: Text('body'),
      )));
      expect(find.text('body'), findsOneWidget);
      expect(find.text('expand'), findsNothing);
    });

    testWidgets('collapses tall content and toggles expand/collapse', (tester) async {
      final tall = Column(children: [for (var i = 0; i < 12; i++) Text('line $i')]);
      await tester.pumpWidget(host(AnFadeCollapse(
        collapsible: true,
        collapsedHeight: 100,
        expandLabel: 'expand',
        collapseLabel: 'collapse',
        child: tall,
      )));
      expect(tester.getSize(find.byType(SingleChildScrollView)).height, 100);
      expect(find.text('expand'), findsOneWidget);

      await tester.tap(find.text('expand'));
      await tester.pump();
      expect(find.text('collapse'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing); // expanded = bare child
      expect(find.text('line 11'), findsOneWidget);

      await tester.tap(find.text('collapse'));
      await tester.pump();
      expect(find.text('expand'), findsOneWidget);
    });
  });
}
