import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import 'an_skeleton.dart';

/// The first-load placeholder for a left-island rail — a few bone rows under the chrome zone. Shared by
/// every rail (entities, chat, …) so the shape reads identically and isn't hand-copied per feature. Pair
/// with [AnDeferredLoading] at the call site so a fast first load never flashes it.
///
/// 左岛 rail 首载占位:chrome 区下数行骨架。各 rail(实体/对话/…)共用,形状一致、不再逐 feature 手抄。
/// 调用处配 AnDeferredLoading,快速首载不闪。
class AnRailSkeleton extends StatelessWidget {
  const AnRailSkeleton({this.rows = 5, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: AnSpace.s8),
            const AnSkeleton.row(),
          ],
        ],
      ),
    );
  }
}
