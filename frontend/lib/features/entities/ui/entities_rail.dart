import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../model/entity.dart';
import '../state/entities_providers.dart';

/// The 左岛 list for the Entities ocean: a "New" button + entities grouped into the four
/// rail groups (Logic / Control / Workflow / External), each kind shown with its icon, each
/// row selectable. Faithful to the demo's entities rail structure.
/// Entities 海洋的左岛列表:New + 四组(逻辑/控制/工作流/外部)分组实体,逐行可选。忠实于 demo。
class EntitiesRail extends ConsumerWidget {
  const EntitiesRail({super.key});

  static const _groups = <(String, List<EntityKind>)>[
    ('Logic', [EntityKind.function, EntityKind.handler, EntityKind.agent, EntityKind.trigger]),
    ('Control', [EntityKind.control, EntityKind.approval]),
    ('Workflow', [EntityKind.workflow]),
    ('External', [EntityKind.mcp, EntityKind.skill]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final listing = ref.watch(entityListProvider);
    final selected = ref.watch(selectedEntityIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s8),
          child: AnButton(
            label: 'New entity',
            icon: AnIcons.add,
            size: AnButtonSize.small,
            onPressed: () {},
          ),
        ),
        Expanded(
          child: listing.when(
            loading: () => const Center(child: AnSpinner()),
            error: (e, _) => Center(child: Text('$e', style: AnText.meta.copyWith(color: c.danger))),
            data: (items) {
              final byKind = <EntityKind, List<EntitySummary>>{};
              for (final e in items) {
                (byKind[e.kind] ??= []).add(e);
              }
              final tiles = <Widget>[];
              for (final (groupLabel, kinds) in _groups) {
                final present = kinds.where((k) => byKind[k]?.isNotEmpty ?? false).toList();
                if (present.isEmpty) continue;
                tiles.add(_groupHeader(c, groupLabel));
                for (final k in present) {
                  for (final e in byKind[k]!) {
                    tiles.add(AnRow(
                      leading: kindMeta[k]!.icon,
                      title: e.name,
                      selected: e.id == selected,
                      trailing: AnStatusDot(e.status),
                      onTap: () => ref.read(selectedEntityIdProvider.notifier).select(e.id),
                    ));
                  }
                }
              }
              return ListView(padding: const EdgeInsets.only(bottom: AnSpace.s8), children: tiles);
            },
          ),
        ),
      ],
    );
  }

  Widget _groupHeader(AnColors c, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(AnSpace.s8, AnSpace.s12, AnSpace.s8, AnSpace.s4),
        child: Text(label, style: AnText.label.copyWith(color: c.inkFaint)),
      );
}
