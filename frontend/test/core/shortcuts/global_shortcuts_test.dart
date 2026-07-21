import 'dart:io';

import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
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
}
