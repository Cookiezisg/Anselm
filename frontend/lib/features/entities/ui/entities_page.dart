import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/ui.dart';
import '../model/entity.dart';
import '../state/entities_providers.dart';
import 'entity_sections.dart';

/// The 海洋 detail for the selected entity: a big ocean header (crumb / title / status badge
/// / verb CTA + more) over the schema-driven sections. Goes inside the shell's AnPage.
/// 选中实体的海洋详情:大页头(面包屑/标题/状态徽/动词 CTA + …)压 schema 驱动的段落。置于 shell 的 AnPage 内。
class EntitiesPage extends ConsumerWidget {
  const EntitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEntityProvider);
    // Cross-fade the detail when the selected entity changes (standard content transition).
    // 切换实体时详情交叉淡入(标准内容转场)。
    return AnimatedSwitcher(
      duration: AnMotion.mid,
      switchInCurve: AnMotion.easeOut,
      child: selected.when(
        loading: () => const Padding(
          key: ValueKey('loading'),
          padding: EdgeInsets.only(top: AnSpace.s48),
          child: Center(child: AnSpinner()),
        ),
        error: (e, _) => Padding(
          key: const ValueKey('error'),
          padding: const EdgeInsets.only(top: AnSpace.s48),
          child: AnEmptyState(icon: AnIcons.error, title: 'Failed to load', hint: '$e'),
        ),
        data: (detail) {
          if (detail == null) {
            return const Padding(
              key: ValueKey('empty'),
              padding: EdgeInsets.only(top: AnSpace.s48),
              child: AnEmptyState(
                icon: AnIcons.entities,
                title: 'Select an entity',
                hint: 'Pick a function, agent, workflow, or other entity from the left.',
              ),
            );
          }
          final s = detail.summary;
          final meta = kindMeta[s.kind]!;
          return Column(
            key: ValueKey(s.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            AnOceanHeader(
              crumb: ['Entities', meta.label],
              title: s.name,
              actions: [
                if (meta.verb != null)
                  AnButton(
                    label: meta.verb!,
                    icon: meta.icon,
                    variant: AnButtonVariant.primary,
                    onPressed: () {},
                  ),
                AnIconButton(AnIcons.iterate, tooltip: 'Iterate with AI', onPressed: () {}),
                AnIconButton(AnIcons.more, tooltip: 'More', onPressed: () {}),
              ],
              meta: [
                if (s.meta != null) AnBadge(s.meta!, tone: _tone(s.status)),
              ],
            ),
            EntitySections(kind: s.kind, data: detail.data),
          ],
        );
      },
      ),
    );
  }

  AnBadgeTone _tone(AnStatus s) => switch (s) {
        AnStatus.done => AnBadgeTone.ok,
        AnStatus.wait => AnBadgeTone.warn,
        AnStatus.err => AnBadgeTone.danger,
        AnStatus.run => AnBadgeTone.accent,
        AnStatus.idle => AnBadgeTone.neutral,
      };
}
