import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// AnToast = one presentational toast chip (self-owned enter/exit animation + auto-dismiss timer).
// Here: render (text / tone / action / close), liveRegion a11y (polite, never focus-stealing), the
// dismiss paths (close tap, auto-dismiss timer, sticky Duration.zero), reduced-motion timer-decoupling,
// and injection/overflow stress. The controller's stack logic is an_overlay_test. AnToast 渲染/语义/消隐/压力。
void main() {
  Widget host(Widget child, {double width = 460}) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  testWidgets('renders text + a dismissible close button', (tester) async {
    await tester.pumpWidget(
      host(AnToast(text: 'Saved', duration: Duration.zero, onDismissed: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
  });

  testWidgets(
    'a11y: a polite liveRegion labelled with the text (never focus-stealing)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final probe = FocusNode();
      addTearDown(probe.dispose);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              Focus(
                focusNode: probe,
                autofocus: true,
                child: const SizedBox(width: 10, height: 10),
              ),
              AnToast(
                text: 'Announced',
                duration: Duration.zero,
                onDismissed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // liveRegion sits on the text node (polite announce); the close button is a SEPARATE node (not merged). liveRegion 在文字节点。
      expect(find.bySemanticsLabel('Announced'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Announced')),
        isSemantics(isLiveRegion: true),
      );
      expect(
        find.bySemanticsLabel('Dismiss'),
        findsOneWidget,
      ); // close stays a discoverable button 关钮独立可达
      expect(
        probe.hasFocus,
        isTrue,
        reason: 'a toast must not steal focus on appear',
      );
      handle.dispose();
    },
  );

  testWidgets(
    'close tap dismisses (onDismissed fires after the exit animation)',
    (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        host(
          AnToast(
            text: 'x',
            duration: Duration.zero,
            onDismissed: () => dismissed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      expect(
        dismissed,
        isFalse,
        reason: 'not until the exit animation finishes',
      ); // mid-exit
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets('auto-dismiss after its duration', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(
        AnToast(
          text: 'x',
          duration: const Duration(milliseconds: 100),
          onDismissed: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(); // enter + arm timer
    await tester.pump(
      const Duration(milliseconds: 150),
    ); // timer fires → exit starts
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets(
    'Duration.zero = sticky (no auto-dismiss, close-only — WCAG 2.2.1)',
    (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        host(
          AnToast(
            text: 'sticky',
            duration: Duration.zero,
            onDismissed: () => dismissed = true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(dismissed, isFalse);
      expect(find.text('sticky'), findsOneWidget);
    },
  );

  testWidgets('action button renders, fires its callback, then dismisses', (
    tester,
  ) async {
    var acted = false;
    var dismissed = false;
    await tester.pumpWidget(
      host(
        AnToast(
          text: 'Deleted',
          duration: Duration.zero,
          action: AnToastAction(label: 'Undo', onPressed: () => acted = true),
          onDismissed: () => dismissed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(acted, isTrue);
    expect(dismissed, isTrue);
  });

  testWidgets('reduced-motion: timer still runs, exit is instant', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: host(
          AnToast(
            text: 'x',
            duration: const Duration(milliseconds: 100),
            onDismissed: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pump(); // enter (instant under reduced)
    await tester.pump(
      const Duration(milliseconds: 150),
    ); // timer fires → instant reverse
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('special characters render as plain text (no injection)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AnToast(
          text: '<b>not</b> & x',
          duration: Duration.zero,
          onDismissed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('<b>not</b> & x'), findsOneWidget);
  });

  testWidgets('long text wraps/ellipsizes without overflow', (tester) async {
    await tester.pumpWidget(
      host(
        AnToast(
          text:
              'a really long toast message that should wrap to two lines then ellipsize and never overflow the chip',
          duration: Duration.zero,
          onDismissed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── G6 adversarial-review addition: the real host + soft-cap eviction path (zero widget coverage before) ──
  testWidgets(
    'soft cap via the real host: 8 fired → 5 shown, evicting a mid-enter toast is safe, settles',
    (tester) async {
      final k = GlobalKey<NavigatorState>();
      late AnOverlayController ctrl;
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              navigatorKey: k,
              builder: (context, child) =>
                  AnOverlayHost(navigatorKey: k, child: child!),
              home: Consumer(
                builder: (context, ref, _) {
                  ctrl = ref.read(overlayProvider.notifier);
                  return const Scaffold(body: SizedBox.shrink());
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        ctrl.showToast('n$i');
      }
      await tester
          .pump(); // evictions fire here, while survivors are mid-enter — disposing the evicted must be safe
      expect(tester.takeException(), isNull);
      expect(
        find.byType(AnToast),
        findsNWidgets(AnOverlayController.maxToasts),
      ); // 8 → 5
      await tester.pumpAndSettle(); // enters complete, no leftover ticker
      expect(tester.takeException(), isNull);
      // Drain the 4s auto-dismiss timers so none stay pending at teardown. 排空计时器。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
