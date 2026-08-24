import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_attachment_chip.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('failed chip exposes its state and retry action to semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnAttachmentChip(
          kind: 'image',
          filename: 'broken.png',
          meta: 'Failed — tap to retry',
          failed: true,
          onRetry: () {},
          onRemove: () {},
          removeLabel: 'Remove attachment',
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('broken.png, Failed — tap to retry'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Remove attachment'), findsOneWidget);
  });

  testWidgets('preparing chip exposes the named preparation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnAttachmentChip(
          kind: 'image',
          filename: 'large.png',
          meta: 'Preparing media…',
          actionIcon: Icons.stop,
          actionLabel: 'Cancel media preparation',
          onAction: () {},
          onRemove: () {},
          removeLabel: 'Remove attachment',
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('large.png, Preparing media…'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Cancel media preparation'), findsOneWidget);
  });
}
