import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/contract/entities/relation.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/shell/right_panel.dart';
import '../../../../core/shell/shell_chrome.dart';
import '../../../../core/runtime.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/entities_overview_model.dart';
import '../../state/rail_model.dart';
import '../../state/rel_graph_provider.dart';
import 'graph_entity_card.dart';
import 'graph_labels.dart';

/// The full-page relationship-graph EXPLORE state (`/entities/graph`, optional `?sel=kind:id`) — a
/// distinct frameless route (NOT the three-island shell), width-aligned to the workflow graph editor
/// precedent: a full-bleed canvas with transparent floating chrome and a real collapsible right island.
/// The kind legend doubles as the show/hide filter (one row of colour chips), the "show provenance" toggle
/// re-admits create/edit edges + conversation nodes (default off), Esc returns to the Overview, and
/// selection is derived one-way from the URL's `?sel`.
///
/// 全页关系图探索态(/entities/graph,可带 ?sel=kind:id)——独立无边框路由(非三岛壳),宽度对齐 workflow 图
/// 编辑器先例:满铺画布 + 透明浮层 chrome + 真·可收右岛。kind 图例即显隐过滤(一行色点),「显示溯源」开关默认关
/// (开后纳入 create/edit 边 + 对话节点),Esc 回总览,选区单向派生自 URL 的 ?sel。
class EntitiesGraphPage extends ConsumerStatefulWidget {
  const EntitiesGraphPage({super.key});

  @override
  ConsumerState<EntitiesGraphPage> createState() => _EntitiesGraphPageState();
}

class _EntitiesGraphPageState extends ConsumerState<EntitiesGraphPage> {
  final Set<String> _hidden = {}; // kinds toggled off by the legend 图例隐藏的 kind
  bool _provenance = false;
  String? _revealId;
  int _revealToken = 0;

  // Selection from the URL: `?sel=<kind>:<id>`. 选区自 URL。
  (String kind, String id)? _sel(BuildContext context) {
    final raw = GoRouterState.of(context).uri.queryParameters['sel'];
    if (raw == null || raw.isEmpty) return null;
    final i = raw.indexOf(':');
    if (i <= 0 || i >= raw.length - 1) return null;
    return (raw.substring(0, i), raw.substring(i + 1));
  }

  void _select(String kind, String id, {bool reveal = false}) {
    if (reveal) {
      setState(() {
        _revealId = id;
        _revealToken++;
      });
    }
    context.go('/entities/graph?sel=$kind:$id');
  }

