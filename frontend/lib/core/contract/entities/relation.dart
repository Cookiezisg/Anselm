import 'package:freezed_annotation/freezed_annotation.dart';

part 'relation.freezed.dart';
part 'relation.g.dart';

/// One edge in the workspace's entity-relation graph — read-only derived data (the backend diff-syncs
/// edges on entity writes; there is no edge CRUD). [kind] is the closed 4-verb set `create|edit|equip|
/// link`; a document's `[[id]]` wikilinks materialize as `link` out-edges, so BACKLINKS of a document =
/// incoming `link` edges (`GET /relations?toKind=document&toId=…&kind=link`). [fromName]/[toName] are
/// hydrated FRESH at read time via the backend's Namer registry — a renamed linker always shows its
/// current title; a deleted one falls back to the raw id. relation.go:28。
///
/// 关系图一条边——只读派生数据(边随实体写 diff-sync,无边 CRUD)。kind=4 动词封闭集;文档 `[[id]]` wikilink
/// 落成 link 出边,故文档的 backlinks=入向 link 边。fromName/toName 读时新鲜 hydrate(改名跟随;删了回落裸 id)。
@freezed
abstract class EntityRelation with _$EntityRelation {
  const factory EntityRelation({
    required String id,
    @Default('') String kind,
    @Default('') String fromKind,
    @Default('') String fromId,
    @Default('') String fromName,
    @Default('') String toKind,
    @Default('') String toId,
    @Default('') String toName,
  }) = _EntityRelation;
  factory EntityRelation.fromJson(Map<String, dynamic> json) => _$EntityRelationFromJson(json);
}

/// One node in the whole-workspace relation snapshot — a deduped entity that appears at some edge
/// endpoint (an isolated entity with no relations never surfaces; the backend builds nodes by deduping
/// edge endpoints). [kind] is one of the 11 backend `EntityKind` wire strings — the four Quadrinity
/// (function/handler/agent/workflow), the three support kinds (trigger/control/approval), and the four
/// accessory kinds (skill/mcp/document/conversation) that never appear in the 7-value rail `EntityKind`.
/// [name] is hydrated FRESH at read time (a rename shows current; a deleted entity falls back to raw id).
/// relation.go Node。
///
/// 全 workspace 关系快照的一个节点——出现在某边端点、去重后的实体(零关系的孤立实体不入快照)。kind=11
/// 种后端 EntityKind 线缆值(四大 + 三支撑 + 四配件 skill/mcp/document/conversation);name 读时新鲜 hydrate。
@freezed
abstract class EntityNode with _$EntityNode {
  const factory EntityNode({
    @Default('') String kind,
    @Default('') String id,
    @Default('') String name,
  }) = _EntityNode;
  factory EntityNode.fromJson(Map<String, dynamic> json) => _$EntityNodeFromJson(json);
}

/// The whole-workspace relation snapshot (`GET /api/v1/relgraph`, no params, no pagination — a bounded
/// system-level resource) = deduped [nodes] + all [edges]. The Entities Overview relationship graph reads
/// this ONE snapshot: the observing state filters edges to the structural verbs (equip/link) and their
/// endpoint nodes; the "show provenance" toggle re-admits create/edit edges + conversation nodes.
/// relation.go Snapshot。
///
/// 全 workspace 关系快照(GET /relgraph,无参无分页,有界系统级资源)=去重 nodes + 全部 edges。Entities 总览
/// 关系图读这一份:观赏态过滤到结构边 equip/link + 其端点节点,「显示溯源」开关再纳入 create/edit 边 + 对话节点。
@freezed
abstract class EntityRelGraph with _$EntityRelGraph {
  const factory EntityRelGraph({
    @Default(<EntityNode>[]) List<EntityNode> nodes,
    @Default(<EntityRelation>[]) List<EntityRelation> edges,
  }) = _EntityRelGraph;
  factory EntityRelGraph.fromJson(Map<String, dynamic> json) => _$EntityRelGraphFromJson(json);
}
