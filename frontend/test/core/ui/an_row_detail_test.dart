import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnRowDetail = a row + a detail panel that reveals below it when open (controlled). AnRowDetail 契约。
void main() {
  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
      );

  testWidgets('closed → detail hidden; open → detail revealed', (tester) async {
    await tester.pumpWidget(host(const AnRowDetail(
      open: false,
      row: AnRow(label: 'row'),
      detail: Text('detail panel'),
    )));
    expect(find.text('row'), findsOneWidget);
    expect(find.text('detail panel'), findsNothing); // collapsed

    await tester.pumpWidget(host(const AnRowDetail(
      open: true,
      row: AnRow(label: 'row'),
      detail: Text('detail panel'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('detail panel'), findsOneWidget); // revealed
  });

  testWidgets('controlled: a row that toggles open shows/hides the detail', (tester) async {
    await tester.pumpWidget(host(_ToggleHost()));
    // open via the row tap (the host wires onSelect → toggle)
    expect(find.text('Cron'), findsNothing);
    await tester.tap(find.byType(AnRow));
    await tester.pumpAndSettle();
    expect(find.text('Cron'), findsOneWidget);
    await tester.tap(find.byType(AnRow));
    await tester.pumpAndSettle();
    expect(find.text('Cron'), findsNothing);
  });
}

class _ToggleHost extends StatefulWidget {
  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => AnRowDetail(
        open: _open,
        row: AnRow(label: 'Schedule', selected: _open, onSelect: () => setState(() => _open = !_open)),
        detail: const AnKv(rows: [AnKvRow('Cron', '0 0 * * *')]),
      );
}
