import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/contract/entities/relation.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/entities_overview_model.dart';
import '../../state/rel_graph_provider.dart';

/// The explore-state right-island card for the selected graph node — kind + name + vN + description, then
/// the RELATION GROUPS («装备了…» / «被…引用» / «链接…»), each row a tappable pill that flies-to that node in
/// the graph, then «打开详情 →» into the entity page. Reuses the archive-face PRIMITIVES (AnRefPill kind
/// identity + relation pills, AnKv description) rather than the JSON-shaped EntityGetBody composite — the
/// graph's data is EntityNode+EntityRow, not a tool-result blob. 探索态右岛卡:kind+名+vN+描述 + 关系分组
/// (点行 fly-to)+ 打开详情;复用档案脸原语(AnRefPill/AnKv),非 JSON 形的 EntityGetBody 复合件。
class GraphEntityCard extends ConsumerWidget {
  const GraphEntityCard({
    required this.sel,
    required this.onOpenNode,
    super.key,
  });

  final (String kind, String id)? sel;

  /// Fly-to a related node (select it + pan the graph). 飞到相关节点(选中 + 平移)。
  final void Function(String kind, String id) onOpenNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.entities.graph;
    final c = context.colors;
    if (sel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AnSpace.s16),
          child: Text(
            t.selectHint,
            textAlign: TextAlign.center,
            style: AnText.body.copyWith(color: c.inkFaint),
          ),
        ),
      );
    }
    final (kind, id) = sel!;
    final graph = ref.watch(relGraphProvider).value;
    final node = graph?.nodes.where((n) => n.id == id).firstOrNull;
    final name = (node?.name.isNotEmpty ?? false) ? node!.name : id;
    final groups = relationGroupsFor(id, graph?.edges ?? const []);

    // vN + description for the 7 rail kinds (the others have no row fetcher → name-only). 7 rail kind 取行。
    final railKind = entityKindFromWire(kind);
    final row = railKind == null
        ? null
        : ref.watch(entityRowFetchProvider((kind: railKind, id: id))).value;

    return ListView(
      // No horizontal pad — the [AnIsland]'s 12px is the sole island inset (single-source law); only
      // vertical. 水平 0:岛壳 12 即唯一岛级内距,仅纵向。
      padding: const EdgeInsets.only(top: AnSpace.s16, bottom: AnSpace.s24),
      children: [
        // Identity: kind glyph (kind-coloured) + name + vN. 身份:kind 字形(kind 色)+ 名 + vN。
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              AnIcons.entityKindGlyph(kind),
              size: AnSize.icon,
              color: entityKindColor(context, kind),
            ),
            const SizedBox(width: AnGap.inline),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AnText.body
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: c.ink),
              ),
            ),
            if (row?.version != null) ...[
              const SizedBox(width: AnGap.inline),
              AnChip('v${row!.version}', look: AnChipLook.outlined),
            ],
          ],
        ),
        const SizedBox(height: AnSpace.s4),
        Text(
          '${entityKindWord(context, kind)} · $id',
          style: AnText.meta.copyWith(color: c.inkFaint),
        ),
        if ((row?.description ?? '').isNotEmpty) ...[
          const SizedBox(height: AnSpace.s12),
          Text(
            row!.description,
            style: AnText.body.copyWith(color: c.inkMuted),
          ),
        ],

        // Relation groups. 关系分组。
        _group(context, t.groupEquips, groups.equips, outgoing: true),
        _group(
          context,
          t.groupReferencedBy,
          groups.referencedBy,
          outgoing: false,
        ),
        _group(context, t.groupLinks, groups.links, outgoing: true),
        if (groups.isEmpty) ...[
          const SizedBox(height: AnSpace.s16),
          Text(t.selectHint, style: AnText.meta.copyWith(color: c.inkFaint)),
        ],

        // Open the entity's own detail page (rail kinds only — the four accessory kinds live in other
        // oceans and have no entity page here). 打开实体详情(仅 rail kind)。
        if (railKind != null) ...[
          const SizedBox(height: AnSpace.s24),
          AnButton(
            label: t.openDetail,
            icon: AnIcons.chevronRight,
            onPressed: () => context.go(entityLocation(railKind, id)),
          ),
        ],
      ],
    );
  }

  /// One relation group: a heading + a wrap of tappable pills. [outgoing] picks the "other" endpoint —
  /// the `to` for equips/links, the `from` for referenced-by. Empty groups are omitted. 一组关系:标题 + 药丸墙。
  Widget _group(
    BuildContext context,
    String heading,
    List<EntityRelation> edges, {
    required bool outgoing,
  }) {
    if (edges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnGroupLabel(heading),
          const SizedBox(height: AnGap.stackTight),
          Wrap(
            spacing: AnGap.inline,
            runSpacing: AnGap.stackTight,
            children: [
              for (final e in edges)
                AnRefPill(
                  kind: outgoing ? e.toKind : e.fromKind,
                  id: outgoing ? e.toId : e.fromId,
                  label: outgoing
                      ? (e.toName.isEmpty ? e.toId : e.toName)
                      : (e.fromName.isEmpty ? e.fromId : e.fromName),
                  onTap: (target) => onOpenNode(target.kind, target.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
