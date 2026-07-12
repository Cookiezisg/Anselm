import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_tabs.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_kind.dart';
import '../data/entity_providers.dart';
import '../state/detail/entity_detail.dart';
import '../state/detail/entity_detail_provider.dart';
import '../state/detail/observability_list_provider.dart';
import '../../../core/shell/right_panel.dart';
import '../state/run/run_terminal_controller.dart';
import '../state/selected_entity.dart';
import 'detail/log_tab.dart';
import 'detail/run_cockpit_tab.dart';
import 'detail/ocean_header.dart';
import 'detail/overview/agent_overview.dart';
import 'detail/overview/approval_overview.dart';
import 'detail/overview/control_overview.dart';
import 'detail/overview/function_overview.dart';
import 'detail/overview/handler_overview.dart';
import 'detail/overview/trigger_overview.dart';
import 'detail/overview/workflow_overview.dart';
import 'detail/trigger_observability_tab.dart';
import 'detail/version_tab.dart';

/// The detail "ocean" (the open window surface). Reads [selectedEntityProvider]: null → empty state;
/// else watches [entityDetailProvider] → loading skeleton / error+retry / the header + 概览/版本/日志 tabs.
/// The selected tab is local widget state and resets to overview when the selection changes. STEP 4:
/// verb CTA + rename + build-mirror are disabled stubs (STEP 5). 详情海洋:选中→详情头 + 三 tab。
class EntityOcean extends ConsumerStatefulWidget {
  const EntityOcean({super.key});

  @override
  ConsumerState<EntityOcean> createState() => _EntityOceanState();
}

class _EntityOceanState extends ConsumerState<EntityOcean> {
  String _tab = 'overview';

  // The ocean's single scroll controller — drives the floating-head breadcrumb (collapsed once the big
  // in-content title scrolls past the head). 海洋唯一滚动控制器,驱动浮层头面包屑折叠。
  final ScrollController _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  double _threshold = AnSpace.s64; // pre-measure fallback; recomputed from the measured header height 测量前兜底,据测得头高重算

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed = _scroll.hasClients && _scroll.offset > _threshold;
    ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final selected = ref.watch(selectedEntityProvider);

