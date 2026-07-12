import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/graph/graph_model.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/shell/shell_chrome.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_deferred_loading.dart';
import '../../../../core/ui/an_divider.dart';
import '../../../../core/ui/an_floating_bar.dart';
import '../../../../core/ui/an_graph_canvas.dart';
import '../../../../core/ui/an_inspector.dart';
import '../../../../core/ui/an_island.dart';
import '../../../../core/ui/an_skeleton.dart';
import '../../../../core/ui/an_menu.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_window_controls.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/workflow_editor_provider.dart';
import '../../state/detail/workflow_editor_state.dart';
import '../../../../core/shell/right_panel.dart';
import '../../state/selected_entity.dart';
import 'workflow_editor_inspector.dart';

/// The full-screen graph editor (WRK-055 W5) — a distinct route, NOT the three-island shell, and
/// FRAMELESS: the canvas is full-bleed and the chrome floats OVER it as transparent pill clusters, not
/// a solid top bar. The top control row is banded on the OS traffic-lights' line and reserves their
/// zone with [AnWindowControls], so nothing overlaps the lights. Actions: back · add-node · auto-layout
/// · direction (left pill); unsaved · discard · save (right pill); the right-island toggle. The canvas
/// keeps its own zoom cluster, moved to the bottom-left to clear the top chrome. The right island is the
/// real collapsible one ([AnIsland] + the shared [rightPanelCollapsedProvider]); it holds the node/edge
/// inspector and slides away on toggle. All edits mutate a local working graph via
/// [workflowEditorProvider]; save diffs it into one `:edit` (one version). Back returns to the entity page.
///
/// 全屏图编辑器(W5)——独立路由、非三岛壳,且无边框:画布满铺,chrome 以透明浮层药丸浮在其上、非实心
/// 顶条。顶控行落在红绿灯线上、用 [AnWindowControls] 预留灯位,不压灯。动作:返回·加节点·自动布局·方向
/// (左药丸);未保存·放弃·保存(右药丸);右岛切换。画布自带缩放条移到左下、让开顶部 chrome。右岛是真·可
/// 收岛([AnIsland] + 共享 [rightPanelCollapsedProvider]),装节点/边检查器、切换时滑出。所有编辑改本地
/// working 图;保存 diff 成一个 `:edit`(一版)。返回回实体页。
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
    final collapsed = ref.watch(rightPanelCollapsedProvider);

    return Scaffold(
      backgroundColor: c.canvas,
      // stretch → the right island fills the full height (the shell's right-island spec), not a
      // content-height card floating mid-edge. stretch → 右岛满高(同壳右岛规格),非居中矮卡。
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(children: [
            // The canvas is full-bleed (frameless). Its zoom cluster floats bottom-left so it clears
            // the top chrome + the OS lights. 画布满铺(无边框);缩放条落左下、让开顶部 chrome 与红绿灯。
            Positioned.fill(
              child: async.when(
                // Deferred skeleton — the house loading idiom (a bare instant spinner flashed on
                // every entry since the graph fetch resolves in milliseconds over loopback).
                // 延迟骨架(房规):裸即时 spinner 在毫秒级 loopback 取图下每次进入都闪。
                loading: () => const AnDeferredLoading(child: Center(child: AnSkeleton.card())),
                error: (_, _) => Center(
                    child: AnState(
                        kind: AnStateKind.error, size: AnStateSize.inset, title: d.state.errorTitle)),
                data: (st) => AnGraphCanvas(
                  graph: st.working,
                  dir: st.dir,
                  editable: true,
                  toolbarAlignment: Alignment.bottomLeft,
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
                          .showToast(_edgeError(context, reason), tone: AnTone.warn);
                    }
                  },
                ),
              ),
            ),
            // Frameless top chrome: two independently-anchored transparent clusters (never one full-width
            // Spacer row that could overflow) — the left reserves the OS traffic-lights' zone. 无边框顶控:
            // 左右两簇各自锚定(无会溢出的满宽 Spacer 行),左簇预留红绿灯位。
            _leftChrome(context, ref, async.value, notifier),
            _rightChrome(context, ref, async.value, notifier),
          ]),
        ),
        // The real collapsible right island. 真·可收右岛。
        _CollapsibleInspector(entityRef: _ref, collapsed: collapsed),
      ]),
    );
  }

  /// The left chrome cluster: OS-lights reservation + the edit-tool pill. Anchored left, min-sized —
  /// it never fights the right cluster for width. 左簇:红绿灯预留 + 编辑工具药丸;左锚、min 宽,不与右簇争。
  Widget _leftChrome(BuildContext context, WidgetRef ref, WorkflowEditorState? st, WorkflowEditorNotifier notifier) {
    final e = context.t.entities.detail.editor;
    return Positioned(
      top: 0,
      left: AnSpace.s8,
      height: AnSize.titlebar, // centered controls sit on the traffic-lights' horizontal line 控件居中落灯线
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Reserve the OS traffic-lights' zone so nothing sits under them. 预留红绿灯位。
        const AnWindowControls(),
        const SizedBox(width: AnSpace.s4),
        AnFloatingBar(children: [
          AnButton(
            label: e.back,
            variant: AnButtonVariant.ghost,
            size: AnButtonSize.sm,
            onPressed: () => _exit(context, ref, dirty: st?.dirty ?? false),
          ),
          const AnDivider.vertical(),
          AnMenu(
            entries: [
              for (final k in const [
                NodeKind.trigger,
                NodeKind.action,
                NodeKind.agent,
                NodeKind.control,
                NodeKind.approval
              ])
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
          AnMenu(
            entries: [
              AnMenuItem(
                  label: e.dirLR,
                  checked: st?.dir == GraphDirection.lr,
                  onTap: () => notifier.setDir(GraphDirection.lr)),
              AnMenuItem(
                  label: e.dirTB,
                  checked: st?.dir == GraphDirection.tb,
                  onTap: () => notifier.setDir(GraphDirection.tb)),
            ],
            anchorBuilder: (context, toggle, isOpen) => AnButton(
              label: st?.dir == GraphDirection.tb ? e.dirTB : e.dirLR,
              variant: AnButtonVariant.ghost,
              size: AnButtonSize.sm,
              onPressed: st == null ? null : toggle,
            ),
          ),
        ]),
      ]),
    );
  }

  /// The right chrome cluster: unsaved marker + discard/save pill + the right-island toggle. Anchored
  /// right, min-sized. 右簇:未保存标记 + 放弃/保存药丸 + 右岛切换;右锚、min 宽。
  Widget _rightChrome(BuildContext context, WidgetRef ref, WorkflowEditorState? st,
      WorkflowEditorNotifier notifier) {
    final c = context.colors;
    final e = context.t.entities.detail.editor;
    final dirty = st?.dirty ?? false;
    final saving = st?.saving ?? false;
    final collapsed = ref.watch(rightPanelCollapsedProvider);
    // The secondary ghost actions (discard while dirty, reopen while collapsed) share ONE surface pill —
    // ghost buttons are transparent at rest and need a readable backing over the canvas. The primary
    // save is NOT in this pill (a filled button inside a bordered pill reads as an ugly double frame).
    // 次级 ghost 动作(脏时放弃 / 收起时重开)共用一张 surface 药丸——ghost 静止透明、画布上需底;主按钮
    // 保存不进药丸(填充钮套在描边药丸里=难看的双层框)。
    final ghostActions = <Widget>[
      if (dirty)
        AnButton(
          label: e.discard,
          variant: AnButtonVariant.ghost,
          size: AnButtonSize.sm,
          onPressed: saving ? null : notifier.discard,
        ),
      if (collapsed)
        AnButton.iconOnly(
          AnIcons.panelRight,
          size: AnButtonSize.sm,
          semanticLabel: context.t.shell.togglePanel,
          onPressed: () => ref.read(rightPanelCollapsedProvider.notifier).set(false),
        ),
    ];
    final VoidCallback? onSave = (!dirty || saving)
        ? null
        : () async {
            final ok = await notifier.save();
            if (!context.mounted) return;
            final st2 = ref.read(workflowEditorProvider(_ref)).value;
            if (ok) {
              ref.read(overlayProvider.notifier).showToast(e.saved, tone: AnTone.ok);
            } else if ((st2?.saveError ?? '').isNotEmpty) {
              ref.read(overlayProvider.notifier).showToast(st2!.saveError!, tone: AnTone.danger);
            }
          };
    return Positioned(
      top: 0,
      right: AnSpace.s8,
      height: AnSize.titlebar,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dirty)
          Padding(
            padding: const EdgeInsets.only(right: AnSpace.s8),
            child: Text(e.unsaved, style: AnText.meta.copyWith(color: c.warn)),
          ),
        if (ghostActions.isNotEmpty) ...[
          AnFloatingBar(children: ghostActions),
          const SizedBox(width: AnSpace.s6),
        ],
        // Save = the primary CTA, accent-filled with a soft float shadow to anchor it over the busy
        // canvas ([AnButton] elevated). 保存=主 CTA:accent 填充 + 柔和 float 阴影锚在繁忙画布上(AnButton elevated)。
        AnButton(
          label: e.save,
          icon: AnIcons.check,
          variant: AnButtonVariant.primary,
          elevated: true,
          onPressed: onSave,
        ),
      ]),
    );
  }

  /// Back guards unsaved edits: the provider is autoDispose (popping destroys the working graph),
  /// so a dirty exit confirms first — the page tracks the dirty flag two lines away; silently
  /// discarding on Back contradicted its own model (Discard is an explicit action).
  /// 返回带脏检查:provider autoDispose、pop 即毁 working 图——脏时先确认;页面本就持 dirty 标,
  /// Back 静默丢弃与自身模型矛盾(丢弃是显式动作)。
  Future<void> _exit(BuildContext context, WidgetRef ref, {required bool dirty}) async {
    if (dirty) {
      final e = context.t.entities.detail.editor;
      final ok = await ref.read(overlayProvider.notifier).confirm(
            title: e.discardConfirmTitle,
            message: e.discardConfirmMessage,
            confirmLabel: e.discardConfirmAction,
            cancelLabel: context.t.action.cancel,
            barrierLabel: context.t.action.cancel,
          );
      if (!ok || !context.mounted) return;
    }
    context.go(entityLocation(EntityKind.workflow, workflowId));
  }

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

