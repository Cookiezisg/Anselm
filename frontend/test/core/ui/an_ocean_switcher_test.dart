import 'package:anselm/core/ui/an_ocean_switcher.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('icon-only ocean slots remain named in the semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AnTheme.light(),
        home: Center(
          child: AnOceanSwitcher(
            items: const [
              AnOceanItem(id: 'chat', icon: Icons.chat_outlined, label: 'Chat'),
              AnOceanItem(
                id: 'entities',
                icon: Icons.grid_view,
                label: 'Entities',
              ),
              AnOceanItem(
                id: 'scheduler',
                icon: Icons.schedule,
                label: 'Scheduler',
              ),
              AnOceanItem(
                id: 'library',
                icon: Icons.menu_book_outlined,
                label: 'Library',
              ),
            ],
            selectedIndex: -1,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Chat', 'Entities', 'Scheduler', 'Library']) {
      expect(
        find.bySemanticsLabel(label),
        findsOneWidget,
        reason:
            'every ocean must remain discoverable when its label is collapsed',
      );
    }
    semantics.dispose();
  });
}
