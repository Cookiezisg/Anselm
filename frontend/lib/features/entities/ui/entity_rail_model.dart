import '../../../core/model/sidebar_model.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/icons.dart';
import '../data/entity_kind.dart';
import '../data/entity_row.dart';
import '../state/rail_model.dart';
import '../state/rail_sort.dart';

/// Pure projection: the rail's [RailGroup]s → an [AnSidebarList] [SidebarModel]. Kept widget/context-free
/// so the mapping (one section per kind, per-kind status dot, id→kind lookup) is unit-tested without
/// pumping UI. The i18n strings are injected ([RailLabels]) rather than read from context here.
///
/// 纯投影:rail 的 RailGroup → AnSidebarList 的 SidebarModel。无 widget/context,使映射可脱 UI 单测;
/// i18n 文案注入而非此处读 context。
class RailLabels {
  const RailLabels(
      {required this.kindLabel, required this.newLabel, required this.filter, required this.overview});

  /// Display name for a kind section header (injected from i18n `ref.<kind>`). kind 段头名(i18n 注入)。
  final String Function(EntityKind) kindLabel;
  final String newLabel;
  final String filter;

  /// The fixed «总览» row label (i18n `entities.overview.title`). 固定总览行标签。
  final String overview;
}

/// The fixed Overview row's model id — never an entity id (mirrors scheduler's `schedulerOverviewRowId`).
/// Selecting it routes home to the Overview; it is the rail's entry back to the graph/counts homepage.
/// 固定总览行 id(非实体 id);选它回总览主页,是 rail 回图/清点主页的入口。
const entitiesOverviewRowId = '__entities_overview';

/// The at-a-glance status dot for a row — only kinds that carry runtime state get one (handler runtime,
/// workflow lifecycle/attention); function/agent rows have no inherent live state, so no dot. Folds raw
/// status strings through the shared [AnStatus.fromRaw]. 行状态点:仅有运行态的 kind 显(handler/workflow)。
AnStatus? railDot(EntityRow r) => switch (r.kind) {
      EntityKind.handler => AnStatus.fromRaw(r.runtimeState),
      EntityKind.workflow =>
        r.needsAttention ? AnStatus.wait : AnStatus.fromRaw(r.lifecycleState),
      // A trigger's live signal is whether its listener is hot (≥1 active workflow references it). trigger:listener 热则蓝点。
      EntityKind.trigger => r.listening == true ? AnStatus.run : null,
      EntityKind.function || EntityKind.agent || EntityKind.control || EntityKind.approval => null,
    };

/// Build the rail model: one flat group with a collapsible section per kind (icon + label + count),
/// entities as rows ordered by [sort]. Every kind head always renders (an empty kind = the collapsed shape
/// of a populated one — 空态=满态收起的形状). [showCount] gates the per-section count badge (the ⚙ "show
/// counts" toggle); a count only renders when it has货 (n>0), so an empty kind head shows no "0".
/// 构建 rail 模型:单平铺组 + 每 kind 一折叠段(按 sort 排序);每 kind 头恒渲(空 kind=满态收起形)。计数仅 showCount 开
/// 且 n>0 时渲(空组头不显「0」)。
SidebarModel buildRailModel(
  List<RailGroup> groups,
  RailLabels labels,
  RailSort sort, {
  bool showCount = true,
}) =>
    SidebarModel(
      newLabel: labels.newLabel,
      filterPlaceholder: labels.filter,
      groups: [
        SidebarGroup(
          types: [
            // The fixed «总览» row — headless, above every kind section (mirrors scheduler's pinned
            // Overview row); without it there is no rail entry back to the Overview homepage. 固定总览行:
            // 无头、置顶,对齐 scheduler 先例;没有它就没有回总览主页的入口。
            SidebarType(rows: [
              SidebarRow(id: entitiesOverviewRowId, label: labels.overview, icon: AnIcons.entities),
            ]),
            for (final g in groups)
              SidebarType(
                label: labels.kindLabel(g.kind),
                icon: AnIcons.byKey(g.kind.scopeKind),
                count: showCount && g.count > 0 ? g.count : null,
                pageKey: g.kind.name, // pagination axis — onLoadMore maps this back to the kind 分页轴
                hasMore: g.state.value?.hasMore ?? false,
                loadingMore: g.state.value?.loadingMore ?? false,
                rows: [
                  for (final row in sortRows(g.state.value?.rows ?? const <EntityRow>[], sort))
                    SidebarRow(id: row.id, label: row.name, dot: railDot(row)),
                ],
              ),
          ],
        ),
      ],
    );

/// Which kind owns [id] among the loaded rows (AnSidebarList's onSelect gives only the row id, so the
/// rail resolves the kind to build an [EntityRef]). 据已载行解出 id 所属 kind。
EntityKind? kindForId(List<RailGroup> groups, String id) {
  for (final g in groups) {
    if ((g.state.value?.rows ?? const <EntityRow>[]).any((r) => r.id == id)) {
      return g.kind;
    }
  }
  return null;
}
