import '../contract/entities/values.dart' show NodeKind;

/// The family a workflow node's `ref` selects from. For an `action` node the family is CHOSEN by the
/// author (function vs handler vs mcp — all callable); for every other kind the family is fixed by the
/// node kind. 节点 ref 所选的实体族。action 的族由作者选(function/handler/mcp,皆可调用);其余族由 kind 定死。
enum RefFamily {
  function,
  handler,
  mcp,
  agent,
  trigger,
  control,
  approval,
  unknown,
}

/// A parsed workflow node `ref` — a pure, framework-free value object mirroring the backend's ref
/// grammar (workflow domain §20: `trg_` / `fn_` · `hd_….method` · `mcp:server/tool` / `ag_` / `ctl_` /
/// `apf_`). It splits a raw ref string into (family, target, member) so a hierarchical picker can drive
/// it — the author picks a family, then a target entity, then (handler → method, mcp → tool) a member —
/// and re-formats back to the wire string. Freshly added nodes carry a `<prefix>_new` placeholder that
/// parses to an UNSELECTED ref (target == null), which the picker renders as its empty prompt.
///
/// 解析后的节点 ref——纯框架无关值对象,镜像后端 ref 文法(workflow 域 §20)。把裸 ref 拆成
/// (族, 目标, 成员)供分层选择器驱动(选族 → 选目标实体 → 选成员[handler→方法 / mcp→工具]),再拼回线缆串。
/// 新加节点带 `<前缀>_new` 占位 → 解析为未选(target==null),选择器渲染为空提示。
class NodeRef {
  const NodeRef({required this.family, this.target, this.member});

  /// The selected family. 选中的族。
  final RefFamily family;

  /// The selected target entity id/name (`fn_…` / `hd_…` / an mcp server name / `ag_…` / …). Null = not
  /// yet selected (a fresh `<prefix>_new` placeholder or an empty ref). 目标实体 id/名;null=未选。
  final String? target;

  /// Handler method / mcp tool — only meaningful for the handler & mcp families. handler 方法 / mcp 工具。
  final String? member;

  bool get isResolved => target != null && target!.isNotEmpty;

  /// Only handler & mcp have a second (member) level. 仅 handler 与 mcp 有第二层(成员)。
  bool get hasMember => family == RefFamily.handler || family == RefFamily.mcp;

  NodeRef copyWith({
    RefFamily? family,
    Object? target = _keep,
    Object? member = _keep,
  }) => NodeRef(
    family: family ?? this.family,
    target: target == _keep ? this.target : target as String?,
    member: member == _keep ? this.member : member as String?,
  );

  /// Parse a raw ref for a node [kind]. The action family is inferred from the prefix (`mcp:` / `hd_` /
  /// `fn_`); every other kind maps 1:1. A `<prefix>_new` placeholder or empty string → unselected.
  /// 按 kind 解析裸 ref;action 族由前缀推断,其余 1:1;`<前缀>_new` 占位或空串 → 未选。
  static NodeRef parse(NodeKind kind, String ref) {
    final r = ref.trim();
    switch (kind) {
      case NodeKind.action:
        if (r.startsWith('mcp:')) {
          final rest = r.substring(4);
          final slash = rest.indexOf('/');
          if (slash >= 0) {
            return NodeRef(
              family: RefFamily.mcp,
              target: _blankToNull(rest.substring(0, slash)),
              member: _blankToNull(rest.substring(slash + 1)),
            );
          }
          return NodeRef(family: RefFamily.mcp, target: _blankToNull(rest));
        }
        if (r.startsWith('hd_')) {
          final dot = r.indexOf('.');
          if (dot >= 0) {
            return NodeRef(
              family: RefFamily.handler,
              target: _blankToNull(r.substring(0, dot)),
              member: _blankToNull(r.substring(dot + 1)),
            );
          }
          return NodeRef(
            family: RefFamily.handler,
            target: _placeholderToNull(r, 'hd'),
          );
        }
        // Default (and the fresh `fn_new` placeholder) → the function family. 默认(及 fn_new 占位)→ function 族。
        return NodeRef(
          family: RefFamily.function,
          target: _placeholderToNull(r, 'fn'),
        );
      case NodeKind.agent:
        return NodeRef(
          family: RefFamily.agent,
          target: _placeholderToNull(r, 'ag'),
        );
      case NodeKind.trigger:
        return NodeRef(
          family: RefFamily.trigger,
          target: _placeholderToNull(r, 'trg'),
        );
      case NodeKind.control:
        return NodeRef(
          family: RefFamily.control,
          target: _placeholderToNull(r, 'ctl'),
        );
      case NodeKind.approval:
        return NodeRef(
          family: RefFamily.approval,
          target: _placeholderToNull(r, 'apf'),
        );
      case NodeKind.unknown:
        return NodeRef(family: RefFamily.unknown, target: _blankToNull(r));
    }
  }

  /// Re-assemble the wire ref string. A target-less ref emits a family-CARRYING placeholder (NOT a bare
  /// '') so `parse` round-trips the family back — otherwise switching the picker's family dropdown to
  /// handler/mcp would collapse to '' and re-parse as the `function` default, making those two families
  /// unreachable. 拼回线缆 ref;无目标发**带族**占位(非空串),使 parse 能还原本族——否则切族到 handler/mcp
  /// 会塌成 '' 被当 function 默认重解析,那两族就够不到。
  String format() {
    final t = target;
    if (t == null || t.isEmpty) {
      return switch (family) {
        RefFamily.function => 'fn_new',
        RefFamily.handler => 'hd_new',
        RefFamily.mcp => 'mcp:',
        RefFamily.agent => 'ag_new',
        RefFamily.trigger => 'trg_new',
        RefFamily.control => 'ctl_new',
        RefFamily.approval => 'apf_new',
        RefFamily.unknown => '',
      };
    }
    switch (family) {
      case RefFamily.handler:
        return (member?.isNotEmpty ?? false) ? '$t.$member' : t;
      case RefFamily.mcp:
        return (member?.isNotEmpty ?? false) ? 'mcp:$t/$member' : 'mcp:$t';
      default:
        return t;
    }
  }

  /// The families an [action] node may pick among (ordered). Non-action kinds have exactly one, keyed
  /// off the kind. action 可选的族(有序);非 action 恰一个、由 kind 定。
  static List<RefFamily> familiesFor(NodeKind kind) => switch (kind) {
    NodeKind.action => const [
      RefFamily.function,
      RefFamily.handler,
      RefFamily.mcp,
    ],
    NodeKind.agent => const [RefFamily.agent],
    NodeKind.trigger => const [RefFamily.trigger],
    NodeKind.control => const [RefFamily.control],
    NodeKind.approval => const [RefFamily.approval],
    NodeKind.unknown => const [RefFamily.unknown],
  };

  static const _keep = Object();

  static String? _blankToNull(String s) => s.isEmpty ? null : s;

  /// A `<prefix>_new` fresh-node placeholder (or empty) → unselected; a real id passes through.
  /// `<前缀>_new` 占位(或空)→ 未选;真 id 原样。
  static String? _placeholderToNull(String s, String prefix) =>
      (s.isEmpty || s == '${prefix}_new') ? null : s;

  @override
  bool operator ==(Object other) =>
      other is NodeRef &&
      other.family == family &&
      other.target == target &&
      other.member == member;

  @override
  int get hashCode => Object.hash(family, target, member);

  @override
  String toString() => 'NodeRef(${family.name}, $target, $member)';
}
