import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_kind.dart';
import '../state/selected_entity.dart';

/// The detail "ocean" for the selected entity (the open window surface between the islands). STEP 3
/// ships a PLACEHOLDER: empty-state when nothing is selected, a minimal kind+id card once a rail row is
/// picked — proving the rail → selection → ocean axis end to end. STEP 4 replaces the body with the
/// real detail sea (AnOceanHeader + AnTabs 概览/版本/日志). 详情海洋(STEP 3 占位,STEP 4 建真详情)。
class EntityOcean extends ConsumerWidget {
  const EntityOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEntityProvider);
    final t = context.t;

    if (selected == null) {
      return Center(
        child: AnState(
          kind: AnStateKind.empty,
          title: t.entities.selectTitle,
          hint: t.entities.selectHint,
        ),
      );
    }

    final c = context.colors;
    final kindLabel = switch (selected.kind) {
      EntityKind.function => t.ref.function,
      EntityKind.handler => t.ref.handler,
      EntityKind.agent => t.ref.agent,
      EntityKind.workflow => t.ref.workflow,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kindLabel, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
          Text(selected.id, style: AnText.body.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
