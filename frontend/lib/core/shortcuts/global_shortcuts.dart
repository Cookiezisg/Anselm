import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/window_zoom.dart';
import '../shell/oceans.dart';
import '../shell/right_panel.dart';
import '../shell/shell_chrome.dart';
import 'shortcut_bindings.dart';
import 'shortcut_catalog.dart';

/// The global command shortcuts (WRK-062 S6) — the [CallbackShortcuts] built from the rebindable
/// [shortcutBindingsProvider] catalog. It is mounted at the APP ROOT, ABOVE the autofocus [Focus], on
/// purpose: a [CallbackShortcuts] only fires for key events that bubble UP from a focused descendant, so
/// the focused node must sit BELOW it. Mounting it inside the shell (below the autofocus node) starves
/// every global chord on cold start until the user first clicks into the shell — the exact regression
/// this widget fixes. Every handler is a pure provider/static call, so no shell BuildContext is needed.
///
/// 全局命令快捷键(S6):由可改绑目录 [shortcutBindingsProvider] 生成的 CallbackShortcuts,挂在 **app 根、
/// autofocus Focus 之上**——CallbackShortcuts 只对「从持焦点子孙冒泡上来的按键」触发,故持焦点节点须在其
/// 之下。若挂进壳内(autofocus 节点之下),冷启动首帧全局键全被饿死、要先点一下壳才活(本 widget 修的正是
/// 这个回归)。每个 handler 都是纯 provider/静态调用,无需壳 BuildContext。
class GlobalShortcuts extends ConsumerWidget {
  const GlobalShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chords = ref.watch(shortcutBindingsProvider);
    final handlers = <ShortcutCommand, VoidCallback>{
      ShortcutCommand.toggleLeftIsland: () =>
          ref.read(shellChromeProvider.notifier).toggleLeft(),
      ShortcutCommand.toggleRightIsland: () =>
          ref.read(rightPanelCollapsedProvider.notifier).toggle(),
      // Mirror the shell's selectOcean side-effect: picking settings dismisses the notifications tray.
      // 镜像壳的 selectOcean:选 settings 顺手收起通知托盘。
      ShortcutCommand.openSettings: () {
        ref.read(selectedOceanProvider.notifier).select(OceanKind.settings);
        ref.read(notificationsOpenProvider.notifier).close();
      },
      ShortcutCommand.zoomIn: WindowZoom.zoomIn,
      ShortcutCommand.zoomOut: WindowZoom.zoomOut,
      ShortcutCommand.zoomReset: WindowZoom.reset,
    };
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        for (final e in handlers.entries) chords[e.key]!.toActivator(): e.value,
      },
      child: child,
    );
  }
}
