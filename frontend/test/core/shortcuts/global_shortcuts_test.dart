import 'dart:io';

import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:anselm/core/platform/window_zoom.dart';
import 'package:anselm/core/shell/oceans.dart';
import 'package:anselm/core/shell/right_panel.dart';
import 'package:anselm/core/shortcuts/global_shortcuts.dart';
import 'package:anselm/core/shortcuts/shortcut_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// GlobalShortcuts mounts the catalog-driven CallbackShortcuts ABOVE the autofocus Focus, so a global
// chord fires on cold start WITHOUT any click. Regression pin for the S6 bug where the shortcuts sat
// inside the shell (below focus) and were starved until the user clicked in.
// GlobalShortcuts 把目录 CallbackShortcuts 挂在 autofocus 之上,冷启动无需点击即可触发全局键。
void main() {
  // `cmd` maps to ⌘ on macOS / Ctrl elsewhere — send the modifier this host actually binds.
  final LogicalKeyboardKey cmdKey = Platform.isMacOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  testWidgets('a global chord fires on cold start via autofocus (no click)', (
    tester,
  ) async {
    final prefs = SettingsPrefs.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(
            body: GlobalShortcuts(
              child: Focus(autofocus: true, child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalShortcuts)),
      listen: false,
    );

    final before = container.read(shellChromeProvider).leftCollapsed;
    // Default toggle-left is ⌘B — send it with NOTHING clicked (only the autofocus node holds focus).
    // 默认 ⌘B——不点任何东西直接发(只有 autofocus 节点持焦点)。
    expect(
      kShortcutDefaults[ShortcutCommand.toggleLeftIsland]!.key,
      LogicalKeyboardKey.keyB,
    );
    await tester.sendKeyDownEvent(cmdKey);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(cmdKey);
    await tester.pumpAndSettle();

    expect(
      container.read(shellChromeProvider).leftCollapsed,
      !before,
      reason: '冷启动全局快捷键无需点击即生效',
    );
  });

  testWidgets('a rebound chord replaces the default one live', (tester) async {
    // Persist a ⌘J override for toggle-left, then prove ⌘J fires and the old ⌘B no longer does.
    // 持久化 ⌘J 覆写,证明 ⌘J 生效、旧 ⌘B 失效。
    final prefs = SettingsPrefs.inMemory({
      SettingsKeys.shortcuts.key:
          '{"toggleLeftIsland":"cmd+${LogicalKeyboardKey.keyJ.keyId}"}',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(
            body: GlobalShortcuts(
              child: Focus(autofocus: true, child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalShortcuts)),
      listen: false,
    );

    final base = container.read(shellChromeProvider).leftCollapsed;
    // Old default ⌘B must do NOTHING now. 旧默认 ⌘B 现在必须无效。
    await tester.sendKeyDownEvent(cmdKey);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(cmdKey);
    await tester.pumpAndSettle();
    expect(
      container.read(shellChromeProvider).leftCollapsed,
      base,
      reason: '改绑后旧默认键失效',
    );

    // The rebound ⌘J toggles it. 改绑后的 ⌘J 生效。
    await tester.sendKeyDownEvent(cmdKey);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(cmdKey);
    await tester.pumpAndSettle();
    expect(
      container.read(shellChromeProvider).leftCollapsed,
      !base,
      reason: '改绑键即时生效',
    );
  });
  // WRK-083 P07 — EVERY declared chord must reach its handler, not just the one ⌘B the suite happened
  // to pick. Real machine: ⌘B collapsed the island while ⌘− / ⌘= / ⌘0 appeared to do nothing, which
  // looks exactly like a broken zoom binding. This test asks the app itself, with no macOS and no
  // synthetic-input tooling in the loop, so the answer cannot be blamed on either.
  //
  // The zoom trio is asserted through [WindowZoom.factor] — the same notifier the scaled binding reads
  // — rather than through a provider, because that IS the observable the shortcut is supposed to move.
  //
  // WRK-083 P07——**每一条**声明过的和弦都必须抵达它的处理器,而不只是测试恰好挑中的那条 ⌘B。真机上 ⌘B 能折岛,
  // 而 ⌘− / ⌘= / ⌘0 看起来毫无反应——那看上去正像缩放绑定坏了。本测试**直接问 app 自己**,回路里既没有 macOS 也没有
  // 合成输入工具,故答案赖不到它们头上。
  //
  // 缩放三条断言在 [WindowZoom.factor] 上——那正是 scaled binding 读的那个 notifier,也正是快捷键**应该**推动的
  // 那个可观察量。
  testWidgets('every declared chord reaches its handler (P07)', (tester) async {
    final prefs = SettingsPrefs.inMemory();
    WindowZoom.useSettingsPrefs(prefs);
    addTearDown(() => WindowZoom.factor.value = 1.0);
    // A REAL-SIZED display: zoom-in is capped at `screen / designMin`, and the default 800x600 test
    // view makes that cap ~0.65 — so `⌘=` would legitimately refuse to move and the test would read
    // it as a broken binding. The cap is correct behaviour; the tiny view is the artefact.
    // 给一块**真实尺寸**的屏:zoom-in 的上限是「屏/设计min」,而默认 800x600 的测试视口把上限算成 ~0.65
    // ——于是 `⌘=` **正当地**拒绝移动,而测试会把它读成绑定坏了。封顶是对的行为,小视口才是假象。
    tester.view.physicalSize = const Size(3024, 1964);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(
            body: GlobalShortcuts(
              child: Focus(autofocus: true, child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalShortcuts)),
      listen: false,
    );

    Future<void> press(ShortcutCommand cmd) async {
      final chord = kShortcutDefaults[cmd]!;
      await tester.sendKeyDownEvent(cmdKey);
      await tester.sendKeyDownEvent(chord.key);
      await tester.sendKeyUpEvent(chord.key);
      await tester.sendKeyUpEvent(cmdKey);
      await tester.pumpAndSettle();
    }

    // ⌘\ — the right island. ⌘\ 右岛。
    final rightBefore = container.read(rightPanelCollapsedProvider);
    await press(ShortcutCommand.toggleRightIsland);
    expect(
      container.read(rightPanelCollapsedProvider),
      !rightBefore,
      reason: '⌘\\ 必须切右岛',
    );

    // ⌘, — settings. ⌘, 设置。
    await press(ShortcutCommand.openSettings);
    expect(
      container.read(selectedOceanProvider),
      OceanKind.settings,
      reason: '⌘, 必须进设置',
    );

    // ⌘− / ⌘= / ⌘0 — the zoom trio. 缩放三条。
    WindowZoom.factor.value = 1.0;
    await press(ShortcutCommand.zoomOut);
    expect(WindowZoom.factor.value, lessThan(1.0), reason: '⌘− 必须缩小');

    await press(ShortcutCommand.zoomIn);
    expect(WindowZoom.factor.value, 1.0, reason: '⌘= 必须放大回来');

    WindowZoom.factor.value = 0.8;
    await press(ShortcutCommand.zoomReset);
    expect(WindowZoom.factor.value, 1.0, reason: '⌘0 必须重置');
  });
}
