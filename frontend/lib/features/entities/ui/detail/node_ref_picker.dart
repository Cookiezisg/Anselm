import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/graph/node_ref.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/detail/ref_candidates.dart';

/// The hierarchical node-ref picker (WRK-055 stage 2) — replaces the raw ref text field with dependent
/// dropdowns: family → target → member, exactly the run input form's handler→method idiom. For an
/// `action` node the author first picks a family (function / handler / mcp), then the target entity,
/// then (handler → method, mcp → tool) a member; every other kind has a single target dropdown keyed
/// off its kind. Selecting up-level resets the levels below it. The picker is CONTROLLED — it derives
/// its state from [refString] (the node's live ref) and writes the re-formatted wire string via
/// [onChanged]; a stale/unloaded target stays selectable so it always displays.
///
/// 分层节点 ref 选择器——用依赖下拉替裸 ref 文本框:族 → 目标 → 成员(复用 run 输入表单 handler→method 范式)。
/// action 先选族(function/handler/mcp)再选目标实体再选成员(handler→方法 / mcp→工具);其余 kind 单目标下拉。
/// 选上层清下层。受控——从 [refString] 派生、经 [onChanged] 回写拼好的线缆串;陈旧/未加载的目标仍可选、始终显示。
class NodeRefPicker extends ConsumerWidget {
  const NodeRefPicker({
    required this.kind,
    required this.refString,
    required this.onChanged,
    super.key,
  });

  final NodeKind kind;
  final String refString;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.t.entities.detail.editor;
    final parsed = NodeRef.parse(kind, refString);
    final families = NodeRef.familiesFor(kind);

    final rows = <Widget>[
      // Family — only when there's a choice (action). 族——仅有选择时(action)。
      if (families.length > 1)
        AnDropdown<RefFamily>(
          block: true,
          value: parsed.family,
          placeholder: e.refPickFamily,
          options: [
            for (final f in families)
              AnDropdownOption(
                value: f,
                label: _familyLabel(context, f),
                icon: _familyIcon(f),
              ),
          ],
          // Switching family clears the target + member below it. 切族清下游目标+成员。
          onChanged: (f) => onChanged(NodeRef(family: f).format()),
        ),
      _targetDropdown(context, ref, parsed),
      // Member (handler method / mcp tool) — only once a target is chosen. 成员——选中目标后才出。
      if (parsed.hasMember && parsed.isResolved)
        _memberDropdown(context, ref, parsed),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AnSpace.s6),
          rows[i],
        ],
      ],
    );
  }

  Widget _targetDropdown(BuildContext context, WidgetRef ref, NodeRef parsed) {
    final e = context.t.entities.detail.editor;
    final loaded =
        ref.watch(refTargetsProvider(parsed.family)).value ??
        const <RefCandidate>[];
    final options = [
      for (final o in loaded)
        AnDropdownOption(value: o.id, label: o.name, meta: o.meta),
    ];
    // Keep the current target selectable even if the list hasn't loaded or no longer contains it. 保留当前目标可选。
    final t = parsed.target;
    if (t != null && !loaded.any((o) => o.id == t)) {
      options.insert(0, AnDropdownOption(value: t, label: t));
    }
    return AnDropdown<String>(
      block: true,
      value: t,
      placeholder: e.refPickTarget,
      options: options,
      onChanged: (id) =>
          onChanged(parsed.copyWith(target: id, member: null).format()),
    );
  }

  Widget _memberDropdown(BuildContext context, WidgetRef ref, NodeRef parsed) {
    final e = context.t.entities.detail.editor;
    final loaded =
        ref
            .watch(
              refMembersProvider((
                family: parsed.family,
                target: parsed.target!,
              )),
            )
            .value ??
        const <RefCandidate>[];
    final options = [
      for (final o in loaded)
        AnDropdownOption(value: o.id, label: o.name, meta: o.meta),
    ];
    final m = parsed.member;
    if (m != null && m.isNotEmpty && !loaded.any((o) => o.id == m)) {
      options.insert(0, AnDropdownOption(value: m, label: m));
    }
    return AnDropdown<String>(
      block: true,
      value: (m?.isEmpty ?? true) ? null : m,
      placeholder: parsed.family == RefFamily.mcp
          ? e.refPickTool
          : e.refPickMethod,
      options: options,
      onChanged: (v) => onChanged(parsed.copyWith(member: v).format()),
    );
  }

  static String _familyLabel(BuildContext context, RefFamily f) {
    final t = context.t.entities.detail.editor;
    return switch (f) {
      RefFamily.function => t.refFamilyFunction,
      RefFamily.handler => t.refFamilyHandler,
      RefFamily.mcp => t.refFamilyMcp,
      _ => f.name,
    };
  }

  static IconData _familyIcon(RefFamily f) => switch (f) {
    RefFamily.handler => AnIcons.byKey('handler'),
    RefFamily.mcp => AnIcons.byKey('mcp'),
    _ => AnIcons.byKey('function'),
  };
}
