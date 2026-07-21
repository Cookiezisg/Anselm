import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/entities/ui/detail/overview/control_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P1 · control as a rail entity — the ControlOverview detail page (support kind: meta + declared inputs +
// routing branches; NO execution/versions/logs). 支撑 kind 的 control 概览页。

final _t = DateTime.utc(2026, 7, 4);

ControlLogic _ctl({ControlVersion? version}) => ControlLogic(
  id: 'ctl_1',
  name: 'quality-gate',
  description: 'Route by test score',
  activeVersionId: 'ctlv_1',
  createdAt: _t,
  updatedAt: _t,
  activeVersion:
      version ??
      ControlVersion(
        id: 'ctlv_1',
        controlId: 'ctl_1',
        version: 2,
        inputs: const [Field(name: 'score', type: 'number')],
        branches: const [
          Branch(
            port: 'pass',
            when: 'input.score > 0.8',
            emit: {'grade': '"A"'},
          ),
          Branch(port: 'retry', when: 'true'),
        ],
        createdAt: _t,
        updatedAt: _t,
      ),
);

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 720, child: child)),
    ),
  ),
);

void main() {
  testWidgets(
    'renders meta + declared inputs + routing branches (port / when / emit / catch-all)',
    (tester) async {
      await tester.pumpWidget(_host(ControlOverview(control: _ctl())));
      await tester.pump();
      final d = TranslationProvider.of(
        tester.element(find.byType(ControlOverview)),
      ).translations.entities.detail;

      expect(find.text('Route by test score'), findsOneWidget); // description
      expect(find.text('ctl_1'), findsOneWidget); // id
      expect(find.text('score'), findsWidgets); // declared input field

      // Branches: pass (real condition + emit), retry (catch-all, passthrough).
      expect(find.text('pass'), findsWidgets);
      expect(find.text('input.score > 0.8'), findsOneWidget); // pass's when CEL
      expect(
        find.text('${d.editor.branchEmit}: grade'),
        findsOneWidget,
      ); // pass reshapes payload
      expect(find.text('retry'), findsWidgets);
      expect(
        find.text(d.editor.branchDefault),
        findsOneWidget,
      ); // retry is the catch-all
      expect(
        find.text(d.val.passthrough),
        findsOneWidget,
      ); // retry has no emit → passthrough
    },
  );

  testWidgets('no active version → honest empty inset', (tester) async {
    await tester.pumpWidget(
      _host(ControlOverview(control: _ctl().copyWith(activeVersion: null))),
    );
    await tester.pump();
    expect(
      find.byType(AnState),
      findsOneWidget,
    ); // insetEmpty, not a blank page
  });
}
