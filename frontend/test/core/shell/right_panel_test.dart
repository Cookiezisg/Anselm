import 'package:anselm/core/shell/oceans.dart';
import 'package:anselm/core/shell/right_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// WRK-061 W0: the right-island collapse is a sticky preference BUCKETED PER OCEAN — collapsing the
// documents inspector must not leave the chat sidestage collapsed; each ocean remembers its own state
// across switches (session-scoped). 右岛收起按海洋分桶:documents 收起不连累 chat;各海洋跨切换自记。

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default: open (not collapsed) in every ocean', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(rightPanelCollapsedProvider), isFalse);
    c.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    expect(c.read(rightPanelCollapsedProvider), isFalse);
  });

  test('collapse in one ocean does NOT leak into another; each bucket sticks across switches', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    c.read(rightPanelCollapsedProvider.notifier).set(true);
    expect(c.read(rightPanelCollapsedProvider), isTrue);

    // Switch to chat — its bucket is untouched. 切 chat,桶不受染。
    c.read(selectedOceanProvider.notifier).select(OceanKind.chat);
    expect(c.read(rightPanelCollapsedProvider), isFalse);

    // Back to documents — its collapse stuck. 回 documents,收起仍在。
    c.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    expect(c.read(rightPanelCollapsedProvider), isTrue);
  });

  test('toggle flips only the current ocean\'s bucket', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedOceanProvider.notifier).select(OceanKind.entities);
    c.read(rightPanelCollapsedProvider.notifier).toggle();
    expect(c.read(rightPanelCollapsedProvider), isTrue);
    c.read(selectedOceanProvider.notifier).select(OceanKind.chat);
    expect(c.read(rightPanelCollapsedProvider), isFalse);
    c.read(rightPanelCollapsedProvider.notifier).toggle();
    c.read(rightPanelCollapsedProvider.notifier).toggle();
    expect(c.read(rightPanelCollapsedProvider), isFalse); // double toggle round-trips 双 toggle 归位
  });
}
