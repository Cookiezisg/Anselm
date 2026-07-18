import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/control.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_action_group.dart';
import '../../../../core/ui/an_field.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_form_field.dart';
import '../../../../core/ui/an_input.dart';
import '../../../../core/ui/an_inspector_head.dart';
import '../../../../core/ui/an_scroll_behavior.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/detail/ref_candidates.dart';
import '../../state/detail/workflow_editor_provider.dart';
import '../../../../core/shell/right_panel.dart';
import '../../state/selected_entity.dart';
import 'node_ref_picker.dart';
import 'control_branch_row.dart';

/// The editor's inspector (WRK-055) — the visual twin of the run terminal's right-island content: a
/// head band (kind glyph + node.id + a bare collapse button) → a hairline → a full-height scrolling
/// body, so it reads as the SAME app, not a foreign panel. Edits the SELECTED node or edge; nothing
/// selected → a centered empty state in the full-height body. Fields use the app's label-above /
/// block-control-below vocabulary. All edits flow through [workflowEditorProvider].
///
/// 编辑器检查器——run 终端右岛内容的视觉孪生:头带(kind 图标 + node.id + 裸收起钮)→ 发丝线 → 满高滚动
/// body,读来是同一个 app、不是外来面板。编辑选中的节点或边;未选 = 满高 body 里居中的空态。字段用 app 的
/// 「标签在上、block 控件在下」语汇。所有编辑经 [workflowEditorProvider]。
class WorkflowEditorInspector extends ConsumerWidget {
  const WorkflowEditorInspector({required this.entityRef, super.key});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.t.entities.detail.editor;
    final st = ref.watch(workflowEditorProvider(entityRef)).value;
    final notifier = ref.read(workflowEditorProvider(entityRef).notifier);
    final node = st?.selectedNode;
    final edge = st?.selectedEdge;

    // Head content varies by selection; the collapse action is always present (twin of run_terminal). 头随选区变;收起钮常在。
    final IconData headIcon;
    final String headTitle;
    String? subLeading;
    String? subTrailing;
    if (node != null) {
      headIcon = AnIcons.node(node.kind.name);
      headTitle = node.id;
      subLeading = _kindLabel(context, node.kind);
      subTrailing = node.ref;
    } else if (edge != null) {
      headIcon = AnIcons.byKey('chevr');
      headTitle = '${edge.from} → ${edge.to}';
      subLeading = e.edge;
      subTrailing = edge.fromPort;
    } else {
      headIcon = AnIcons.workflow;
      headTitle = e.inspectorTitle;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInspectorHead(
          icon: headIcon,
          label: headTitle,
          subLeading: subLeading,
          subTrailing: subTrailing,
          onClose: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
          closeSemantics: context.t.shell.togglePanel,
        ),
        Expanded(
          child: node != null
              ? _body(_NodeEditor(node: node, notifier: notifier))
              : edge != null && st != null
                  ? _body(_EdgeEditor(edge: edge, graph: st.working, notifier: notifier))
                  : AnState(
                      kind: AnStateKind.empty,
                      size: AnStateSize.inset,
                      title: e.inspectorEmpty,
                      hint: e.inspectorEmptyHint,
                    ),
        ),
      ],
    );
  }

  /// The scrolling body wrapper (bar hidden). No horizontal pad — the [AnIsland]'s 12px is the sole island
  /// inset (single-source law); only vertical s16. 滚动 body(隐条、水平 0:岛壳 12 即唯一岛级内距,仅纵 s16)。
  Widget _body(Widget child) => ScrollConfiguration(
        behavior: const AnScrollBehavior(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
          child: child,
        ),
      );

  static String _kindLabel(BuildContext context, NodeKind k) {
    final g = context.t.graph.kind;
    return switch (k) {
      NodeKind.trigger => g.trigger,
      NodeKind.action => g.action,
      NodeKind.agent => g.agent,
      NodeKind.control => g.control,
      NodeKind.approval => g.approval,
      NodeKind.unknown => g.unknown,
    };
  }
}

/// A form field with the standard inter-field bottom gap — a thin wrapper over the shared [AnFormField]
/// (label-above / control-below). 字段块(带标准字段间距):薄封装共享 [AnFormField](标签在上、控件在下)。
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.desc});

  final String label;
  final String? desc;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AnSpace.s16),
        child: AnFormField(label: label, desc: desc, child: child),
      );
}

class _NodeEditor extends StatelessWidget {
  const _NodeEditor({required this.node, required this.notifier});

