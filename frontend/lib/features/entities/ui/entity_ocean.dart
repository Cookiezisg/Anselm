import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
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
import '../state/run/right_panel.dart';
import '../state/run/run_terminal_controller.dart';
import '../state/selected_entity.dart';
import 'detail/log_tab.dart';
import 'detail/run_cockpit_tab.dart';
import 'detail/ocean_header.dart';
import 'detail/overview/agent_overview.dart';
import 'detail/overview/function_overview.dart';
import 'detail/overview/handler_overview.dart';
import 'detail/overview/workflow_overview.dart';
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
  double _threshold = 64; // recomputed from the measured header height 据测得头高重算

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
            label: d.state.loadMore,
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
            _threshold = (box.size.height - AnSize.islandHead).clamp(
              8.0,
              600.0,
            );
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
                  // Rename = meta PATCH (kinds join as their pages are sculpted: function F2,
                  // workflow W2). 改名=meta PATCH(随各自雕琢批接入:function F2、workflow W2)。
                  onRename: switch (detail.ref.kind) {
                    EntityKind.function => (name) async {
                        await ref
                            .read(entityRepositoryProvider)
                            .patchFunctionMeta(detail.ref.id, {'name': name});
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
  };
}
