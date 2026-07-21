import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_disclosure.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnDisclosure = persistent-chevron header (icon/label/trailing) + AnExpandReveal body. Controlled:
// the caller owns `open`. The reveal removes the body from the tree when fully collapsed.
// AnDisclosure 契约:常驻 chevron 头 + 揭示体;受控;全收时 body 从树移除。
void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('tapping the header toggles the body reveal (controlled)', (
    tester,
  ) async {
    var open = false;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => AnDisclosure(
            label: 'reasoning',
            icon: AnIcons.reasoning,
            open: open,
            onToggle: () => setState(() => open = !open),
            child: const Text('BODY'),
          ),
        ),
      ),
    );

    // Collapsed: header shows, body removed from the tree. 收起:头显、体移除。
    expect(find.text('reasoning'), findsOneWidget);
    expect(find.text('BODY'), findsNothing);

    // Tap header → open → body revealed. 点头→展开→显体。
    await tester.tap(find.text('reasoning'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);

    // Tap again → collapse → body gone. 再点→收起→体没。
    await tester.tap(find.text('reasoning'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('trailing widget renders in the header', (tester) async {
    await tester.pumpWidget(
      host(
        AnDisclosure(
          label: 'shell.run',
          icon: AnIcons.tool,
          open: false,
          onToggle: () {},
          trailing: const AnChip('dangerous', tone: AnTone.danger),
          child: const Text('args'),
        ),
      ),
    );
    expect(find.text('shell.run'), findsOneWidget);
    expect(
      find.text('dangerous'),
      findsOneWidget,
    ); // trailing badge in header 尾随徽章在头
  });
}
