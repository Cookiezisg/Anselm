import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// AnDialog confirm route, driven through the REAL path: AnOverlayHost + AnOverlayController.confirm()
// pushed on the registered root navigator. Covers render, the four resolution paths (confirm / cancel
// / barrier / Escape — all framework-given), the safe autofocus (Enter never fires the destructive
// button), scopesRoute a11y, no-message, and injection. confirm 路由经真路径(host + controller)全覆盖。
void main() {
  late GlobalKey<NavigatorState> navKey;
  Future<bool>? result;

  Widget app({
    String? message,
    AnDialogTone tone = AnDialogTone.danger,
    String title = 'Delete?',
  }) {
    navKey = GlobalKey<NavigatorState>();
    result = null;
    return TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          navigatorKey: navKey,
          builder: (context, child) =>
              AnOverlayHost(navigatorKey: navKey, child: child!),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: AnButton(
                  label: 'open',
                  onPressed: () {
                    result = ref
                        .read(overlayProvider.notifier)
                        .confirm(
                          title: title,
                          message: message,
                          confirmLabel: 'Delete',
                          cancelLabel: 'Cancel',
                          barrierLabel: 'Dismiss dialog',
                          confirmTone: tone,
                        );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    String? message,
    AnDialogTone tone = AnDialogTone.danger,
  }) async {
    await tester.pumpWidget(app(message: message, tone: tone));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders title / message / cancel / confirm', (tester) async {
    await open(tester, message: 'This cannot be undone.');
    expect(find.text('Delete?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('confirm button → true', (tester) async {
    await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result!, isTrue);
  });

  testWidgets('cancel button → false', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result!, isFalse);
  });

  testWidgets('barrier tap → false (framework barrierDismissible)', (
    tester,
  ) async {
    await open(tester);
    await tester.tapAt(const Offset(8, 8)); // outside the centred card 卡外
    await tester.pumpAndSettle();
    expect(await result!, isFalse);
  });

  testWidgets('Escape → false (framework DismissIntent → maybePop)', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result!, isFalse);
  });

  testWidgets(
    'Enter fires the autofocused SAFE choice (cancel) → false, never the destructive one',
    (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        await result!,
        isFalse,
        reason:
            'cancel is autofocused so Enter cannot trigger a destructive confirm',
      );
    },
  );

  testWidgets('a11y: the title is reachable as a semantics label', (
    tester,
  ) async {
    // 'Delete?' surfaces as a label on both the title Text node and the named-route node (next test
    // asserts the latter's namesRoute flag specifically). 标题在 title 节点与具名路由节点上各现一次。
    final handle = tester.ensureSemantics();
    await open(tester, message: 'sure?');
    expect(find.bySemanticsLabel('Delete?'), findsWidgets);
    handle.dispose();
  });

  testWidgets('no message → no body; primary confirm still resolves true', (
    tester,
  ) async {
    await open(tester, tone: AnDialogTone.primary);
    expect(find.text('Delete?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result!, isTrue);
  });

  testWidgets(
    'special characters in the title render as plain text (no injection)',
    (tester) async {
      await tester.pumpWidget(app(title: '<b>x</b> & y'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('<b>x</b> & y'), findsOneWidget);
    },
  );

  // ── G6 adversarial-review additions ──

  testWidgets(
    'a11y: the modal route is NAMED by its title (namesRoute), not merely scoped',
    (tester) async {
      // RawDialogRoute gives scopesRoute but NOT a route name — without the card's own
      // Semantics(namesRoute, label) a screen reader entering the modal announces nothing. 路由命名须自补。
      final handle = tester.ensureSemantics();
      await open(tester, message: 'sure?');
      final named = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any(
            (s) =>
                s.properties.namesRoute == true &&
                s.properties.label == 'Delete?',
          );
      expect(
        named,
        isTrue,
        reason:
            'the confirm card must name the route off its title (namesRoute + label)',
      );
      handle.dispose();
    },
  );

  // A controller-driven harness (no trigger button) for the supersede / reduced paths. 直驱 controller 的壳。
  Widget ctrlApp(
    GlobalKey<NavigatorState> k,
    void Function(AnOverlayController) capture,
  ) => TranslationProvider(
    child: ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        navigatorKey: k,
        builder: (context, child) =>
            AnOverlayHost(navigatorKey: k, child: child!),
        home: Consumer(
          builder: (context, ref, _) {
            capture(ref.read(overlayProvider.notifier));
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );

  testWidgets(
    'a second confirm preempts the first: first→false, only one dialog on screen, second→true',
    (tester) async {
      final k = GlobalKey<NavigatorState>();
      late AnOverlayController ctrl;
      await tester.pumpWidget(ctrlApp(k, (c) => ctrl = c));
      final first = ctrl.confirm(
        title: 'First?',
        confirmLabel: 'OK',
        cancelLabel: 'Cancel',
        barrierLabel: 'Dismiss dialog',
      );
      await tester.pumpAndSettle();
      expect(find.text('First?'), findsOneWidget);
      final second = ctrl.confirm(
        title: 'Second?',
        confirmLabel: 'OK',
        cancelLabel: 'Cancel',
        barrierLabel: 'Dismiss dialog',
      );
      await tester.pumpAndSettle();
      expect(
        await first,
        isFalse,
        reason: 'the preempted stale dialog resolves false',
      );
      expect(
        find.text('First?'),
        findsNothing,
      ); // single-instance: stale popped 单实例
      expect(find.text('Second?'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await second, isTrue);
    },
  );

  testWidgets(
    'reduced-motion: dialog opens (transitionBuilder returns child) and settles, no throw',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final k = GlobalKey<NavigatorState>();
      late AnOverlayController ctrl;
      await tester.pumpWidget(ctrlApp(k, (c) => ctrl = c));
      final r = ctrl.confirm(
        title: 'Reduced?',
        message: 'x',
        confirmLabel: 'OK',
        cancelLabel: 'Cancel',
        barrierLabel: 'Dismiss dialog',
      );
      await tester.pumpAndSettle();
      expect(find.text('Reduced?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
    },
  );
}
