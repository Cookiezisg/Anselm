import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

// AnSection = small heading + unbordered content. caption = uppercase meta (reuses AnGroupLabel),
// plain = document-tier strong heading; both expose a `header` node reading the original-case label;
// actions sit head-right; the head renders when label OR actions present. AnSection 段契约。
void main() {
  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: SizedBox(width: 360, child: child)),
      );

  testWidgets('caption: visual label is uppercased, header reads original case', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnSection(label: 'inputs', children: [Text('body')])));
    expect(find.text('INPUTS'), findsOneWidget); // visual uppercased
    expect(find.text('body'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('inputs')); // SR hears original case, not "INPUTS"
    expect(node.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('plain: document-tier heading (not uppercased), header flagged', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnSection(label: 'Schedule', variant: AnSectionVariant.plain, children: [Text('b')])));
    expect(find.text('Schedule'), findsOneWidget); // original case
    expect(tester.getSemantics(find.bySemanticsLabel('Schedule')).flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('actions render at the head right; body children present', (tester) async {
    await tester.pumpWidget(host(AnSection(
      label: 'env',
      actions: [AnButton(label: 'Add', size: AnButtonSize.sm, onPressed: () {})],
      children: const [Text('row1'), Text('row2')],
    )));
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('row1'), findsOneWidget);
    expect(find.text('row2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions-only head renders (no label is not dropped)', (tester) async {
    await tester.pumpWidget(host(AnSection(
      actions: [AnButton(label: 'Add', size: AnButtonSize.sm, onPressed: () {})],
      children: const [Text('x')],
    )));
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('semanticLabel overrides the SR header label (visual stays the abbreviation)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnSection(label: 'I/O', semanticLabel: 'Inputs and outputs', children: [Text('b')])));
    expect(find.text('I/O'), findsOneWidget);
    expect(find.bySemanticsLabel('Inputs and outputs'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('head reading order: the header (label) is read BEFORE the actions (WRK-038 §G3-a invariant)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(AnSection(
      label: 'inputs',
      actions: [AnButton(label: 'Add', size: AnButtonSize.sm, onPressed: () {})],
      children: const [Text('body')],
    )));
    // Flatten the section's semantics subtree in traversal (reading) order, collecting labels.
    final labels = <String>[];
    void visit(SemanticsNode n) {
      if (n.label.isNotEmpty) labels.add(n.label);
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(AnSection)));
    final iHeader = labels.indexOf('inputs');
    final iAdd = labels.indexOf('Add');
    expect(iHeader, isNonNegative);
    expect(iAdd, greaterThan(iHeader), reason: 'label-Expanded physically precedes trailing actions');
    handle.dispose();
  });

  testWidgets('empty-string label with actions → actions-only head, no phantom empty header', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(AnSection(
      label: '',
      actions: [AnButton(label: 'Add', size: AnButtonSize.sm, onPressed: () {})],
      children: const [Text('x')],
    )));
    expect(find.text('Add'), findsOneWidget);
    // No header node should exist (empty label collapsed). 无空 header 节点。
    var headers = 0;
    void visit(SemanticsNode n) {
      if (n.flagsCollection.isHeader) headers++;
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(AnSection)));
    expect(headers, 0);
    handle.dispose();
  });
}