/// The editor's right island — the SAME skin + reveal as the shell's inspector (app_shell.dart:168 +
/// an_shell _RightReveal): `AnIsland(child: AnInspector(headless: WorkflowEditorInspector))`, revealed
/// by animating the wrapper width 0↔the shared user-dragged width ([ShellChrome.rightWidth], WRK-061:
/// one width for ALL right islands).
/// When collapsed the content is excluded from focus/semantics/pointer (twin of the shell), and it
/// keeps only the shell's standard 8px breathing on top/right/bottom (flush to the canvas seam on the
/// left) — no titlebar-height gap, since the OS lights are on the LEFT, not over this island.
/// 编辑器右岛——与壳右岛同皮同揭示:`AnIsland(AnInspector(headless: 检查器))`,按共享 collapse 态动画收放
/// 0↔右岛宽;收起时内容排除出焦点/语义/指针(同壳);只留壳标准的 8px 顶/右/下留白(左缘贴画布缝)——无
/// 标题栏高的空洞(红绿灯在左、不压此岛)。
class _CollapsibleInspector extends ConsumerWidget {
  const _CollapsibleInspector({required this.entityRef, required this.collapsed});

  final EntityRef entityRef;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = AnMotionPref.reduced(context);
    // The shared user-dragged right width (one chrome across oceans). 共享用户拖宽(全海洋一份)。
    final rightWidth = ref.watch(shellChromeProvider.select((s) => s.rightWidth));
    final content = AnInspector(headless: true, child: WorkflowEditorInspector(entityRef: entityRef));
    final island = AnIsland(
      child: collapsed
          ? ExcludeFocus(child: ExcludeSemantics(child: IgnorePointer(child: content)))
          : content,
    );
    return AnimatedContainer(
      duration: reduced ? Duration.zero : AnMotion.mid,
      curve: AnMotion.easeOut,
      width: collapsed ? 0 : rightWidth,
      child: ClipRect(
        // Keep the island at its full width while the wrapper animates 0↔rightIsland (no reflow of the
        // inspector as it slides). 岛保持满宽,外层动画收放(滑动时检查器不重排)。
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: rightWidth,
          maxWidth: rightWidth,
          child: SizedBox(
            width: rightWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AnSize.shellPad,
                right: AnSize.shellPad,
                bottom: AnSize.shellPad,
              ),
              child: island,
            ),
          ),
        ),
      ),
    );
  }
}
