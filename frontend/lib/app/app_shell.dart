import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/an_inspector.dart';
import '../core/ui/an_shell.dart';
import '../features/entities/state/run/run_terminal_controller.dart';
import '../features/entities/ui/entity_ocean.dart';
import '../features/entities/ui/entity_rail.dart';
import '../features/entities/ui/run/run_terminal.dart';

/// THE single shell composition — which feature sits in which island. Mounted by BOTH entries so the
/// real app and the demo never diverge: `lib/main.dart` (→ `make app`) wraps it in the startup gate and
/// feeds it the LIVE repositories; `lib/dev/demo_main.dart` (→ `make demo`) skips the gate and overrides
/// the repository seam with fixtures. App vs demo differ ONLY in data source + startup — the layout is
/// defined exactly once, here. New features wire into this one widget (never a per-feature run target).
///
/// The right island is the run terminal: it reveals when a verb CTA opens it (`runTerminalProvider.open`)
/// and slides away when closed. Both the ocean (verb CTA) and this shell watch the one controller.
///
/// 唯一的壳组合——哪个 feature 在哪个岛。两个入口都挂它,使真 app 与 demo 永不分叉。右岛=run 终端:动词 CTA
/// 打开时揭示(runTerminalProvider.open)、关闭时滑走;海洋与本壳都 watch 同一控制器。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(runTerminalProvider.select((s) => s.open));
    return AnShell(
      sidebar: const EntityRail(),
      ocean: const EntityOcean(),
      inspector: const AnInspector(headless: true, child: RunTerminal()),
      inspectorOpen: open,
    );
  }
}
