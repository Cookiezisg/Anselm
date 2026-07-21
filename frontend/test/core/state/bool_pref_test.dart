import 'package:anselm/core/state/bool_pref.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = NotifierProvider<BoolPrefNotifier, bool>(
    () => BoolPrefNotifier(true),
  );

  test('starts at its default', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(p), isTrue);
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final q = NotifierProvider<BoolPrefNotifier, bool>(
      () => BoolPrefNotifier(false),
    );
    expect(c2.read(q), isFalse);
  });

  test('toggle flips; set forces (and is a no-op when unchanged)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(p.notifier).toggle();
    expect(c.read(p), isFalse);
    c.read(p.notifier).set(true);
    expect(c.read(p), isTrue);
    c.read(p.notifier).set(true); // unchanged
    expect(c.read(p), isTrue);
  });
}
