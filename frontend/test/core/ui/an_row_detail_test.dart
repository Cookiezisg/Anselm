import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnRowDetail = a row + a detail panel that reveals below it when open (controlled). AnRowDetail 契约。
void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('closed → detail hidden; open → detail revealed', (tester) async {
    await tester.pumpWidget(
      host(
        const AnRowDetail(
          open: false,
          row: AnRow(label: 'row'),
          detail: Text('detail panel'),
        ),
      ),
    );
    expect(find.text('row'), findsOneWidget);
    expect(find.text('detail panel'), findsNothing); // collapsed

    await tester.pumpWidget(
      host(
        const AnRowDetail(
          open: true,
          row: AnRow(label: 'row'),
          detail: Text('detail panel'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail panel'), findsOneWidget); // revealed
  });
}
