import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/graph/graph_model.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_graph_canvas.dart';
import '../../../../core/ui/an_menu.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_toast.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/workflow_editor_provider.dart';
import '../../state/detail/workflow_editor_state.dart';
import '../../state/selected_entity.dart';
import 'workflow_editor_inspector.dart';

/// The full-screen graph editor (WRK-055 W5) — a distinct route, NOT the three-island shell: a top
/// toolbar (back · add-node · auto-layout · direction · save/discard) + the [AnGraphCanvas] in EDIT
/// mode + a right inspector. All edits mutate a local working graph via [workflowEditorProvider]; save
/// diffs it into one `:edit` (one version). Back returns to the entity page.
///
/// 全屏图编辑器(W5)——独立路由、非三岛壳:顶工具条(返回·加节点·自动布局·方向·保存/放弃)+ 编辑态
/// [AnGraphCanvas] + 右检查器。所有编辑改本地 working 图(workflowEditorProvider);保存 diff 成一个
/// `:edit`(一版)。返回回实体页。
class WorkflowEditorPage extends ConsumerWidget {
  const WorkflowEditorPage({required this.workflowId, super.key});

  final String workflowId;

  EntityRef get _ref => EntityRef(EntityKind.workflow, workflowId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final d = context.t.entities.detail;
    final async = ref.watch(workflowEditorProvider(_ref));
    final notifier = ref.read(workflowEditorProvider(_ref).notifier);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(children: [
          _toolbar(context, ref, async.value, notifier),
          Expanded(
            child: async.when(
              loading: () => const Center(child: AnState(kind: AnStateKind.loading, title: '')),
              error: (_, _) => Center(
                  child: AnState(
                      kind: AnStateKind.error, size: AnStateSize.inset, title: d.state.errorTitle)),
              data: (st) => Row(children: [
                Expanded(
                  child: AnGraphCanvas(
                    graph: st.working,
                    dir: st.dir,
                    editable: true,
                    selectedNodeId: st.selectedNodeId,
                    selectedEdgeId: st.selectedEdgeId,
                    onNodeTap: notifier.selectNode,
                    onEdgeTap: notifier.selectEdge,
                    onNodeMoved: notifier.moveNode,
                    onConnect: (from, to) {
                      final reason = notifier.connect(from, to);
                      if (reason != null) {
                        ref
                            .read(overlayProvider.notifier)
                            .showToast(_edgeError(context, reason), tone: AnToastTone.warn);
                      }
                    },
                  ),
                ),
                Container(width: AnSize.rightIsland, color: c.surface, child: WorkflowEditorInspector(entityRef: _ref)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _toolbar(BuildContext context, WidgetRef ref, WorkflowEditorState? st, WorkflowEditorNotifier notifier) {
    final c = context.colors;
    final d = context.t.entities.detail;
    final e = d.editor;
    final dirty = st?.dirty ?? false;
    final saving = st?.saving ?? false;
    return Container(
      height: AnSize.islandHead + AnSpace.s8,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
      ),
      child: Row(children: [
        AnButton(
          label: e.back,
          variant: AnButtonVariant.ghost,
          size: AnButtonSize.sm,
          onPressed: () => _exit(context),
        ),
        const SizedBox(width: AnSpace.s12),
        // Add-node menu (the 5 kinds). 加节点菜单(5 类)。
        AnMenu(
          entries: [
            for (final k in const [NodeKind.trigger, NodeKind.action, NodeKind.agent, NodeKind.control, NodeKind.approval])
              AnMenuItem(
                label: _kindLabel(context, k),
                icon: AnIcons.node(k.name),
                onTap: () => notifier.addNode(k),
              ),
          ],
          anchorBuilder: (context, toggle, isOpen) => AnButton(
            label: e.addNode,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            onPressed: st == null ? null : toggle,
          ),
        ),
        AnButton(
          label: e.autoLayout,
          icon: AnIcons.byKey('spin'),
          variant: AnButtonVariant.ghost,
          size: AnButtonSize.sm,
          onPressed: st == null ? null : notifier.autoLayout,
        ),
        // Direction menu. 方向菜单。
        AnMenu(
          entries: [
            AnMenuItem(label: e.dirLR, checked: st?.dir == GraphDirection.lr, onTap: () => notifier.setDir(GraphDirection.lr)),
            AnMenuItem(label: e.dirTB, checked: st?.dir == GraphDirection.tb, onTap: () => notifier.setDir(GraphDirection.tb)),
          ],
          anchorBuilder: (context, toggle, isOpen) => AnButton(
            label: st?.dir == GraphDirection.tb ? e.dirTB : e.dirLR,
            variant: AnButtonVariant.ghost,
            size: AnButtonSize.sm,
            onPressed: st == null ? null : toggle,
          ),
        ),
        const Spacer(),
        if (dirty)
          Padding(
            padding: const EdgeInsets.only(right: AnSpace.s12),
            child: Text(e.unsaved, style: AnText.meta.copyWith(color: c.warn)),
          ),
        if (dirty)
          AnButton(
            label: e.discard,
            variant: AnButtonVariant.ghost,
            size: AnButtonSize.sm,
            onPressed: saving ? null : notifier.discard,
          ),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: e.save,
          icon: AnIcons.check,
          variant: AnButtonVariant.primary,
          size: AnButtonSize.sm,
          onPressed: (!dirty || saving)
              ? null
              : () async {
                  final ok = await notifier.save();
                  if (!context.mounted) return;
                  final st2 = ref.read(workflowEditorProvider(_ref)).value;
                  if (ok) {
                    ref.read(overlayProvider.notifier).showToast(e.saved, tone: AnToastTone.ok);
                  } else if ((st2?.saveError ?? '').isNotEmpty) {
                    ref.read(overlayProvider.notifier).showToast(st2!.saveError!, tone: AnToastTone.danger);
                  }
                },
        ),
      ]),
    );
  }

  void _exit(BuildContext context) => context.go(entityLocation(EntityKind.workflow, workflowId));

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

  static String _edgeError(BuildContext context, String reason) {
    final e = context.t.entities.detail.editor;
    return switch (reason) {
      'selfLoop' => e.errSelfLoop,
      'duplicateEdge' => e.errDuplicateEdge,
      'backEdgeSource' => e.errBackEdgeSource,
      'approvalPortsFull' => e.errApprovalPortsFull,
      _ => reason,
    };
  }
}
