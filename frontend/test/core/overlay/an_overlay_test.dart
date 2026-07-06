import 'package:anselm/core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// AnOverlayController = the imperative-overlay service. Pure-logic unit tests via ProviderContainer
// (no widgets): toast append / unique id / soft cap 5 / dismiss / data carry, and confirm's safe
// default when no navigator is attached (the host-not-mounted path). Widget-level toast/dialog
// rendering lives in an_toast_test / an_dialog_test. controller 纯逻辑单测。
void main() {
  late ProviderContainer container;
  AnOverlayController ctrl() => container.read(overlayProvider.notifier);
  AnOverlayState st() => container.read(overlayProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('showToast appends in order and returns a unique id', () {
    final a = ctrl().showToast('one');
    final b = ctrl().showToast('two');
    expect(a, isNot(b));
    expect(st().toasts.map((t) => t.text), ['one', 'two']);
  });

  test('soft cap (3): over the cap drops the oldest (N3 = Sonner visible count)', () {
    for (var i = 0; i < 6; i++) {
      ctrl().showToast('t$i');
    }
    expect(st().toasts.length, AnOverlayController.maxToasts); // 3
    expect(st().toasts.first.text, 't3'); // t0..t2 evicted 最旧被挤掉
    expect(st().toasts.last.text, 't5');
  });

  test('dismissToast removes by id; unknown id is a no-op', () {
    final id = ctrl().showToast('x');
    ctrl().dismissToast('does-not-exist');
    expect(st().toasts.length, 1);
    ctrl().dismissToast(id);
    expect(st().toasts, isEmpty);
  });

  test('toast carries tone / action / duration', () {
    ctrl().showToast('a',
        tone: AnToastTone.danger,
        duration: Duration.zero,
        action: AnToastAction(label: 'undo', onPressed: () {}));
    final t = st().toasts.single;
    expect(t.tone, AnToastTone.danger);
    expect(t.duration, Duration.zero);
    expect(t.action?.label, 'undo');
  });

  test('confirm with no navigator attached resolves false (host not mounted)', () async {
    final ok = await ctrl().confirm(
      title: 't', confirmLabel: 'ok', cancelLabel: 'no', barrierLabel: 'b');
    expect(ok, isFalse);
  });
}