  final Node node;
  final WorkflowEditorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final e = context.t.entities.detail.editor;
    final g = context.t.graph.kind;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Field(
        label: e.nodeKind,
        child: AnDropdown<NodeKind>(
          value: node.kind,
          block: true,
          options: [
            for (final k in const [
              NodeKind.trigger,
              NodeKind.action,
              NodeKind.agent,
              NodeKind.control,
              NodeKind.approval
            ])
              AnDropdownOption(
                  value: k,
                  label: switch (k) {
                    NodeKind.trigger => g.trigger,
                    NodeKind.action => g.action,
                    NodeKind.agent => g.agent,
                    NodeKind.control => g.control,
                    NodeKind.approval => g.approval,
                    NodeKind.unknown => g.unknown,
                  },
                  icon: AnIcons.node(k.name)),
          ],
          onChanged: (k) => notifier.setNodeKind(node.id, k),
        ),
      ),
      _Field(
        label: e.nodeRef,
        child: NodeRefPicker(
          key: ValueKey('ref_${node.id}'),
          kind: node.kind,
          refString: node.ref,
          onChanged: (v) => notifier.setNodeRef(node.id, v),
        ),
      ),
      _Field(label: e.nodeInput, child: _InputMapEditor(node: node, notifier: notifier)),
      _Field(label: e.nodeRetry, child: _RetryEditor(node: node, notifier: notifier)),
      // Control nodes: a read-only peek at the referenced control's routing branches (port / when / emit)
      // so the author sees the exits without leaving the editor. control 节点:只读 peek 路由分支(出口条件)。
      if (node.kind == NodeKind.control && node.ref.isNotEmpty) _ControlBranches(controlId: node.ref),
      AnActionGroup(footer: true, [
        AnButton(
          label: e.deleteNode,
          icon: AnIcons.trash,
          variant: AnButtonVariant.danger,
          size: AnButtonSize.sm,
          onPressed: notifier.deleteSelected,
        ),
      ]),
    ]);
  }
}

/// A field→CEL input-map editor: existing rows (editable + remove) + an add-row. The whole map is
/// re-sent on any change (the backend replaces input wholesale). field→CEL 输入映射编辑;整体回发。
class _InputMapEditor extends StatelessWidget {
  const _InputMapEditor({required this.node, required this.notifier});

  final Node node;
  final WorkflowEditorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final e = context.t.entities.detail.editor;
    final entries = node.input.entries.toList();
    void commit(Map<String, String> next) => notifier.setNodeInput(node.id, next);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s6),
          child: Row(children: [
            SizedBox(
              width: AnSize.inspectorKeyCol,
              child: Text(entry.key,
                  style: AnText.code.copyWith(color: context.colors.inkMuted),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AnSpace.s6),
            Expanded(
              child: AnInput(
                key: ValueKey('in_${node.id}_${entry.key}'),
                initialValue: entry.value,
                block: true,
                seamless: true,
                onSubmitted: (v) => commit({...node.input, entry.key: v}),
                onChanged: (v) => commit({...node.input, entry.key: v}),
              ),
            ),
            AnButton.iconOnly(
              AnIcons.close,
              size: AnButtonSize.sm,
              semanticLabel: e.removeField,
              onPressed: () => commit({...node.input}..remove(entry.key)),
            ),
          ]),
        ),
      _AddFieldRow(hint: e.field, onAdd: (name) {
        if (name.isEmpty || node.input.containsKey(name)) return;
        commit({...node.input, name: ''});
      }),
    ]);
  }
}

class _AddFieldRow extends StatefulWidget {
  const _AddFieldRow({required this.hint, required this.onAdd});
  final String hint;
  final ValueChanged<String> onAdd;

  @override
  State<_AddFieldRow> createState() => _AddFieldRowState();
}

class _AddFieldRowState extends State<_AddFieldRow> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add() {
    widget.onAdd(_ctl.text.trim());
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: AnInput(controller: _ctl, placeholder: widget.hint, block: true, onSubmitted: (_) => _add()),
      ),
      AnButton.iconOnly(AnIcons.plus, size: AnButtonSize.sm, semanticLabel: widget.hint, onPressed: _add),
    ]);
  }
}

class _RetryEditor extends StatelessWidget {
  const _RetryEditor({required this.node, required this.notifier});

