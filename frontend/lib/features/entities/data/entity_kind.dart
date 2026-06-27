import '../../../core/sse/frame.dart';

/// The four executable Quadrinity kinds the Entities feature gives full detail + execution to
/// (Phase 4.1 scope; trigger/control/approval/mcp/skill are deferred past 4.1). Each value carries
/// the three backend-derived constants a repository call needs — the REST collection segment, the SSE
/// `scope.kind` string, and the execution verb suffix — so call sites never hard-code paths.
///
/// 四个可执行 Quadrinity kind(4.1 范围)。每个值携带 repository 调用所需的三个后端派生常量——REST
/// 集合段 / SSE `scope.kind` / 执行动词后缀——使调用点不硬编码路径。
enum EntityKind {
  function('functions', 'function', ':run'),
  handler('handlers', 'handler', ':call'),
  agent('agents', 'agent', ':invoke'),
  workflow('workflows', 'workflow', ':trigger');

  const EntityKind(this.collection, this.scopeKind, this.verb);

  /// REST path segment: `/api/v1/<collection>`. functions/handlers/agents/workflows。
  final String collection;

  /// The SSE envelope `scope.kind` for this entity's panel realtime (entities stream). function/…。
  final String scopeKind;

  /// The execution action suffix (N5): `:run`/`:call`/`:invoke`/`:trigger`. 执行动词后缀。
  final String verb;

  String get base => '/api/v1/$collection';
  String itemPath(String id) => '$base/$id';
  String actionPath(String id) => '${itemPath(id)}$verb';

  /// The entities-stream scope for one instance's panel realtime (run terminal / build mirror /
  /// flowrun tick). 单实例面板实时的 entities 流 scope。
  StreamScope scope(String id) => StreamScope(kind: scopeKind, id: id);

  /// The payload key carrying this entity's id in a lifecycle notification — functionId / handlerId /
  /// agentId / workflowId (all four go through the same `publish()` shape backend-side).
  /// 生命周期通知 payload 里携带本实体 id 的键。
  String get idField => '${scopeKind}Id';
}

/// The deep-link location for an entity (STEP 6): `/entities/<kind>/<id>`. The `:kind` segment is the
/// enum `name` (= the lowercase wire kind), so [entityKindFromWire] round-trips it. The rail navigates
/// here (`context.go`) to set selection; the router is the source of truth. 实体 deep-link 位置。
String entityLocation(EntityKind kind, String id) => '/entities/${kind.name}/$id';

/// Parse a route `:kind` segment back to an [EntityKind] — null if not one of the four (a bad/legacy
/// link). URLs are case-sensitive in go_router, so only the exact lowercase `name` matches; the router's
/// redirect uses this to bounce bad kinds home. 解析路由 :kind(非四者之一→null,大小写敏感)。
EntityKind? entityKindFromWire(String? wire) {
  for (final k in EntityKind.values) {
    if (k.name == wire) return k;
  }
  return null;
}
