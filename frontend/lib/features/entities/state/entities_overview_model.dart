import '../../../core/contract/entities/relation.dart';
import '../data/entity_kind.dart';
import '../data/entity_row.dart';
import 'rail_model.dart';

/// Pure projections for the Entities Overview page — headless-testable, no widget/provider. 纯投影,可无头测。

/// The OBSERVING subgraph: only structural edges (equip/link) + the nodes they touch. create/edit
/// provenance edges and the conversation nodes they hang off are dropped here (every entity trailing an
/// umbilical to its birth conversation is a hairball amplifier — the "show provenance" toggle re-admits
/// them in the explore state). An entity with no structural edge simply isn't a structural node.
/// 观赏子图:只留结构边 equip/link + 其端点节点;溯源 create/edit 边 + 对话节点在此丢弃(每个实体拖脐带连出生
/// 对话=毛线球放大器;探索态「显示溯源」再纳入)。无结构边的实体不是结构节点。
({List<EntityNode> nodes, List<EntityRelation> edges}) structuralSubgraph(EntityRelGraph g) {
  final edges = [
    for (final e in g.edges)
      if (e.kind == 'equip' || e.kind == 'link') e,
  ];
  final ids = <String>{
    for (final e in edges) ...[e.fromId, e.toId],
  };
  final nodes = [
    for (final n in g.nodes)
      if (ids.contains(n.id)) n,
  ];
  return (nodes: nodes, edges: edges);
}

/// The five-card counts — the four Quadrinity + the accessory total (trigger+control+approval). Counts
/// come from the (SSE-live) rail groups, so they track the same numbers the rail badges show. Zero is a
/// real answer (the clip is a constant structure, not a vanity number). 五牌计数:四大 + 配件合计,取自 rail 组。
class OverviewCounts {
  const OverviewCounts({
    required this.function,
    required this.handler,
    required this.agent,
    required this.workflow,
    required this.accessory,
  });

  final int function;
  final int handler;
  final int agent;
  final int workflow;

  /// trigger + control + approval combined — the three support kinds fold into one "Parts" tile. 配件合计。
  final int accessory;
}

OverviewCounts overviewCounts(List<RailGroup> groups) {
  int of(EntityKind k) => groups.where((g) => g.kind == k).fold(0, (a, g) => a + g.count);
  return OverviewCounts(
    function: of(EntityKind.function),
    handler: of(EntityKind.handler),
    agent: of(EntityKind.agent),
    workflow: of(EntityKind.workflow),
    accessory: of(EntityKind.trigger) + of(EntityKind.control) + of(EntityKind.approval),
  );
}

/// The «最近更新» top-N across ALL kinds by updatedAt desc. Merges the rail groups' loaded rows (the rail
/// already sorts its own default view this way — see rail_sort.dart's `recent`), so the Overview's recent
/// list is exactly consistent with the rail's notion of recent. Name is the stable tiebreak so the order
/// is deterministic. 跨 kind 按 updatedAt desc 取 top-N:合并 rail 已载行(与 rail 默认 recent 排序一致),名字破平局。
/// The explore-state right-island card's relation grouping for one node id: what it EQUIPS (outgoing
/// equip), what REFERENCES it (incoming equip + link — the "删了它什么会坏" dependents), and what it LINKS
/// (outgoing link, e.g. a document's `[[id]]` wikilinks). Pure. 探索态右岛卡的关系分组:装备了(出 equip)/
/// 被引用(入 equip+link)/链接(出 link)。
class RelationGroups {
  const RelationGroups({required this.equips, required this.referencedBy, required this.links});

  /// Outgoing `equip` — the entities this node mounts. 出向 equip(它挂载的)。
  final List<EntityRelation> equips;

  /// Incoming `equip`+`link` — who depends on / points at this node. 入向 equip+link(依赖它的)。
  final List<EntityRelation> referencedBy;

  /// Outgoing `link` — what this node links out to. 出向 link(它链出的)。
  final List<EntityRelation> links;

  bool get isEmpty => equips.isEmpty && referencedBy.isEmpty && links.isEmpty;
}

RelationGroups relationGroupsFor(String id, List<EntityRelation> edges) => RelationGroups(
      equips: [for (final e in edges) if (e.fromId == id && e.kind == 'equip') e],
      referencedBy: [
        for (final e in edges)
          if (e.toId == id && (e.kind == 'equip' || e.kind == 'link')) e,
      ],
      links: [for (final e in edges) if (e.fromId == id && e.kind == 'link') e],
    );

List<EntityRow> recentEntities(List<RailGroup> groups, {int max = 5}) {
  final rows = [
    for (final g in groups) ...(g.state.value?.rows ?? const <EntityRow>[]),
  ];
  rows.sort((a, b) {
    final c = b.updatedAt.compareTo(a.updatedAt);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return rows.take(max).toList();
}
