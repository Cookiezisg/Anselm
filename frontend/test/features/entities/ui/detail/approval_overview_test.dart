import 'package:anselm/core/contract/entities/approval.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/entities/ui/detail/overview/approval_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P1 · approval as a rail entity — the ApprovalOverview detail page (support kind: meta + inputs + the
// markdown template + decision rules; NO execution/versions/logs). 支撑 kind 的 approval 概览页。

final _t = DateTime.utc(2026, 7, 4);

ApprovalForm _apf({
  String timeout = '2d',
  String behavior = 'reject',
  bool allowReason = true,
}) => ApprovalForm(
  id: 'apf_1',
  name: 'deploy-gate',
  description: 'Approve a production deploy',
  activeVersionId: 'apfv_1',
  createdAt: _t,
  updatedAt: _t,
  activeVersion: ApprovalVersion(
    id: 'apfv_1',
    approvalId: 'apf_1',
    version: 2,
    inputs: const [Field(name: 'env', type: 'string')],
    template:
        '# Deploy to {{ input.env }}?\n\nReview the diff before approving.',
    allowReason: allowReason,
    timeout: timeout,
    timeoutBehavior: behavior,
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
  testWidgets('renders meta + inputs + markdown template + decision rules', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ApprovalOverview(approval: _apf())));
    await tester.pump();
    final d = TranslationProvider.of(
      tester.element(find.byType(ApprovalOverview)),
    ).translations.entities.detail;

    expect(
      find.text('Approve a production deploy'),
      findsOneWidget,
    ); // description
    expect(find.text('apf_1'), findsOneWidget); // id
    expect(find.text('env'), findsWidgets); // declared input
    expect(find.byType(AnCodeEditor), findsOneWidget); // the markdown template
    // Decision rules KV.
    expect(find.text(d.val.yes), findsOneWidget); // allowReason = true
    expect(find.text('2d'), findsOneWidget); // timeout
    expect(find.text('reject'), findsOneWidget); // timeoutBehavior
  });

  testWidgets('empty timeout → "never", behavior row dropped', (tester) async {
    await tester.pumpWidget(
      _host(ApprovalOverview(approval: _apf(timeout: ''))),
    );
    await tester.pump();
    final d = TranslationProvider.of(
      tester.element(find.byType(ApprovalOverview)),
    ).translations.entities.detail;
    expect(find.text(d.val.never), findsOneWidget); // no timeout
    expect(
      find.text('reject'),
      findsNothing,
    ); // behavior meaningless without a timeout → dropped
  });

  testWidgets('no active version → honest empty inset', (tester) async {
    await tester.pumpWidget(
      _host(ApprovalOverview(approval: _apf().copyWith(activeVersion: null))),
    );
    await tester.pump();
    expect(find.byType(AnState), findsOneWidget);
  });
}
