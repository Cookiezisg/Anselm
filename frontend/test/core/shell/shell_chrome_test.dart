import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// STEP 5.5 gate — shell chrome state: left collapse + drag width persist (shared_preferences), and the
// floating-head breadcrumb (bind / scroll-collapse / clear, collapse flag independent of the bound title).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggleLeft flips + persists', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(shellChromeProvider).leftCollapsed, isFalse);
    c.read(shellChromeProvider.notifier).toggleLeft();
    expect(c.read(shellChromeProvider).leftCollapsed, isTrue);
    await pumpEventQueue();
    expect((await SharedPreferences.getInstance()).getBool('fy.side.collapsed'), isTrue);
  });

  test('setLeftWidth clamps to [min, max] + persists', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(shellChromeProvider.notifier).setLeftWidth(999);
    expect(c.read(shellChromeProvider).leftWidth, AnSize.sidebarMax);
    c.read(shellChromeProvider.notifier).setLeftWidth(100);
    expect(c.read(shellChromeProvider).leftWidth, AnSize.sidebarMin);
    await pumpEventQueue();
    expect((await SharedPreferences.getInstance()).getDouble('fy.side.w'), AnSize.sidebarMin);
  });

  test('restore reads the persisted collapsed + width', () async {
    SharedPreferences.setMockInitialValues({'fy.side.collapsed': true, 'fy.side.w': 360.0});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(shellChromeProvider); // trigger build → async _restore
    await pumpEventQueue();
    expect(c.read(shellChromeProvider).leftCollapsed, isTrue);
    expect(c.read(shellChromeProvider).leftWidth, 360.0);
  });

  test('shellHead: bind sets title (collapsed false), setCollapsed preserves title, clear resets', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(shellHeadProvider.notifier);
    n.bind('normalize', () {});
    expect(c.read(shellHeadProvider).title, 'normalize');
    expect(c.read(shellHeadProvider).collapsed, isFalse);
    n.setCollapsed(true);
    expect(c.read(shellHeadProvider).collapsed, isTrue);
    expect(c.read(shellHeadProvider).title, 'normalize'); // title preserved across collapse
    n.clear();
    expect(c.read(shellHeadProvider).title, '');
    expect(c.read(shellHeadProvider).collapsed, isFalse);
  });
}
