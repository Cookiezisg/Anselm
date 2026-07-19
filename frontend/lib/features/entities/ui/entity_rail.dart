import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_kind.dart';
import '../data/entity_labels.dart';
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
        showNew: false, // entity creation is a later phase; the rail is read+select only in 4.1
        menuEntries: _menu(t, sort, showCount),
        // Navigate to set selection — the route is the source of truth (STEP 6). 导航即设选区(路由为真相)。
        onSelect: (id) {
          if (id == entitiesOverviewRowId) {
            context.go('/'); // the entities home = the Overview (no selection) 总览主页
            return;
          }
          final kind = kindForId(groups, id);
          if (kind != null) context.go(entityLocation(kind, id));
        },
        onFilterChanged: _onFilter,
        onLoadMore: _onLoadMore,
        onRetryLoad: _onLoadMore, // retry = just page again 重试即再翻
      ),
    );
  }

  /// The filter-row sliders menu — a single-select Sort section (recently active / created / name,
  /// client-side over the loaded rows) + a Display section (show counts). 排序单选 + 显示开关。
  List<AnMenuEntry> _menu(Translations t, RailSort sort, bool showCount) {
    void pick(RailSort s) => ref.read(railSortProvider.notifier).set(s);
    return [
      AnMenuSection(t.entities.sortLabel),
      AnMenuItem(label: t.entities.sortRecent, checked: sort == RailSort.recent, onTap: () => pick(RailSort.recent)),
      AnMenuItem(label: t.entities.sortCreated, checked: sort == RailSort.created, onTap: () => pick(RailSort.created)),
      AnMenuItem(label: t.entities.sortName, checked: sort == RailSort.name, onTap: () => pick(RailSort.name)),
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
}
