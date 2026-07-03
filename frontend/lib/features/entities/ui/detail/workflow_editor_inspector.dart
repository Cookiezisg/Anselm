import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_action_group.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_input.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/detail/workflow_editor_provider.dart';
import '../../state/selected_entity.dart';

/// The editor's inspector (WRK-055 W5) — edits the SELECTED node or edge. Node: kind, ref, an
/// input-mapping (field→CEL) editor, a retry toggle, delete. Edge: from→to (read-only), a port field
/// (approval → yes/no dropdown; control → text that must match a branch name; others hidden), delete.
/// Nothing selected → an empty state. All edits flow through [workflowEditorProvider].
///
/// 编辑器检查器(W5)——编辑选中的节点或边。节点:类型/引用/输入映射(field→CEL)/重试开关/删除。
/// 边:from→to(只读)/端口(approval yes/no 下拉;control 文本须匹配分支名;余隐藏)/删除。未选=空态。
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

    final Widget body;
    if (node != null) {
      body = _NodeEditor(node: node, notifier: notifier);
    } else if (edge != null && st != null) {
      body = _EdgeEditor(edge: edge, graph: st.working, notifier: notifier);
    } else {
      body = Center(
        child: AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: e.inspectorEmpty),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AnSpace.s12),
      child: body,
    );
  }
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
      Text(node.id, style: AnText.h3.copyWith(color: context.colors.ink)),
      const SizedBox(height: AnSpace.s12),
      AnSection(label: e.nodeKind, variant: AnSectionVariant.quiet, children: [
        AnDropdown<NodeKind>(
          value: node.kind,
          block: true,
          options: [
            for (final k in const [NodeKind.trigger, NodeKind.action, NodeKind.agent, NodeKind.control, NodeKind.approval])
              AnDropdownOption(value: k, label: switch (k) {
                NodeKind.trigger => g.trigger,
                NodeKind.action => g.action,
                NodeKind.agent => g.agent,
                NodeKind.control => g.control,
                NodeKind.approval => g.approval,
                NodeKind.unknown => g.unknown,
              }, icon: AnIcons.node(k.name)),
          ],
          onChanged: (k) => notifier.setNodeKind(node.id, k),
        ),
      ]),
      AnSection(label: e.nodeRef, variant: AnSectionVariant.quiet, children: [
        AnInput(
          key: ValueKey('ref_${node.id}'),
          initialValue: node.ref,
          block: true,
          onSubmitted: (v) => notifier.setNodeRef(node.id, v),
          onChanged: (v) => notifier.setNodeRef(node.id, v),
        ),
      ]),
      AnSection(label: e.nodeInput, variant: AnSectionVariant.quiet, children: [
        _InputMapEditor(node: node, notifier: notifier),
      ]),
      AnSection(label: e.nodeRetry, variant: AnSectionVariant.quiet, children: [
        _RetryEditor(node: node, notifier: notifier),
      ]),
      const SizedBox(height: AnSpace.s12),
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
              width: 96,
              child: Text(entry.key, style: AnText.code.copyWith(color: context.colors.inkMuted), overflow: TextOverflow.ellipsis),
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
            AnButton.iconOnly(AnIcons.close,
                size: AnButtonSize.sm,
                semanticLabel: 'remove',
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
    final c = context.colors;
    final retry = node.retry;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(e.retryEnable, style: AnText.body.copyWith(color: c.ink))),
        AnButton(
          label: retry == null ? e.off : e.on,
          size: AnButtonSize.sm,
          variant: retry == null ? AnButtonVariant.ghost : AnButtonVariant.primary,
          onPressed: () => notifier.setNodeRetry(node.id, retry == null ? const RetryConfig(maxAttempts: 3) : null),
        ),
      ]),
      if (retry != null) ...[
        const SizedBox(height: AnSpace.s6),
        Row(children: [
          Expanded(child: Text(e.maxAttempts, style: AnText.meta.copyWith(color: c.inkMuted))),
          SizedBox(
            width: 72,
            child: AnInput(
              key: ValueKey('retry_${node.id}'),
              initialValue: '${retry.maxAttempts}',
              block: true,
              onSubmitted: (v) => notifier.setNodeRetry(node.id, retry.copyWith(maxAttempts: int.tryParse(v) ?? retry.maxAttempts)),
            ),
          ),
        ]),
      ],
    ]);
  }
}

class _EdgeEditor extends StatelessWidget {
  const _EdgeEditor({required this.edge, required this.graph, required this.notifier});

  final Edge edge;
  final Graph graph;
  final WorkflowEditorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final e = context.t.entities.detail.editor;
    final c = context.colors;
    final src = graph.nodes.where((n) => n.id == edge.from).firstOrNull;
    final isApproval = src?.kind == NodeKind.approval;
    final isControl = src?.kind == NodeKind.control;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${edge.from} → ${edge.to}', style: AnText.strong.copyWith(color: c.ink)),
      const SizedBox(height: AnSpace.s12),
      if (isApproval)
        AnSection(label: e.edgePort, variant: AnSectionVariant.quiet, children: [
          AnDropdown<String>(
            value: edge.fromPort ?? 'yes',
            block: true,
            options: const [
              AnDropdownOption(value: 'yes', label: 'yes'),
              AnDropdownOption(value: 'no', label: 'no'),
            ],
            onChanged: (p) => notifier.setEdgePort(edge.id, p),
          ),
        ])
      else if (isControl)
        AnSection(label: e.edgePort, variant: AnSectionVariant.quiet, children: [
          AnInput(
            key: ValueKey('port_${edge.id}'),
            initialValue: edge.fromPort ?? '',
            block: true,
            onSubmitted: (v) => notifier.setEdgePort(edge.id, v.isEmpty ? null : v),
            onChanged: (v) => notifier.setEdgePort(edge.id, v.isEmpty ? null : v),
          ),
          const SizedBox(height: AnSpace.s4),
          Text(e.portHint, style: AnText.meta.copyWith(color: c.inkFaint)),
        ]),
      const SizedBox(height: AnSpace.s12),
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
