import '../../../core/sse/frame.dart';

/// Every kind the Entities rail carries. The four executable **Quadrinity** kinds get full detail +
/// execution (run terminal + verb CTA + logs); the three **support** kinds are in the rail but not
/// executable (verb=null). Each value carries the backend-derived constants a repository call needs — the
/// REST collection segment, the SSE `scope.kind` string, and the execution verb suffix — so call sites
/// never hard-code paths.
///
/// rail 的全部 kind:四个可执行 Quadrinity(全详情+执行)+ 三个支撑 kind(进 rail、不可执行,verb=null)。
/// 每个值携带 repository 调用所需的后端派生常量——REST 集合段 / SSE `scope.kind` / 执行动词后缀。
enum EntityKind {
  function('functions', 'function', ':run'),
  handler('handlers', 'handler', ':call'),
  agent('agents', 'agent', ':invoke'),
  workflow('workflows', 'workflow', ':trigger'),
  // Support kinds — in the entities rail but NOT executable Quadrinity. control/approval are versioned
  // routing/approval logic (no run terminal); trigger is an UNVERSIONED config signal-source with its own
  // observability (activations/firings) instead of logs. All three have verb=null (no run terminal / no
  // execution verb). 支撑 kind:进 rail 但非可执行四大(verb=null)。control/approval 有版本;trigger 无版本、
  // 有自己的观测面(活动/派发)代替日志。
  control('controls', 'control', null),
  approval('approvals', 'approval', null),
  trigger('triggers', 'trigger', null);

  const EntityKind(this.collection, this.scopeKind, this.verb);

  /// REST path segment: `/api/v1/<collection>`. functions/handlers/agents/workflows/controls。
  final String collection;

  /// The SSE envelope `scope.kind` for this entity's panel realtime (entities stream). function/…。
  final String scopeKind;

  /// The execution action suffix (N5): `:run`/`:call`/`:invoke`/`:trigger` — **null for support kinds**
  /// (control/…) that don't execute. 执行动词后缀;**支撑 kind 为 null**。
  final String? verb;

  /// Whether this kind executes (has a run terminal + verb CTA + logs). Support kinds are pure
  /// config/logic. 是否可执行(有 run 终端 + 动词 CTA + 日志);支撑 kind 否。
  bool get executable => verb != null;

  String get base => '/api/v1/$collection';
  String itemPath(String id) => '$base/$id';

  /// The execution action path — null for non-executable support kinds. 执行动作路径(支撑 kind 为 null)。
  String? actionPath(String id) => verb == null ? null : '${itemPath(id)}$verb';

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
String entityLocation(EntityKind kind, String id) =>
    '/entities/${kind.name}/$id';

/// The workflow graph-editor route (WRK-055 W5) — a full-screen page, NOT the shell. 图编辑器路由(全屏)。
String workflowEditorLocation(String id) => '/entities/workflow/$id/editor';

/// Parse a route `:kind` segment back to an [EntityKind] — null if not one of the four (a bad/legacy
/// link). URLs are case-sensitive in go_router, so only the exact lowercase `name` matches; the router's
/// redirect uses this to bounce bad kinds home. 解析路由 :kind(非四者之一→null,大小写敏感)。
EntityKind? entityKindFromWire(String? wire) {
  for (final k in EntityKind.values) {
    if (k.name == wire) return k;
  }
  return null;
}
