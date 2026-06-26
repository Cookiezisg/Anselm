import 'package:freezed_annotation/freezed_annotation.dart';

part 'values.freezed.dart';
part 'values.g.dart';

/// Shared value types across the entity domains (function/handler/agent/workflow), each a 1:1 freezed
/// mirror of a backend Go value struct (cited per type). Reuse [ModelRef] from workspace.dart for
/// agent modelOverride. camelCase wire, json_serializable, no rename maps (except the `default`
/// reserved word). 跨实体域共享值类型,逐一镜像后端 Go 值结构。

/// A typed I/O field (fn/hd/ag/mcp/trigger/control/approval inputs+outputs). `type` is a COARSE open
/// set (string/number/boolean/object/array) never enforced server-side — keep it an open String.
/// schema.go:37。类型粗粒度开放集、后端不强校,故 String。
@freezed
abstract class Field with _$Field {
  const factory Field({
    required String name,
    required String type,
    String? description,
  }) = _Field;
  factory Field.fromJson(Map<String, dynamic> json) => _$FieldFromJson(json);
}

/// A tool mount reference on an agent: `ref` ∈ `fn_<id>` / `hd_<id>.<method>` / `mcp:<server>/<tool>`
/// (`ag_` forbidden), `name` the display alias. agent.go:49。
@freezed
abstract class ToolRef with _$ToolRef {
  const factory ToolRef({required String ref, required String name}) = _ToolRef;
  factory ToolRef.fromJson(Map<String, dynamic> json) => _$ToolRefFromJson(json);
}

/// One handler method (a streaming-or-not callable). method.go:8。
@freezed
abstract class MethodSpec with _$MethodSpec {
  const factory MethodSpec({
    required String name,
    String? description,
    @Default(<Field>[]) List<Field> inputs,
    @Default(<Field>[]) List<Field> outputs,
    @Default('') String body,
    @Default(false) bool streaming,
    int? timeout,
  }) = _MethodSpec;
  factory MethodSpec.fromJson(Map<String, dynamic> json) => _$MethodSpecFromJson(json);
}

/// A handler __init__ config arg (distinct from [Field] — carries required/sensitive/default). The
/// `default` JSON key is a Dart reserved word → renamed. method.go:38。
@freezed
abstract class InitArgSpec with _$InitArgSpec {
  const factory InitArgSpec({
    required String name,
    required String type,
    String? description,
    @Default(false) bool required,
    @Default(false) bool sensitive,
    @JsonKey(name: 'default') Object? defaultValue,
  }) = _InitArgSpec;
  factory InitArgSpec.fromJson(Map<String, dynamic> json) => _$InitArgSpecFromJson(json);
}

/// The workflow graph node kind — a SEALED closed set (workflow.go:104). `unknown` is the
/// forward-compat fallback (used via @JsonKey(unknownEnumValue:) on [Node.kind]). 封闭集 + unknown 兜底。
@JsonEnum()
enum NodeKind { trigger, action, agent, control, approval, unknown }

/// A node's persisted canvas position (graph blob is the source of truth for layout). workflow.go。
@freezed
abstract class NodePosition with _$NodePosition {
  const factory NodePosition({@Default(0) int x, @Default(0) int y}) = _NodePosition;
  factory NodePosition.fromJson(Map<String, dynamic> json) => _$NodePositionFromJson(json);
}

/// Per-node retry policy (control-flow). workflow.go。
@freezed
abstract class RetryConfig with _$RetryConfig {
  const factory RetryConfig({
    @Default(0) int maxAttempts,
    String? backoff,
    int? delayMs,
  }) = _RetryConfig;
  factory RetryConfig.fromJson(Map<String, dynamic> json) => _$RetryConfigFromJson(json);
}

/// A graph edge; `fromPort` is set ONLY for control/approval branch outputs (yes/no). workflow.go:131。
@freezed
abstract class Edge with _$Edge {
  const factory Edge({
    required String id,
    required String from,
    String? fromPort,
    required String to,
  }) = _Edge;
  factory Edge.fromJson(Map<String, dynamic> json) => _$EdgeFromJson(json);
}

/// A graph node. `input` is a CEL-expression map; `kind` falls back to [NodeKind.unknown] if the
/// backend ever widens the set. workflow.go:104。
@freezed
abstract class Node with _$Node {
  const factory Node({
    required String id,
    @JsonKey(unknownEnumValue: NodeKind.unknown) required NodeKind kind,
    @Default('') String ref,
    @Default(<String, String>{}) Map<String, String> input,
    RetryConfig? retry,
    NodePosition? pos,
    String? notes,
  }) = _Node;
  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);
}

/// The decoded workflow graph (nodes + edges). The raw JSON blob lives on WorkflowVersion.graph;
/// this is the parsed form (`graphParsed`). workflow.go:96。
@freezed
abstract class Graph with _$Graph {
  const factory Graph({
    @Default(<Node>[]) List<Node> nodes,
    @Default(<Edge>[]) List<Edge> edges,
  }) = _Graph;
  factory Graph.fromJson(Map<String, dynamic> json) => _$GraphFromJson(json);
}
