import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/shell/ocean_breadcrumb.dart';
import '../core/shell/shell_chrome.dart';
import '../core/ui/an_inspector.dart';
import '../core/ui/an_shell.dart';
import '../features/entities/state/run/right_panel.dart';
import '../features/entities/state/selected_entity.dart';
import '../features/entities/ui/entity_ocean.dart';
import '../features/entities/ui/entity_rail.dart';
import '../features/entities/ui/run/run_terminal.dart';

/// THE single shell composition — which feature sits in which island. Mounted by BOTH entries so the real
/// app and the demo never diverge (`lib/main.dart` → `make app` with live repos behind the startup gate;
/// `lib/dev/demo_main.dart` → `make demo` with fixtures, no gate). App vs demo differ ONLY in data + startup.
///
/// Wires the shell chrome to the app providers: the LEFT island collapse/width ([shellChromeProvider],
/// persisted), the OCEAN floating-head breadcrumb ([OceanBreadcrumb] over [shellHeadProvider], fed by the
/// ocean's scroll), and the RIGHT island reveal — strong-linked to the selection (reveals whenever an
/// entity is selected and the panel isn't manually collapsed; the run terminal re-binds to the selection).
/// ⌘B / ⌘\ toggle the panels (the autofocus anchor in app.dart keeps them live from launch).
///
/// 唯一壳组合。把壳 chrome 接到 app provider:左岛收起/宽度(持久化)· 海洋浮层头面包屑(随海洋滚动)· 右岛揭示
/// (强链选区:有选中且未手动收起即揭示,run 终端随选区重绑)。⌘B/⌘\ 切换左右岛(app.dart autofocus 锚使开机即生效)。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = ref.watch(selectedEntityProvider) != null;
    final rightCollapsed = ref.watch(rightPanelCollapsedProvider);
    final chrome = ref.watch(shellChromeProvider);

    void toggleLeft() => ref.read(shellChromeProvider.notifier).toggleLeft();
    void toggleRight() =>
        ref.read(rightPanelCollapsedProvider.notifier).toggle();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): toggleLeft,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            toggleLeft,
        const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
            toggleRight,
        const SingleActivator(LogicalKeyboardKey.backslash, control: true):
            toggleRight,
      },
      child: AnShell(
        sidebar: const EntityRail(),
        ocean: const EntityOcean(),
        inspector: const AnInspector(headless: true, child: RunTerminal()),
        inspectorOpen: hasSelection && !rightCollapsed,
        leftCollapsed: chrome.leftCollapsed,
        leftWidth: chrome.leftWidth,
        onToggleLeft: toggleLeft,
        onLeftWidthCommitted: (w) =>
            ref.read(shellChromeProvider.notifier).setLeftWidth(w),
        head: const OceanBreadcrumb(),
        // titlebarHeight defaults to AnSize.titlebar (the lights-centering band, real-run verified). 用默认带高。
        // The panel-right toggle exists only when an entity is selected (a bound right island). 仅有选中时给右切换。
        onToggleRight: hasSelection ? toggleRight : null,
      ),
    );
  }
}
