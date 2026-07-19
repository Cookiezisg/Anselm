import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/shell/ocean_breadcrumb.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5.5 gate (widget) — the floating-head breadcrumb is hidden + inert until the ocean reports the big
// title scrolled under the head (collapsed), then it fades in showing the title and fires onTap (scroll-to-top).

void main() {
  testWidgets('breadcrumb: opacity 0 + inert until collapsed, then shows the title + tap fires', (tester) async {
    var tapped = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: OceanBreadcrumb())),
        ),
      ),
    ));

    container.read(shellHeadProvider.notifier).bind('normalize', () => tapped = true);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0); // hidden until scrolled

    container.read(shellHeadProvider.notifier).setCollapsed(true);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1); // faded in
    expect(find.text('normalize'), findsOneWidget);

    await tester.tap(find.text('normalize'));
    expect(tapped, isTrue); // scroll-to-top
  });
}
