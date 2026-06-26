import 'package:flutter/widgets.dart';

import '../core/ui/an_shell.dart';
import '../features/entities/ui/entity_ocean.dart';
import '../features/entities/ui/entity_rail.dart';

/// THE single shell composition — which feature sits in which island. Mounted by BOTH entries so the
/// real app and the demo never diverge: `lib/main.dart` (→ `make app`) wraps it in the startup gate and
/// feeds it the LIVE repositories; `lib/dev/demo_main.dart` (→ `make demo`) skips the gate and overrides
/// the repository seam with fixtures. App vs demo differ ONLY in data source + startup — the layout is
/// defined exactly once, here. New features wire into this one widget (never a per-feature run target).
///
/// 唯一的壳组合——哪个 feature 在哪个岛。两个入口都挂它,使真 app 与 demo 永不分叉:main.dart(make app)
/// 裹启动门控 + 真 repository;demo_main.dart(make demo)跳门控 + fixture override 数据缝。app 与 demo
/// 只差「数据源 + 启动」,布局只在此定义一次。新 feature 接进这一个 widget(绝不再加 per-feature 入口)。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    // inspector (right island) joins when a feature needs it; until then the ocean holds detail.
    // 右岛待有 feature 需要时再挂;在此之前详情在海洋。
    return const AnShell(
      sidebar: EntityRail(),
      ocean: EntityOcean(),
      inspectorOpen: false,
    );
  }
}