  void _exit() => context.go('/');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final graphAsync = ref.watch(relGraphProvider);
    final sel = _sel(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _exit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _canvas(context, graphAsync, sel)),
                  _leftChrome(context),
                  _rightChrome(context),
                  if (graphAsync.hasValue) _legend(context, graphAsync.value!),
                ],
              ),
            ),
            _GraphInspector(
              sel: sel,
              onOpenNode: (k, id) => _select(k, id, reveal: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas(
    BuildContext context,
    AsyncValue<EntityRelGraph> async,
    (String, String)? sel,
  ) {
    final d = context.t.entities;
    // Last-known-good over the keepAlive graph provider; the workspace id is the hard generation
    // boundary (this provider survives a hot switch WITH the old workspace's graph attached).
    // last-known-good;workspace id 为硬换代界(keepAlive provider 热切换时还攥着旧空间的图)。
    return AnLastGood(
      value: async,
      resetKey: ref.watch(activeWorkspaceProvider),
      placeholder: const Center(child: AnSkeleton.card()),
      errorBuilder: (_, _, _) => Center(
        child: AnState(
          kind: AnStateKind.error,
          size: AnStateSize.inset,
          title: d.errorTitle,
          hint: d.errorHint,
          action: AnButton(
            label: d.retry,
            onPressed: () => ref.invalidate(relGraphProvider),
          ),
        ),
      ),
      builder: (context, g) {
        // Default: structural (equip/link) only. Provenance toggle re-admits the full graph. 默认结构;溯源开=全图。
        final sub = _provenance
            ? (nodes: g.nodes, edges: g.edges)
            : structuralSubgraph(g);
        final groups = ref.watch(railModelProvider);
        return AnRelationGraph(
          nodes: sub.nodes,
          edges: sub.edges,
          toolbar: true,
          hiddenKinds: _hidden,
          selectedId: sel?.$2,
          // Default ripple focus (used when nothing is selected) = the most-recently-touched graph entity.
          // 默认涟漪焦点(无选中时)=最近碰过的图上实体。
          focusId: mostRecentGraphNodeId(sub.nodes, groups),
          revealId: _revealId,
          revealToken: _revealToken,
          nodeSemanticLabel: (n, deg) => relationNodeLabel(context, n, deg),
          edgeSemanticLabel: (e) => relationEdgeLabel(context, e),
          semanticSummary: context.t.a11y.relationSummary(
            nodes: '${sub.nodes.length}',
            edges: '${sub.edges.length}',
          ),
          onNodeTap: (id) {
            if (id == null) {
              context.go(
                '/entities/graph',
              ); // background tap → deselect 空白点→取消选中
              return;
            }
            final kind = sub.nodes
                .where((n) => n.id == id)
                .map((n) => n.kind)
                .firstOrNull;
            if (kind != null) _select(kind, id);
          },
          // Double tap → open the entity's detail page (rail kinds only; accessory kinds have no page here).
          // 双击→进实体详情页(仅 rail kind;配件 kind 此海洋无页)。
          onNodeDoubleTap: (id) {
            final ek = entityKindFromWire(
              sub.nodes.where((n) => n.id == id).map((n) => n.kind).firstOrNull,
            );
            if (ek != null) context.go(entityLocation(ek, id));
          },
        );
      },
    );
  }

  /// Left chrome on the OS traffic-lights' line: reserve the lights + back + the provenance toggle.
  /// 左簇落红绿灯线:预留灯位 + 返回 + 溯源开关。
  Widget _leftChrome(BuildContext context) {
    final g = context.t.entities.graph;
    return Positioned(
      top: 0,
      left: AnSpace.s8,
      height: AnSize.titlebar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnWindowControls(),
          const SizedBox(width: AnSpace.s4),
          AnFloatingBar(
            children: [
              AnButton(
                label: g.back,
                icon: AnIcons.chevronLeft,
                variant: AnButtonVariant.ghost,
                size: AnButtonSize.sm,
                onPressed: _exit,
              ),
              const AnDivider.vertical(),
              AnButton(
                label: g.showProvenance,
                icon: _provenance ? AnIcons.check : AnIcons.history,
                variant: _provenance
                    ? AnButtonVariant.primary
                    : AnButtonVariant.ghost,
                size: AnButtonSize.sm,
                onPressed: () => setState(() => _provenance = !_provenance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Right chrome: reopen the right island when collapsed. 右簇:收起时重开右岛。
  Widget _rightChrome(BuildContext context) {
    final collapsed = ref.watch(rightPanelCollapsedProvider);
    if (!collapsed) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      right: AnSpace.s8,
      height: AnSize.titlebar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnFloatingBar(
            children: [
              AnButton.iconOnly(
                AnIcons.panelRight,
                size: AnButtonSize.sm,
                semanticLabel: context.t.shell.togglePanel,
                onPressed: () =>
                    ref.read(rightPanelCollapsedProvider.notifier).set(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The kind legend — a floating row of colour chips at bottom-centre; a chip IS the show/hide toggle
  /// for its kind (图例兼职过滤器,不另设两件). Only kinds present in the current graph appear. 图例即显隐开关。
  Widget _legend(BuildContext context, EntityRelGraph g) {
    final nodes = _provenance ? g.nodes : structuralSubgraph(g).nodes;
    final kinds = <String>{for (final n in nodes) n.kind}.toList()..sort();
    if (kinds.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: AnSpace.s12,
      // Center + a bounded floating AnCard (the sanctioned floating surface); the chips Wrap so a wide
      // graph's legend never overflows a narrow window (it grows to a second line instead). 居中 + 有界浮层卡,
      // 芯片 Wrap,窄窗不溢出(换行)。
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s16),
          child: AnCard(
            pad: AnCardPad.tight,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final k in kinds)
                  _LegendChip(
                    kind: k,
                    hidden: _hidden.contains(k),
                    onTap: () => setState(
                      () => _hidden.contains(k)
                          ? _hidden.remove(k)
                          : _hidden.add(k),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One legend chip = a colour dot + kind word; tapping toggles that kind's visibility. Hidden reads
/// muted. 图例芯片:色点 + kind 词,点击切显隐;隐藏态哑。
class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.kind,
    required this.hidden,
    required this.onTap,
  });
  final String kind;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = entityKindColor(context, kind);
    final word = entityKindWord(context, kind);
    return AnInteractive(
      onTap: onTap,
      builder: (context, states) => Opacity(
        opacity: hidden ? 0.38 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnSpace.s6,
            vertical: AnSpace.s4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnStatusDot.raw(color),
              const SizedBox(width: AnGap.inline),
              Text(
                word,
                style: AnText.meta.copyWith(
                  color: hidden ? c.inkFaint : c.inkMuted,
                  decoration: hidden ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The collapsible right island — same skin + reveal as the shell inspector / the workflow editor's
/// (AnIsland + the shared rightPanelCollapsedProvider + the user-dragged rightWidth). Holds the selected
/// node's entity card. 可收右岛:同壳/编辑器右岛皮与揭示;装选中节点实体卡。
class _GraphInspector extends ConsumerWidget {
  const _GraphInspector({required this.sel, required this.onOpenNode});
  final (String kind, String id)? sel;
  final void Function(String kind, String id) onOpenNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(rightPanelCollapsedProvider);
    final reduced = AnMotionPref.reduced(context);
    final rightWidth = ref.watch(
      shellChromeProvider.select((s) => s.rightWidth),
    );
    final content = AnInspector(
      headless: true,
      child: GraphEntityCard(sel: sel, onOpenNode: onOpenNode),
    );
    final island = AnIsland(
      child: collapsed
          ? ExcludeFocus(
              child: ExcludeSemantics(child: IgnorePointer(child: content)),
            )
          : content,
    );
    return AnimatedContainer(
      duration: reduced ? Duration.zero : AnMotion.mid,
      curve: AnMotion.easeOut,
      width: collapsed ? 0 : rightWidth,
      child: ClipRect(
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
