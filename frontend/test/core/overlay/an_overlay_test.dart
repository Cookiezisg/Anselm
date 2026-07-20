import 'package:anselm/core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Overlay is intentionally dialog-only; immediate feedback is covered by notice_center_test.
// overlay 刻意只剩确认框;即时反馈由 notice_center_test 覆盖。
void main() {
  test(
    'confirm with no navigator attached resolves false (safe default)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ok = await container
          .read(overlayProvider.notifier)
          .confirm(
            title: 't',
            confirmLabel: 'ok',
            cancelLabel: 'no',
            barrierLabel: 'b',
          );
      expect(ok, isFalse);
    },
  );
}
