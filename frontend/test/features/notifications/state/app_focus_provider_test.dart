import 'package:anselm/features/notifications/state/app_focus_provider.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The app-focus signal. Pins: defaults focused (safe startup), tracks resumed↔blurred lifecycle.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to focused, then tracks the lifecycle', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appFocusedProvider), isTrue); // safe default at startup

    c
        .read(appFocusedProvider.notifier)
        .debugSetLifecycle(AppLifecycleState.paused);
    expect(c.read(appFocusedProvider), isFalse); // window blurred/backgrounded

    c
        .read(appFocusedProvider.notifier)
        .debugSetLifecycle(AppLifecycleState.resumed);
    expect(c.read(appFocusedProvider), isTrue); // focused again
  });
}
