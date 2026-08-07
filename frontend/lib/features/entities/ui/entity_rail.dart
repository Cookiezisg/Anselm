import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_kind.dart';
import '../data/entity_labels.dart';
import '../data/entity_providers.dart';
import '../data/entity_repository.dart';
import '../data/entity_row.dart';
import '../state/entity_list_provider.dart';
import '../state/rail_model.dart';
import '../state/rail_sort.dart';
import '../state/selected_entity.dart';
import 'entity_rail_model.dart';

/// The left-island entity navigator. Watches [railModelProvider] (the 4 kinds' live list states) +
/// [selectedEntityProvider], resolves ONE of four screens — loading skeleton / error / empty / the
/// virtualized [AnSidebarList] of kind sections — and wires selection back to the URL. The rail's search
/// box drives the server-side `?search` ([entitySearchProvider], debounced), and each kind section's tail
/// drives [EntityListNotifier.loadMore] (keyset infinite scroll). All data flows through the repository
/// seam, so the gallery/tests drive every state with a fixture.
///
/// 左岛实体导航。watch railModel + selected,解出四态之一(骨架/错/空/虚拟化列表),选择写回 URL。搜索框驱动服务端
/// ?search(entitySearchProvider,防抖),每个 kind 段尾驱动 loadMore(keyset 无限下滑)。全数据过 repository 缝。
class EntityRail extends ConsumerStatefulWidget {
  const EntityRail({super.key});

  @override
  ConsumerState<EntityRail> createState() => _EntityRailState();
}

class _EntityRailState extends ConsumerState<EntityRail> {
  final _debounce = Debouncer(AnMotion.searchDebounce);

  EntityRepository get _repo => ref.read(entityRepositoryProvider);

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  // Debounce keystrokes before hitting the server-side ?search (the provider re-pages from the top on
  // change; firing per key would storm the backend). 逐键防抖再打服务端 ?search(每键一请求会打爆后端)。
  void _onFilter(String v) => _debounce.run(() {
    if (mounted) ref.read(entitySearchProvider.notifier).set(v);
  });