  final Node node;
  final WorkflowEditorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final e = context.t.entities.detail.editor;
    final retry = node.retry;
    // Switch/number rows are the ONE label-left·control-right row — AnField's child slot (批6c
    // A-057: this file's own «label above» _Field grammar is for FORM blocks; a toggle with a
    // label above is an anti-pattern). 开关/数值行=唯一「标签左·控件右」行(AnField child 槽)。
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnField(
        label: e.retryEnable,
        child: AnButton(
          label: retry == null ? e.off : e.on,
          size: AnButtonSize.sm,
          variant: retry == null ? AnButtonVariant.ghost : AnButtonVariant.primary,
          onPressed: () =>
              notifier.setNodeRetry(node.id, retry == null ? const RetryConfig(maxAttempts: 3) : null),
        ),
      ),
      if (retry != null)
        AnField(
          label: e.maxAttempts,
          child: SizedBox(
            width: AnSize.inspectorNumField,
            child: AnInput(
              key: ValueKey('retry_${node.id}'),
              initialValue: '${retry.maxAttempts}',
              block: true,
              onSubmitted: (v) => notifier.setNodeRetry(
                  node.id, retry.copyWith(maxAttempts: int.tryParse(v) ?? retry.maxAttempts)),
            ),
          ),
        ),
    ]);
  }
}

class _EdgeEditor extends ConsumerWidget {
  const _EdgeEditor({required this.edge, required this.graph, required this.notifier});

  final Edge edge;
  final Graph graph;
  final WorkflowEditorNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.t.entities.detail.editor;
    final src = graph.nodes.where((n) => n.id == edge.from).firstOrNull;
    final isApproval = src?.kind == NodeKind.approval;
    final isControl = src?.kind == NodeKind.control;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (isApproval)
        _Field(
          label: e.edgePort,
          child: AnDropdown<String>(
            value: edge.fromPort ?? 'yes',
            block: true,
            options: [
              AnDropdownOption(value: 'yes', label: t.entities.val.yes),
              AnDropdownOption(value: 'no', label: t.entities.val.no),
            ],
            onChanged: (p) => notifier.setEdgePort(edge.id, p),
          ),
        )
      else if (isControl)
        // The control's declared branch ports become the dropdown — no more blind free-text.
        // control 声明的 branch port 变下拉,消灭盲打。
        _Field(
          label: e.edgePort,
          desc: e.portHint,
          child: _ControlPortPicker(
            controlId: src!.ref,
            current: edge.fromPort,
            onChanged: (p) => notifier.setEdgePort(edge.id, p),
          ),
        ),
      AnActionGroup(footer: true, [
        AnButton(
          label: e.deleteEdge,
          icon: AnIcons.trash,
          variant: AnButtonVariant.danger,
          size: AnButtonSize.sm,
          onPressed: notifier.deleteSelected,
        ),
      ]),
    ]);
  }
}

/// The control-source edge's `fromPort` picker: an [AnDropdown] of the referenced control's declared
/// branch ports (via [controlPortsProvider]), replacing free-text so a port always matches a real branch
/// (mirrors approval's yes/no dropdown). A stale [current] the control no longer declares stays
/// selectable so editing never silently drops it (same as the ref-target picker). control 出边端口下拉:
/// 被引用 control 的 branch port(陈旧值仍可选、不静默丢)。
class _ControlPortPicker extends ConsumerWidget {
  const _ControlPortPicker({required this.controlId, required this.current, required this.onChanged});

  final String controlId;
  final String? current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.t.entities.detail.editor;
    final ports = ref.watch(controlPortsProvider(controlId)).value ?? const <String>[];
    final cur = current ?? '';
    final options = <String>[...ports, if (cur.isNotEmpty && !ports.contains(cur)) cur];
    return AnDropdown<String>(
      block: true,
      value: cur.isEmpty ? null : cur,
      placeholder: e.portPick,
      options: [for (final p in options) AnDropdownOption(value: p, label: p)],
      onChanged: onChanged,
    );
  }
}

/// A read-only peek at a control's routing branches (its active version), shown in the node inspector so
/// the author sees each exit's port + when-condition + whether it reshapes the payload — without opening
/// the control. Renders nothing until the control loads (or if it declares no branches). control 路由分支
/// 只读 peek(节点检查器):每出口 port + when 条件 + 是否 emit;加载完才显。
class _ControlBranches extends ConsumerWidget {
  const _ControlBranches({required this.controlId});

  final String controlId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.t.entities.detail.editor;
    final c = context.colors;
    final branches =
        ref.watch(controlProvider(controlId)).value?.activeVersion?.branches ?? const <Branch>[];
    if (branches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(e.branches, style: AnText.strong.copyWith(color: c.ink)),
        const SizedBox(height: AnSpace.s6),
        for (final b in branches) ControlBranchRow(branch: b),
      ]),
    );
  }

}
