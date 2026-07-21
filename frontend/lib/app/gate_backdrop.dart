import 'package:flutter/material.dart';

import '../core/design/colors.dart';

/// The full-canvas backdrop shared by the two startup gates ([AppStartupGate] backend-ready +
/// [WorkspaceGate] cold-start) — a canvas-coloured [Material] over which the loading / fatal [AnState]
/// self-centres, caps, and pads. Extracted so the two gates share one backdrop, not a copied helper.
///
/// 两道启动 gate(后端就绪 + 冷启动工作区)共用的满屏底:canvas 色 Material,内层 AnState 自居中/限宽/留白。
class GateBackdrop extends StatelessWidget {
  const GateBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(color: context.colors.canvas, child: child);
}
