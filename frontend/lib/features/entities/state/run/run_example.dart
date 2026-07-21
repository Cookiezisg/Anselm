import 'dart:convert';

import '../../../../core/contract/entities/values.dart';

/// The debugger's example generator (v3 JSON-first, 0719 拍板): `schema → runnable example JSON` as a
/// PURE function, so a freshly-opened panel already holds a concrete, editable object instead of an
/// empty box — «哪里填哪个» disappears, the user changes a value and runs.
///
/// The entity contract's flat [Field] is deliberately minimal — name / coarse type / description only
/// (`schema.go`: no example / default / enum / nested; precise shaping is CEL's job at runtime). So the
/// fn/hd/ag adapter ([exampleForFields]) feeds TYPE-ONLY nodes and the result is a type SKELETON
/// (string→`""`, number→`0`, boolean→`false`, object→`{}`, array→`[]`). The richer precedence branches
/// (example → default → enum-first) live on [ExampleNode] for a source that DOES carry them — an MCP
/// tool's server-provided `inputSchema` (`schema.FromJSONSchema`), or a future richer contract — and are
/// matrix-locked so the ladder never rots. workflow does not go through here (its payload impersonates a
/// trigger's fire — see [workflowPayloadTemplate]).
///
/// 调试台示例生成器(v3 JSON-first):schema→可直接跑的示例 JSON 纯函数,开面板即握一份具体可改的对象、
/// 「哪里填哪个」消失。实体契约 [Field] 刻意极简(name/粗类型/描述,schema.go 无 example/default/enum/嵌套)
/// →fn/hd/ag 适配器喂纯类型节点、产出类型骨架;更富的优先级分支(example→default→enum 首值)留给带这些的
/// 源(MCP 工具 inputSchema / 未来更富契约),测试矩阵锁死。workflow 走触发源模板、不经此。

/// A minimal JSON-schema-ish node for the pure generator. Only [type] is required; the optional
/// [example]/[defaultValue]/[enumValues] and the recursive [properties]/[items] are populated only by a
/// richer source. 极简 JSON-schema 节点:仅 [type] 必填,其余富字段由带它的源填。
class ExampleNode {
  const ExampleNode({
    required this.type,
    this.example,
    this.defaultValue,
    this.enumValues,
    this.properties,
    this.items,
  });

  /// A coarse field type — string / number / boolean / object / array (anything else → null value).
  final String type;

  /// A concrete example value (highest precedence). 具体示例值(最高优先)。
  final Object? example;

  /// A declared default (second precedence). 声明默认(次优先)。
  final Object? defaultValue;

  /// An enum's members — the FIRST is used as the example (third precedence). enum 首值(第三优先)。
  final List<Object?>? enumValues;

  /// Object property nodes (recursed when [type] is object). object 递归属性。
  final Map<String, ExampleNode>? properties;

  /// Array element node (a single-element sample array when [type] is array). array 元素节点。
  final ExampleNode? items;
}

/// The example value for ONE node. Precedence: example → default → enum-first → type skeleton. A
/// recursive object/array descends; an unknown type yields null. 单节点示例:example→default→enum
/// 首值→类型骨架;object/array 递归;未知类型→null。
Object? exampleValue(ExampleNode n) {
  if (n.example != null) return n.example;
  if (n.defaultValue != null) return n.defaultValue;
  final en = n.enumValues;
  if (en != null && en.isNotEmpty) return en.first;
  switch (n.type) {
    case 'string':
      return '';
    case 'number':
      return 0;
    case 'boolean':
      return false;
    case 'object':
      final props = n.properties;
      if (props == null || props.isEmpty) return <String, Object?>{};
      return {for (final e in props.entries) e.key: exampleValue(e.value)};
    case 'array':
      final it = n.items;
      return it == null ? <Object?>[] : <Object?>[exampleValue(it)];
    default:
      return null; // an unknown/absent coarse type — an honest null, not a fake scalar 未知类型诚实 null
  }
}

/// Adapt the contract's flat [Field] list into a top-level example object (fn/hd/ag inputs). Each field
/// becomes a type-only node → its type skeleton. Empty list → an empty object. 扁平 Field→顶层示例对象。
Map<String, Object?> exampleForFields(List<Field> fields) => {
  for (final f in fields) f.name: exampleValue(ExampleNode(type: f.type)),
};

/// The prefilled editor seed: pretty JSON of [exampleForFields]. 编辑器预填种子(美化 JSON)。
String exampleJsonForFields(List<Field> fields) =>
    _pretty(exampleForFields(fields));

/// The workflow payload template for a picked trigger SOURCE (0719 拍板: the payload impersonates what
/// the trigger releases when it fires — so «triggering by hand» faithfully replays a real fire). The
/// shapes mirror the backend fire payloads VERBATIM (`infra/trigger/*`): cron → `{firedAt}`; webhook →
/// `{firedAt, method, path, headers, body}`; fsnotify → `{firedAt, path, eventKind}`; sensor → a CEL
/// output wrapped as `{value}`; manual → a free object. [now] is injected (pure/deterministic — the
/// caller passes wall-clock, tests a fixed instant).
///
/// workflow 按所选触发源的点火 payload 模板:形状逐字镜像后端 fire payload。[now] 注入保纯/可测。
Map<String, Object?> workflowPayloadTemplate(
  String sourceKind, {
  required DateTime now,
}) {
  final iso = now.toIso8601String();
  return switch (sourceKind) {
    'cron' => {'firedAt': iso},
    'webhook' => {
      'firedAt': iso,
      'method': 'POST',
      'path': '/webhooks/example',
      'headers': <String, Object?>{},
      'body': <String, Object?>{},
    },
    'fsnotify' => {
      'firedAt': iso,
      'path': '/path/to/file',
      'eventKind': 'modify',
    },
    'sensor' => {'value': 0},
    _ => <String, Object?>{}, // manual — a free payload body 手动=自由载荷
  };
}

/// The prefilled editor seed for a workflow source. 工作流来源的编辑器预填种子。
String workflowPayloadTemplateJson(
  String sourceKind, {
  required DateTime now,
}) => _pretty(workflowPayloadTemplate(sourceKind, now: now));

String _pretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