  // A kind section's tail fires with that kind's pageKey → page THAT kind's list (each kind is its own
  // keyset axis). 段尾携该 kind 的 pageKey → 翻该 kind 的列表(每 kind 独立 keyset 轴)。
  void _onLoadMore(String pageKey) {
    // pageKey is a kind.name set by the rail model; an unknown key means nothing to page (don't silently
    // fall back to some default kind's list). pageKey 是 rail 模型给的 kind.name;未知键=无可翻,不静默兜底翻别的。
    final kind = EntityKind.values.where((k) => k.name == pageKey).firstOrNull;
    if (kind == null) return;
    ref.read(entityListProvider(kind).notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(railModelProvider);
    final selected = ref.watch(selectedEntityProvider);
    final sort = ref.watch(railSortProvider);
    final showCount = ref.watch(railShowCountProvider);
    final t = context.t;

    // The two placeholder states are an AGGREGATE over the 4 kind lists: loading = nothing resolved yet;
    // error = every kind failed with nothing to show. Zero rows across all kinds is NOT a state — the list
    // renders its chrome + all seven (empty) kind heads (满态收起的形状). 两占位态是 kind 列表的聚合:载=尚无一解 /
    // 错=全 kind 失败且无可显;全 kind 零行不是态,直落列表(渲 chrome + 七个空 kind 组头)。
    final anyData = groups.any((g) => g.state.hasValue);
    return AnRailStates(
      loading: !anyData && groups.any((g) => g.state.isLoading),
      error: !anyData && groups.every((g) => g.state.hasError),
      strings: AnRailStrings(
        errorTitle: t.entities.errorTitle,
        errorHint: t.entities.errorHint,
        retry: t.entities.retry,
      ),
      onRetry: _retryAll,
      builder: () => AnSidebarList(
        model: buildRailModel(
          groups,
          RailLabels(
            kindLabel: (k) => k.typeLabel(t),
            newLabel: t.entities.kNew,
            filter: t.entities.filter,
            overview: t.entities.overview.title,
          ),
          sort,
          showCount: showCount,
        ),
        // No entity selected → the fixed «总览» row is the active one (the ocean is showing the Overview
        // home). 无实体选中→总览行高亮(海洋正显总览主页)。
        selectedId: selected?.id ?? entitiesOverviewRowId,
        showNew:
            false, // entity creation is a later phase; the rail is read+select only in 4.1
        menuEntries: _menu(t, sort, showCount),
        // Navigate to set selection — the route is the source of truth (STEP 6). 导航即设选区(路由为真相)。
        onSelect: (id) {
          if (id == entitiesOverviewRowId) {
            context.go(
              '/',
            ); // the entities home = the Overview (no selection) 总览主页
            return;
          }
          final kind = kindForId(groups, id);
          if (kind != null) context.go(entityLocation(kind, id));
        },
        onFilterChanged: _onFilter,
        filterEmptyLabel: t.entities.noResults,
        onLoadMore: _onLoadMore,
        onRetryLoad: _onLoadMore, // retry = just page again 重试即再翻
        rowActionsBuilder: (id) {
          // the pinned Overview row carries no ⋯ 总览行无 ⋯
          if (id == entitiesOverviewRowId) return const [];
          final kind = kindForId(groups, id);
          final row = kind == null ? null : rowForId(groups, id);
          if (kind == null || row == null) return const [];
          return [_rowMenu(t, kind, row)];
        },
      ),
    );
  }

  /// The filter-row sliders menu — a single-select Sort section (recently active / created / name,
  /// client-side over the loaded rows) + a Display section (show counts). 排序单选 + 显示开关。
  List<AnMenuEntry> _menu(Translations t, RailSort sort, bool showCount) {
    void pick(RailSort s) => ref.read(railSortProvider.notifier).set(s);
    return [
      AnMenuSection(t.entities.sortLabel),
      AnMenuItem(
        label: t.entities.sortRecent,
        checked: sort == RailSort.recent,
        onTap: () => pick(RailSort.recent),
      ),
      AnMenuItem(
        label: t.entities.sortCreated,
        checked: sort == RailSort.created,
        onTap: () => pick(RailSort.created),
      ),
      AnMenuItem(
        label: t.entities.sortName,
        checked: sort == RailSort.name,
        onTap: () => pick(RailSort.name),
      ),
      AnMenuSection(t.entities.displayLabel),
      AnMenuItem(
        label: t.entities.showCount,
        checked: showCount,
        keepOpen: true,
        onTap: () => ref.read(railShowCountProvider.notifier).toggle(),
      ),
    ];
  }

  void _retryAll() {
    for (final kind in EntityKind.values) {
      ref.invalidate(entityListProvider(kind));
    }
  }

  // ── per-row ⋯ menu (hover-revealed, WRK-077 施工序⑩/EA) ───────────────────
  //
  // Every kind shares three items — Open (navigate) · Edit with AI (`:iterate`, in place) · Delete
  // (danger + confirm) — plus kind-specific ones. The HONESTY RULE (most important): an action that
  // needs the user's own typed arguments (`:run`/`:call`/`:invoke` all require an `args`/`input` body;
  // workflow `:trigger`'s optional payload still deserves the SAME review the app's ONE execution point
  // gives every other verb, 0718 拍板) never fires blind from a menu tap — those items only NAVIGATE to
  // the entity (which reveals the right-island debugger for the now-selected entity, `runTerminalProvider`
  // family keyed off [selectedEntityProvider] — mirrors the `reproduce` action in log_tab.dart). Only
  // truly parameter-free actions (restart / activate / deactivate / pause / resume / delete) execute in
  // place. `:iterate` sends a FIXED canned opening line (never free-typed user args, mirroring `:fire`'s
  // synthesized `{manual:true}`) because the backend needs a non-blank `request`. The line includes
  // the entity name deliberately: it makes the immediately-created conversation identifiable in the
  // chat rail before the user has typed a more specific request. The real free-form ask happens in the
  // chat conversation this opens, same as any new thread.
  //
  // 每 kind 共三项——打开(导航)· AI 编辑(`:iterate`,就地)· 删除(danger+确认)——外加 kind 专属项。诚实律
  // (最重要):需要用户自己填参数的动作(`:run`/`:call`/`:invoke` 都要 args/input 体;workflow `:trigger` 的
  // payload 虽可选,但理应享有本 app 唯一执行点给其余动词的同一份复核,0718 拍板)绝不在菜单里盲跑——这些项只
  // 导航到实体(此举据 selectedEntityProvider 揭示右岛调试台,镜像 log_tab.dart 的「用这份输入」)。只有真正
  // 无参的动作(重启/上线/下线/暂停/恢复/删除)就地执行。`:iterate` 发一句固定开场白(绝非用户自由参数,镜像
  // `:fire` 合成的 `{manual:true}`)——因为后端需要非空 request;开场白刻意带实体名,让新会话在 chat rail
  // 里立即可识别;真正的自由诉求在随后打开的对话里,如同任何新线程。
  Widget _rowMenu(Translations t, EntityKind kind, EntityRow row) {
    final rm = t.entities.rail.menu;
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(
          label: rm.open,
          icon: AnIcons.open,
          onTap: () => context.go(entityLocation(kind, row.id)),
        ),
        if (kind == EntityKind.function)
          AnMenuItem(
            label: rm.run,
            icon: AnIcons.run,
            onTap: () => _openDebugger(kind, row.id),
          ),
        if (kind == EntityKind.handler) ...[
          AnMenuItem(
            label: rm.call,
            icon: AnIcons.run,
            onTap: () => _openDebugger(kind, row.id),
          ),
          AnMenuItem(
            label: rm.restart,
            icon: AnIcons.refresh,
            onTap: () => _restartHandler(row.id),
          ),
        ],
        if (kind == EntityKind.agent)
          AnMenuItem(
            label: rm.invoke,
            icon: AnIcons.run,
            onTap: () => _openDebugger(kind, row.id),
          ),
        if (kind == EntityKind.workflow) ...[
          AnMenuItem(
            label: rm.triggerNow,
            icon: AnIcons.run,
            onTap: () => _openDebugger(kind, row.id),
          ),
          // Activate/deactivate are the SAME slot, picked by the row's current lifecycle — never both
          // (the task's «二选一、不并列» rule). 同一格位按现态二选一(不并列)。
          AnMenuItem(
            label: row.lifecycleState == 'active' ? rm.deactivate : rm.activate,
            icon: row.lifecycleState == 'active' ? AnIcons.pause : AnIcons.run,
            onTap: () => _toggleWorkflowLifecycle(row),
          ),
          AnMenuItem(
            label: rm.openEditor,
            icon: AnIcons.edit,
            onTap: () => context.go(workflowEditorLocation(row.id)),
          ),
        ],
        if (kind == EntityKind.trigger)
          // Pause/resume are the SAME slot, picked by the row's persisted `paused` — never both.
          // 同一格位按 paused 二选一(不并列)。
          AnMenuItem(
            label: row.paused == true ? rm.resume : rm.pause,
            icon: row.paused == true ? AnIcons.run : AnIcons.pause,
            onTap: () => _toggleTriggerPaused(row),
          ),
        AnMenuItem(
          label: rm.iterate,
          icon: AnIcons.iterate,
          onTap: () => _iterate(kind, row),
        ),
        AnMenuItem(
          label: t.action.delete,
          icon: AnIcons.trash,
          danger: true,
          onTap: () => _confirmDelete(kind, row),
        ),
      ],
    );
  }

  // Navigate to the entity (sets selection) AND force the right island open — the entity ocean's
  // right-island run terminal is bound to the SELECTED entity ([runTerminalProvider] family), so
  // selecting it is what makes "the detail debugger" show THIS entity; the explicit `.set(false)`
  // guarantees it's visible even if the user had previously collapsed it (same gesture as log_tab.dart's
  // «reproduce» action). 导航即设选区 + 强制展开右岛(run 终端按选区绑定;显式展开防用户曾收起)。
  void _openDebugger(EntityKind kind, String id) {
    context.go(entityLocation(kind, id));
    ref.read(rightPanelCollapsedProvider.notifier).set(false);
  }

  Future<void> _restartHandler(String id) async {
    try {
      await _repo.restartHandler(id);
      ref.invalidate(entityListProvider(EntityKind.handler));
    } catch (error) {
      _noticeFail(error);
    }
  }

  Future<void> _toggleWorkflowLifecycle(EntityRow row) async {
    try {
      if (row.lifecycleState == 'active') {
        await _repo.deactivateWorkflow(row.id);
      } else {
        await _repo.activateWorkflow(row.id);
      }
      ref.invalidate(entityListProvider(EntityKind.workflow));
    } catch (error) {
      _noticeFail(error);
    }
  }

  Future<void> _toggleTriggerPaused(EntityRow row) async {
    try {
      if (row.paused == true) {
        await _repo.resumeTrigger(row.id);
      } else {
        await _repo.pauseTrigger(row.id);
      }
      // Unlike restart/activate/deactivate (which ALSO get an independent durable lifecycle signal —
      // this invalidate is belt-and-suspenders there), :pause/:resume fan ONLY an ephemeral panel
      // signal — this invalidate is the ONLY thing that keeps the row's «Pause»/«Resume» label from
      // going stale. 不同于重启/上线/下线(还另有 durable 生命周期信号兜底,这里的 invalidate 是双保险);
      // :pause/:resume 只发 ephemeral 面板信号——这行 invalidate 是行标签不卡旧态的唯一保障。
      ref.invalidate(entityListProvider(EntityKind.trigger));
    } catch (error) {
      _noticeFail(error);
    }
  }

  Future<void> _iterate(EntityKind kind, EntityRow row) async {
    final t = context.t;
    try {
      final name = row.name.trim().isEmpty ? row.id : row.name.trim();
      final convId = await _repo.iterateEntity(
        kind,
        row.id,
        request: t.entities.rail.iterateRequest(name: name),
      );
      if (!mounted) return;
      // Cross-feature nav by literal path (features/* don't import each other, ADR 0004) — mirrors
      // scheduler_run.dart/scheduler_run_inspector.dart's own `context.go('/chat/$id')`. 跨 feature 走字面
      // 路径(features 互不依赖),镜像 scheduler 侧既有先例。
      context.go('/chat/$convId');
    } catch (error) {
      _noticeFail(error);
    }
  }

  Future<void> _confirmDelete(EntityKind kind, EntityRow row) async {
    final t = context.t;
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.entities.rail.deleteTitle,
          message: t.entities.rail.deleteBody(
            name: row.name.trim().isEmpty ? '…' : row.name,
          ),
          confirmLabel: t.action.delete,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
    if (!ok) return;
    try {
      await _repo.deleteEntity(kind, row.id);
      ref.invalidate(entityListProvider(kind));
      if (!mounted) return;
      // Deleting the open entity leaves a dead detail — clear the selection (route is the truth).
      // 删选中即清选区(路由为真相)。
      if (ref.read(selectedEntityProvider) == EntityRef(kind, row.id)) {
        context.go('/');
      }
    } catch (error) {
      _noticeFail(error);
    }
  }

  void _noticeFail(Object error) {
    if (!mounted) return;
    ref
        .read(noticeCenterProvider.notifier)
        .show(_actionFailureCopy(context.t, error), tone: AnTone.danger);
  }
}

String _actionFailureCopy(Translations t, Object error) {
  if (error is! ApiException) return t.entities.rail.actionFailed;

  if (error.code == 'WORKFLOW_NOT_RUNNABLE') {
    final problem = _firstWorkflowProblem(error.details);
    return problem == null
        ? t.entities.rail.workflowNotRunnable
        : _workflowProblemCopy(t, problem);
  }

  final reason = error.message.trim();
  return reason.isEmpty
      ? t.entities.rail.actionFailed
      : t.entities.rail.actionFailedWithReason(reason: reason);
}

String _workflowProblemCopy(Translations t, String problem) {
  final ref = _missingReference(problem);
  return ref == null
      ? t.entities.rail.workflowNotRunnableWithProblem(problem: problem)
      : t.entities.rail.workflowMissingReference(ref: ref);
}

String? _missingReference(String problem) {
  final match = RegExp(r'ref "([^"]+)" not found').firstMatch(problem);
  return match?.group(1);
}

String? _firstWorkflowProblem(Object? details) {
  if (details is! Map) return null;
  final problems = details['problems'];
  if (problems is! List) return null;
  for (final value in problems) {
    final problem = '$value'.trim();
    if (problem.isNotEmpty) return problem;
  }
  return null;
}