    // Reset to overview + scroll-to-top + clear the breadcrumb collapse whenever the selection changes.
    // 选区变化:回概览 tab + 滚到顶 + 清面包屑折叠。
    ref.listen(selectedEntityProvider, (prev, next) {
      if (prev == next) return;
      if (_tab != 'overview') setState(() => _tab = 'overview');
      if (_scroll.hasClients) _scroll.jumpTo(0);
      ref.read(shellHeadProvider.notifier).setCollapsed(false);
    });

    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(shellHeadProvider.notifier).clear();
      });
      return Center(
        child: AnState(
          kind: AnStateKind.empty,
          title: context.t.entities.selectTitle,
          hint: context.t.entities.selectHint,
        ),
      );
    }

    final async = ref.watch(entityDetailProvider(selected));
    return async.when(
      // Loading lives in the SAME AnPage (centered 720 column) as the loaded content, so there is no
      // width jump when data arrives; deferred so a fast load never flashes a skeleton. 同 720 列 + 延迟防闪。
      loading: () => const AnPage(
        child: AnDeferredLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnSkeleton.card(),
              SizedBox(height: AnSpace.s16),
              AnSkeleton.lines(6),
            ],
          ),
        ),
      ),
      error: (_, _) => Center(
        child: AnState(
          kind: AnStateKind.error,
          title: d.state.errorTitle,
          hint: d.state.errorHint,
          action: AnButton(
            label: d.state.retry,
            onPressed: () => ref.invalidate(entityDetailProvider(selected)),
          ),
        ),
      ),
      // ONE document: header + tabs + content all live in a single AnPage (centered 720 reading column,
      // one scroll) and scroll together — AnTabs in FLOW mode so the selected pane flows inline (the demo
      // an-page/an-tabs model). 整个海洋一份文档:头+tab+内容同在一个 AnPage(居中 720 单滚)一起滚。
      data: (detail) {
        // After layout: measure the big header (the collapse threshold = its height past the head band)
        // and feed the floating-head breadcrumb (title + scroll-to-top). 测大头高定阈值 + 喂浮层头面包屑。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box =
              _headerKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            // Measured height is trusted — floor only (a giant header simply collapses later).
            // 实测头高可信——只设下界(巨头正常晚折叠)。
            _threshold =
                math.max(AnSpace.s8, box.size.height - AnSize.islandHead);
          }
          ref.read(shellHeadProvider.notifier).bind(detail.name, _scrollToTop);
        });
        return AnPage(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: _headerKey,
                child: EntityOceanHeader(
                  detail: detail,
                  // The right island is bound to the selection; the verb CTA reveals it then fires the run
                  // (header CTA = trigger run, demo-aligned). 头部动词钮:展开右岛 + 直接执行。
                  onVerb: () {
                    ref.read(rightPanelCollapsedProvider.notifier).set(false);
                    ref.read(runTerminalProvider(detail.ref).notifier).run();
                  },
                  // Trigger's Fire CTA: `:fire` a manual signal (→ an activation, NOT a run terminal),
                  // toast the new activation id, then refresh the activity list + lastFired badge.
                  // trigger 的 Fire:手动催一次 → toast 新 activation id → 刷新活动列表 + 徽标。
                  onFire: detail.ref.kind == EntityKind.trigger
                      ? () async {
                          final tr = context.t.entities.detail.trigger;
                          // Capture before the await — the ocean may dispose mid-fire. 取在 await 前(催发途中海洋可能释放)。
                          final repo = ref.read(entityRepositoryProvider);
                          final overlay = ref.read(overlayProvider.notifier);
                          try {
                            final actId = await repo.fireTrigger(detail.ref.id);
                            if (!mounted) return;
                            // A fire writes a new activation AND fans out firings — refresh both observability
                            // streams + the lastFired badge. 一次 fire 产 activation + firing,两观测面 + 徽标都刷。
                            ref.invalidate(activationListProvider);
                            ref.invalidate(firingListProvider);
                            ref.invalidate(entityDetailProvider(detail.ref));
                            overlay.showToast(tr.firedToast(id: actId));
                          } catch (_) {
                            overlay.showToast(tr.fireFailed, tone: AnTone.danger);
                          }
                        }
                      : null,
                  // Rename = meta PATCH (kinds join as their pages are sculpted: function F2,
                  // workflow W2, handler). 改名=meta PATCH(随各自雕琢批接入:function、workflow、handler)。
                  onRename: switch (detail.ref.kind) {
                    EntityKind.function => (name) async {
                        await ref
                            .read(entityRepositoryProvider)
                            .patchFunctionMeta(detail.ref.id, {'name': name});
                        ref.invalidate(entityDetailProvider(detail.ref));
                      },
                    EntityKind.handler => (name) async {
                        await ref
                            .read(entityRepositoryProvider)
                            .patchHandlerMeta(detail.ref.id, {'name': name});
                        ref.invalidate(entityDetailProvider(detail.ref));
                      },
                    EntityKind.workflow => (name) async {
                        await ref
                            .read(entityRepositoryProvider)
                            .patchWorkflowMeta(detail.ref.id, {'name': name});
                        ref.invalidate(entityDetailProvider(detail.ref));
                      },
                    _ => null,
                  },
                ),
              ),
              AnTabs(
                flow: true,
                value: _tab,
                onSelect: (k) => setState(() => _tab = k),
                items: [
                  AnTabsItem(
                    key: 'overview',
                    label: d.tab.overview,
                    pane: _overview(detail),
                  ),
                  // Support kinds (control) are overview-only in the pilot — versions (structured branch
                  // diff) + no logs are a follow-up. 支撑 kind 暂概览-only(版本 diff 后续、无日志)。
                  if (detail.ref.kind.executable) ...[
                    AnTabsItem(
                      key: 'versions',
                      label: d.tab.versions,
                      pane: VersionTab(detail.ref),
                    ),
                    // Workflow's log IS its flowruns → the 运行 cockpit (run board + gantt + run graph +
                    // node debug, WRK-055 W4); other kinds keep the generic 日志 tab.
                    // workflow 的日志就是 flowrun → 运行驾驶舱;余 kind 走通用日志 tab。
                    if (detail.ref.kind == EntityKind.workflow)
                      AnTabsItem(
                        key: 'runs',
                        label: d.tab.runs,
                        pane: RunCockpitTab(detail.ref),
                      )
                    else
                      AnTabsItem(
                        key: 'logs',
                        label: d.tab.logs,
                        pane: LogTab(detail.ref),
                      ),
                  ]
                  // Trigger is unversioned but has two observability streams — 活动 (activations, 触发面) +
                  // 派发 (firings, 运行面) — as first-class tabs (two independent keyset cursors can't merge).
                  // trigger 无版本、有两条观测面 → 活动/派发首级 tab(两独立游标不可合并分页)。
                  else if (detail.ref.kind == EntityKind.trigger) ...[
                    AnTabsItem(
                      key: 'activity',
                      label: d.tab.activity,
                      pane: TriggerActivityTab(detail.ref.id),
                    ),
                    AnTabsItem(
                      key: 'dispatch',
                      label: d.tab.dispatch,
                      pane: TriggerDispatchTab(detail.ref.id),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _overview(EntityDetail d) => switch (d.ref.kind) {
    EntityKind.function => FunctionOverview(fn: d.function!),
    EntityKind.handler => HandlerOverview(hd: d.handler!),
    EntityKind.agent => AgentOverview(
      agent: d.agent!,
      mountHealth: d.mountHealth,
    ),
    EntityKind.workflow => WorkflowOverview(wf: d.workflow!),
    EntityKind.control => ControlOverview(control: d.control!),
    EntityKind.approval => ApprovalOverview(approval: d.approval!),
    EntityKind.trigger => TriggerOverview(trigger: d.trigger!),
  };
}
