import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets(
    'clears a previous exact match when a reused danger zone gets a new subject',
    (tester) async {
      var expected = 'Alpha';
      var confirmations = 0;

      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AnTypeToConfirm(
                  title: 'Delete',
                  expected: expected,
                  inputHint: 'Type the name',
                  confirmLabel: 'Delete permanently',
                  onConfirm: () => confirmations++,
                ),
                TextButton(
                  onPressed: () => setState(() => expected = 'Beta'),
                  child: const Text('Swap subject'),
                ),
              ],
            ),
          ),
        ),
      );

      final field = find.byType(TextField);
      final confirm = find.widgetWithText(AnButton, 'Delete permanently');
      await tester.enterText(field, 'Alpha');
      await tester.pump();
      expect(tester.widget<AnButton>(confirm).onPressed, isNotNull);

      await tester.tap(find.text('Swap subject'));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.widget<AnButton>(confirm).onPressed, isNull);

      await tester.tap(confirm, warnIfMissed: false);
      expect(confirmations, 0);

      await tester.enterText(field, 'Beta');
      await tester.pump();
      await tester.tap(confirm);
      expect(confirmations, 1);
    },
  );
}
