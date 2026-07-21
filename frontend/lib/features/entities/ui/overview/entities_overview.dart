import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/contract/entities/relation.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/time_format.dart';
import '../../../../core/shell/shell_chrome.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_row.dart';
import '../../state/entities_overview_model.dart';
import '../../state/rail_model.dart';
import '../../state/rel_graph_provider.dart';
import '../graph/graph_labels.dart';

/// The Entities Overview — `/entities` (or `/`) with nothing selected, the ocean's DEFAULT home (retiring
/// the "select an entity" tombstone). Three stacked sections in the 720 reading column: the five clip
/// tiles (four Quadrinity + a "Parts" accessory total) → the RELATIONSHIP GRAPH (the star, a framed
/// force-directed preview that pans/zooms in its own box; a node/expand enters the full-page explore
/// state) → the «最近更新» top-5 ledger. Breadcrumb law (用户 0718): grey crumb = `Entities` (parent only),
/// big title = 总览, and the floating head shows ONLY 总览 (never the full path).
///
/// Entities 总览:无选中时的海洋默认主页(退役「选择实体」墓碑)。720 列内三段:五牌(四大 + 配件合计)→ 关系图
/// (主角,framed 力导向预览,框内平移缩放;点节点/展开进全页探索)→ 最近更新 top5 台账。面包屑律:灰 crumb=Entities
/// (只到上级)、大标题=总览、浮层头只显「总览」。
class EntitiesOverviewView extends ConsumerStatefulWidget {
  const EntitiesOverviewView({super.key});

  @override
  ConsumerState<EntitiesOverviewView> createState() =>
      _EntitiesOverviewViewState();
}

class _EntitiesOverviewViewState extends ConsumerState<EntitiesOverviewView> {
  final ScrollController _scroll = ScrollController();

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
    final collapsed = _scroll.hasClients && _scroll.offset > AnSpace.s64;
    ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.entities;
    final groups = ref.watch(railModelProvider);
    final graphAsync = ref.watch(relGraphProvider);

    // Bind the floating head post-frame — ONLY the page title (用户 0718 breadcrumb law: the floating head
    // shows «总览», not «Entities / 总览»). 浮层头只绑标题。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(shellHeadProvider.notifier)
            .bind(t.overview.title, _scrollToTop);
      }
    });

    return AnPage(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Overview IS the Entities root — «Entities» is the current context (inert), 总览 the title.
          // 总览即 Entities 根:「Entities」是当前上下文(惰性),黑字=总览。
          AnOceanHeader(
            crumbs: [AnCrumb(t.detail.crumbRoot)],
            title: t.overview.title,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.section),
            child: _ClipTiles(counts: overviewCounts(groups)),
          ),
          AnSection(
            label: t.overview.graphHead,
            variant: AnSectionVariant.plain,
            children: [_graphSection(context, graphAsync, groups)],
          ),
          AnSection(
            label: t.overview.recentHead,
            variant: AnSectionVariant.plain,
            children: [_recentLedger(context, groups)],
          ),
        ],
      ),
    );
  }

  Widget _graphSection(
    BuildContext context,
    AsyncValue<EntityRelGraph> async,
    List<RailGroup> groups,
  ) {
    final t = context.t.entities;
    return async.when(
      loading: () => const AnDeferredLoading(child: AnSkeleton.card()),
      error: (_, _) => AnState(
        kind: AnStateKind.error,
        title: t.errorTitle,
        hint: t.errorHint,
        action: AnButton(
          label: t.retry,
          onPressed: () => ref.invalidate(relGraphProvider),
        ),
      ),
      data: (g) {
        final sub = structuralSubgraph(g);
        final kindOf = {for (final n in sub.nodes) n.id: n.kind};
        return AnRelationGraph(
          nodes: sub.nodes,
          edges: sub.edges,
          framed: true,
          // Default ripple focus = the most-recently-touched entity that's on the graph (rail freshness ⋈
          // graph nodes). 默认涟漪焦点=最近碰过且在图上的实体。
          focusId: mostRecentGraphNodeId(sub.nodes, groups),
          nodeSemanticLabel: (n, deg) => relationNodeLabel(context, n, deg),
          edgeSemanticLabel: (e) => relationEdgeLabel(context, e),
          semanticSummary: context.t.a11y.relationSummary(
            nodes: '${sub.nodes.length}',
            edges: '${sub.edges.length}',
          ),
          expandLabel: t.overview.title,
          onExpand: () => context.go('/entities/graph'),
          // Single tap on the preview → open the full-page explore state (pre-selected). 单击→全页探索(预选)。
          onNodeTap: (id) {
            if (id == null) return;
            final kind = kindOf[id];
            context.go(
              kind == null
                  ? '/entities/graph'
                  : '/entities/graph?sel=$kind:$id',
            );
          },
          // Double tap → jump straight to the entity's detail page (rail kinds only). 双击→直进实体页(仅 rail kind)。
          onNodeDoubleTap: (id) {
            final ek = entityKindFromWire(kindOf[id]);
            if (ek != null) context.go(entityLocation(ek, id));
          },
        );
      },
    );
  }

  Widget _recentLedger(BuildContext context, List<RailGroup> groups) {
    final rows = recentEntities(groups, max: 5);
    if (rows.isEmpty) {
      return Text(
        context.t.entities.selectHint,
        style: AnText.body.copyWith(color: context.colors.inkFaint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final r in rows) _recentRow(context, r)],
    );
  }

  Widget _recentRow(BuildContext context, EntityRow row) {
    final c = context.colors;
    return AnLedgerRow(
      lead: Icon(
        AnIcons.byKey(row.kind.scopeKind),
        size: AnSize.icon,
        color: c.inkFaint,
      ),
      primary: row.name.isEmpty ? row.id : row.name,
      mono: false,
      chips: [
        if (row.version != null)
          AnChip('v${row.version}', look: AnChipLook.outlined),
      ],
      meta: fmtWaitedSince(row.updatedAt),
      onTap: () => context.go(entityLocation(row.kind, row.id)),
    );
  }
}

/// The five clip tiles — four Quadrinity + a folded "Parts" total (trigger+control+approval). Always
/// present, 0 shows 0 (a constant clip, not a vanity number); inert (the rail is right there). 五牌:恒在,
/// 0 显 0,不可点。
class _ClipTiles extends StatelessWidget {
  const _ClipTiles({required this.counts});
  final OverviewCounts counts;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tiles = <Widget>[
      _tile(context, AnIcons.function, t.ref.function, counts.function),
      _tile(context, AnIcons.handler, t.ref.handler, counts.handler),
      _tile(context, AnIcons.agent, t.ref.agent, counts.agent),
      _tile(context, AnIcons.workflow, t.ref.workflow, counts.workflow),
      _tile(
        context,
        AnIcons.sliders,
        t.entities.overview.accessory,
        counts.accessory,
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AnGap.block),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, int count) {
    final c = context.colors;
    return AnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: AnSize.icon, color: c.inkFaint),
              const SizedBox(width: AnGap.inline),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: AnGap.stackTight),
          AnCountUp(count, style: AnText.h2.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
