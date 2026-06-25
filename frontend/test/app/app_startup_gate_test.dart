import 'package:anselm/app/app_startup_gate.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/process/backend_controller.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 6 gate — the app gates on the backend's single phase. Override backendStartupProvider with a
// fixed state per phase and assert the right screen (no real sidecar). Proves the whole-app gate +
// override injection (the DI seam the rest of the app depends on).

/// A backendStartupProvider override that returns a fixed state and a no-op retry (no controller).
class _FixedStartup extends BackendStartup {
  _FixedStartup(this._s);
  final BackendState _s;
  @override
  BackendState build() => _s;
  @override
  void retry() {} // no controller in the render test
}

Widget _app(BackendState st) => ProviderScope(
      overrides: [backendStartupProvider.overrideWith(() => _FixedStartup(st))],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: const AppStartupGate(child: Text('SHELL', key: Key('shell'))),
        ),
      ),
    );

void main() {
  testWidgets('starting → connecting screen, shell hidden', (tester) async {
    await tester.pumpWidget(_app(const BackendState(BackendPhase.starting)));
    expect(find.text(t.startup.connecting), findsOneWidget);
    expect(find.byKey(const Key('shell')), findsNothing);
  });

  testWidgets('ready → shell shown', (tester) async {
    await tester.pumpWidget(_app(const BackendState(BackendPhase.ready, baseUrl: 'http://127.0.0.1:1')));
    expect(find.byKey(const Key('shell')), findsOneWidget);
    expect(find.text(t.startup.connecting), findsNothing);
  });

  testWidgets('crashed → crashed screen with error + Retry, shell hidden', (tester) async {
    await tester.pumpWidget(_app(const BackendState(BackendPhase.crashed, error: 'backend binary not found')));
    expect(find.text(t.startup.crashedTitle), findsOneWidget);
    expect(find.text('backend binary not found'), findsOneWidget); // the error detail surfaces
    expect(find.text(t.startup.retry), findsOneWidget);
    expect(find.byKey(const Key('shell')), findsNothing);
    // Retry is tappable without throwing (no-op in this override).
    await tester.tap(find.text(t.startup.retry));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
