import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5.5 gate — shell chrome state: left collapse + drag width persist (via SettingsPrefs,
// WRK-062 S-13 收编), and the floating-head breadcrumb (bind / scroll-collapse / clear, collapse
// flag independent of the bound title).

ProviderContainer _container(SettingsPrefs prefs) {
  final c = ProviderContainer(
    overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleLeft flips + persists', () {
    final prefs = SettingsPrefs.inMemory();
    final c = _container(prefs);
    expect(c.read(shellChromeProvider).leftCollapsed, isFalse);
    c.read(shellChromeProvider.notifier).toggleLeft();
    expect(c.read(shellChromeProvider).leftCollapsed, isTrue);
    expect(prefs.getBool(SettingsKeys.sideCollapsed), isTrue);
  });

  test('setLeftWidth clamps to [min, max] + persists', () {
    final prefs = SettingsPrefs.inMemory();
    final c = _container(prefs);
    c.read(shellChromeProvider.notifier).setLeftWidth(999);
    expect(c.read(shellChromeProvider).leftWidth, AnSize.sidebarMax);
    c.read(shellChromeProvider.notifier).setLeftWidth(100);
    expect(c.read(shellChromeProvider).leftWidth, AnSize.sidebarMin);
    expect(prefs.getDouble(SettingsKeys.sideWidth), AnSize.sidebarMin);
  });

  test(
    'restore reads the persisted collapsed + width SYNCHRONOUSLY at build',
    () {
      final prefs = SettingsPrefs.inMemory({
        'an.side.collapsed': true,
        'an.side.w': 360.0,
      });
      final c = _container(prefs);
      expect(c.read(shellChromeProvider).leftCollapsed, isTrue);
      expect(c.read(shellChromeProvider).leftWidth, 360.0);
    },
  );

  test(
    'setRightWidth clamps to [min, max] + persists (WRK-061: user-owned right width)',
    () {
      final prefs = SettingsPrefs.inMemory();
      final c = _container(prefs);
      expect(
        c.read(shellChromeProvider).rightWidth,
        AnSize.rightIsland,
      ); // default 默认
      c.read(shellChromeProvider.notifier).setRightWidth(9999);
      expect(c.read(shellChromeProvider).rightWidth, AnSize.rightIslandMax);
      c.read(shellChromeProvider.notifier).setRightWidth(10);
      expect(c.read(shellChromeProvider).rightWidth, AnSize.rightIslandMin);
      expect(prefs.getDouble(SettingsKeys.rightWidth), AnSize.rightIslandMin);
    },
  );

  test(
    'restore reads the persisted right width (bad values fall back to default)',
    () {
      final c = _container(SettingsPrefs.inMemory({'an.side.rightw': 480.0}));
      expect(c.read(shellChromeProvider).rightWidth, 480.0);

      final c2 = _container(
        SettingsPrefs.inMemory({'an.side.rightw': 9999.0}),
      ); // out of range 越界
      expect(c2.read(shellChromeProvider).rightWidth, AnSize.rightIsland);
    },
  );

  test(
    'shellHead: bind sets title AND PRESERVES collapsed (mid-scroll rebinds must not pop the head), clear resets',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(shellHeadProvider.notifier);
      n.bind('normalize', () {});
      expect(c.read(shellHeadProvider).title, 'normalize');
      expect(c.read(shellHeadProvider).collapsed, isFalse);
      n.setCollapsed(true);
      expect(c.read(shellHeadProvider).collapsed, isTrue);
      expect(
        c.read(shellHeadProvider).title,
        'normalize',
      ); // title preserved across collapse
      // The load-bearing new contract: oceans re-bind post-frame on EVERY data rebuild (rename / SSE
      // refetch) — bind keeps collapsed so a mid-scroll rebind cannot pop the breadcrumb open; the
      // ocean/selection switch resets it explicitly (clear / setCollapsed(false) in the listeners).
      // 新契约要害:海洋每次数据重建都重绑——bind 保留 collapsed,滚动中重绑不得弹开;换海洋/选区才显式复位。
      n.bind('renamed', () {});
      expect(c.read(shellHeadProvider).title, 'renamed');
      expect(
        c.read(shellHeadProvider).collapsed,
        isTrue,
        reason: 'bind must preserve collapsed',
      );
      n.clear();
      expect(c.read(shellHeadProvider).title, '');
      expect(c.read(shellHeadProvider).collapsed, isFalse);
    },
  );
}
