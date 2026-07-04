import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnField = key/value big row, three modes: editable value (AnEditableValue), read-only value, and a
// child-slot control (value == null). Taller than AnKv. AnField 键值大行三态契约。
void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 380, child: child))),
        ),
      );

  // The edit pencil is hover-gated (idle 0-width so the value rests flush-right); hover the row to
  // reveal + enable it. 铅笔悬停门控(静态 0 宽让值贴右);悬停行揭示可点。
  Future<void> revealPencil(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(AnEditableValue).first));
    addTearDown(g.removePointer);
    await tester.pumpAndSettle();
  }

  testWidgets('editable value: pencil → edit → Enter commits', (tester) async {
    var value = 'old';
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (ctx, ss) => AnField(label: 'Name', value: value, editable: true, onChanged: (v) => ss(() => value = v)),
    )));
    await revealPencil(tester);
    await tester.tap(find.byIcon(AnIcons.edit));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(value, 'new');
  });

  testWidgets('read-only value: no pencil; merged "label: value" semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnField(label: 'Kind', value: 'function')));
    expect(find.text('function'), findsOneWidget);
    expect(find.byIcon(AnIcons.edit), findsNothing); // not editable → no pencil
    expect(find.bySemanticsLabel('Kind: function'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hint renders below the label and is in the SR label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnField(label: 'Timeout', hint: 'seconds', value: '30')));
    expect(find.text('seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Timeout, seconds: 30'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('child slot (value == null) renders the control, no pencil', (tester) async {
    await tester.pumpWidget(host(AnField(label: 'Mode', child: AnButton(label: 'Toggle', size: AnButtonSize.sm, onPressed: () {}))));
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Toggle'), findsOneWidget); // the control
    expect(find.byIcon(AnIcons.edit), findsNothing); // no edit affordance for a slot field
  });

  testWidgets('editable but null onChanged → read-only (no pencil)', (tester) async {
    await tester.pumpWidget(host(const AnField(label: 'Name', value: 'x', editable: true)));
    expect(find.byIcon(AnIcons.edit), findsNothing);
  });

  testWidgets('empty value shows an em-dash', (tester) async {
    await tester.pumpWidget(host(const AnField(label: 'Owner', value: '')));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('editing in a NARROW row with a multi-word label does not overflow (Save stays on-panel)', (tester) async {
    // Regression: a non-flex capped leading couldn't yield, so the ✓✕ buttons overflowed off-panel in a
    // ~300px inspector rail. The custom layout shrinks the leading so the value zone + buttons always fit.
    // 回归:窄行编辑时 leading 不让位 → ✓✕ 溢出;自研布局让 leading 收缩,值区+按钮恒在面板内。
    Widget narrow(Widget child) => TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
          ),
        );
    await tester.pumpWidget(narrow(StatefulBuilder(
      builder: (ctx, ss) => AnField(label: 'Max concurrency', value: 'short', editable: true, onChanged: (_) {}),
    )));
    await revealPencil(tester);
    await tester.tap(find.byIcon(AnIcons.edit));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'editing a long-label field in a narrow row must not overflow');
    // The Save button's right edge must be within the 300-wide panel. Save 按钮右缘须在面板内。
    final saveRight = tester.getRect(find.text('Save')).right;
    final panelRight = tester.getRect(find.byType(AnField)).right;
    expect(saveRight, lessThanOrEqualTo(panelRight + 0.5), reason: 'Save must stay on-panel, not pushed off the right');
  });
}
