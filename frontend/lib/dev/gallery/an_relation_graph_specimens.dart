import 'package:flutter/widgets.dart';

import '../../core/contract/entities/relation.dart';
import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/graph/relation_graph_config.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnRelationGraph (WRK-072 · v2「涟漪焦点星图」) — the entity-relationship force graph. What these specimens
// prove: nodes are REAL widgets (a FOG-coloured dot sized by in-degree + a name label, focusable + Tab-
// roving), edges are a hairline no-arrow underlay, one FOCUS node glows + grows and colour intensity ripples
// OUT from it by graph distance (near vivid, far a quiet veil — hue fixed, only opacity), and the layout is
// deterministic (same graph, same shape every open). The framed flavour is the Overview preview box; the
// un-framed + toolbar flavour is the explore page. Hover a node to move the ripple there (a preview); hover
// an edge for the relation tooltip.
//
// AnRelationGraph v2 涟漪焦点星图。样本验:节点=真 widget(fog 色点·半径随入度 + 名字标签,可聚焦+Tab roving),
// 边=hairline 无箭头底层,一个焦点发柔光+变大、色彩强度从它按图距离向外涟漪(近浓远淡、色相不变只降不透明度),
// 布局确定(同图恒同形)。framed=总览预览,非 framed+toolbar=探索页。hover 节点=涟漪临时移过去预览;hover 边=tooltip。

EntityNode _n(String kind, String id, String name) =>
    EntityNode(kind: kind, id: id, name: name);
EntityRelation _e(
  String id,
  String fk,
  String from,
  String tk,
  String to, {
  String verb = 'equip',
}) => EntityRelation(
  id: id,
  kind: verb,
  fromKind: fk,
  fromId: from,
  toKind: tk,
  toId: to,
);

// A satisfying "full graph": a star hub (fn_core referenced by many; wf_pipeline orchestrating), a skill +
// document + mcp edge, a low-degree leaf, AND a disconnected second component (wf_batch → hd_ftp) to show
// component packing. 满态好图:星型枢纽 + skill/document/mcp 边 + 低度叶子 + 一个独立第二分量(验分量打包)。
final _nodes = [
  _n('function', 'fn_core', 'core-utils'),
  _n('function', 'fn_fmt', 'formatter'),
  _n('handler', 'hd_db', 'db-handler'),
  _n('agent', 'ag_writer', 'writer-agent'),
  _n('agent', 'ag_triage', 'triage-agent'),
  _n('workflow', 'wf_pipe', 'nightly-pipeline'),
  _n('workflow', 'wf_report', 'weekly-report'),
  _n('trigger', 'trg_cron', 'cron 09:00'),
  _n('control', 'ctl_branch', 'route-by-status'),
  _n('approval', 'apf_gate', 'human-gate'),
  _n('skill', 'sk_style', 'house-style'),
  _n('document', 'doc_spec', 'design-spec'),
  _n('mcp', 'mcp_gh', 'github-mcp'),
  _n('workflow', 'wf_batch', 'batch-import'), // second component
  _n('handler', 'hd_ftp', 'ftp-handler'),
];

final _edges = [
  _e('e1', 'workflow', 'wf_pipe', 'function', 'fn_core'),
  _e('e2', 'workflow', 'wf_pipe', 'handler', 'hd_db'),
  _e('e3', 'workflow', 'wf_pipe', 'agent', 'ag_triage'),
  _e('e4', 'agent', 'ag_triage', 'function', 'fn_core'),
  _e('e5', 'agent', 'ag_writer', 'function', 'fn_core'),
  _e('e6', 'agent', 'ag_writer', 'function', 'fn_fmt'),
  _e('e7', 'agent', 'ag_writer', 'skill', 'sk_style'),
  _e('e8', 'agent', 'ag_writer', 'mcp', 'mcp_gh'),
  _e('e9', 'workflow', 'wf_report', 'agent', 'ag_writer'),
  _e('e10', 'workflow', 'wf_pipe', 'trigger', 'trg_cron'),
  _e('e11', 'workflow', 'wf_pipe', 'control', 'ctl_branch'),
  _e('e12', 'workflow', 'wf_report', 'approval', 'apf_gate'),
  _e('e13', 'document', 'doc_spec', 'function', 'fn_core', verb: 'link'),
  _e(
    'e14',
    'workflow',
    'wf_batch',
    'handler',
    'hd_ftp',
  ), // the second, disconnected component
];

String _nodeLabel(EntityNode n, int deg) => '${n.name}（${n.kind}），被 $deg 个实体引用';
String _edgeLabel(EntityRelation e) =>
    '${e.fromName.isEmpty ? e.fromId : e.fromName} → '
    '${e.toName.isEmpty ? e.toId : e.toName}（${e.kind}）';

// All 11 kinds' fog swatches — the palette-at-a-glance (kind manages hue, low-saturation, one lightness).
// 11 种 kind 的雾彩一览:kind 管色相、低饱和、同明度。
const _paletteKinds = [
  'workflow',
  'agent',
  'function',
  'handler',
  'trigger',
  'control',
  'approval',
  'mcp',
  'skill',
  'memory',
  'document',
];

Widget _fogPalette(BuildContext context) {
  final c = context.colors;
  return Wrap(
    spacing: AnSpace.s16,
    runSpacing: AnSpace.s12,
    children: [
      for (final k in _paletteKinds)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: RelationGraphConfig.fogColor(k),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AnGap.inline),
            Text(k, style: AnText.meta.copyWith(color: c.inkMuted)),
          ],
        ),
    ],
  );
}

final anRelationGraphGalleryItem = GalleryItem(
  'AnRelationGraph 关系图',
  'v2 涟漪焦点星图:fog 色点(半径随入度)+ 无箭头细边 + 焦点柔光·色彩涟漪衰减 + 平移缩放拖拽 + hover 换焦 + Tab roving',
  [
    GallerySpecimen(
      '雾彩色板一览(kind 管色相 · 低饱和同明度 · 独立于提示色)',
      _fogPalette,
      span: true,
    ),
    GallerySpecimen(
      '观赏态 framed(默认焦点=fn_core,柔光+涟漪衰减)',
      (_) => AnRelationGraph(
        nodes: _nodes,
        edges: _edges,
        framed: true,
        focusId: 'fn_core',
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
        onExpand: () {},
        expandLabel: '展开',
      ),
      span: true,
    ),
    GallerySpecimen(
      '换焦(焦点=ag_writer,涟漪整体移位)',
      (_) => AnRelationGraph(
        nodes: _nodes,
        edges: _edges,
        framed: true,
        focusId: 'ag_writer',
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
      ),
      span: true,
    ),
    GallerySpecimen(
      '选中枢纽(accent 环 + 焦点)',
      (_) => AnRelationGraph(
        nodes: _nodes,
        edges: _edges,
        framed: true,
        selectedId: 'fn_core',
        focusId: 'fn_core',
        onNodeTap: (_) {},
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
      ),
      span: true,
    ),
    GallerySpecimen(
      '探索态(非 framed 满幅 + 缩放条)',
      (_) => AnRelationGraph(
        nodes: _nodes,
        edges: _edges,
        toolbar: true,
        selectedId: 'ag_writer',
        focusId: 'ag_writer',
        onNodeTap: (_) {},
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
        semanticSummary: '15 个实体，14 条关系',
      ),
      span: true,
      height: 460,
    ),
    GallerySpecimen(
      '图例隐藏 skill/mcp/document(仅渲染过滤,布局不变)',
      (_) => AnRelationGraph(
        nodes: _nodes,
        edges: _edges,
        framed: true,
        focusId: 'fn_core',
        hiddenKinds: const {'skill', 'mcp', 'document'},
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
      ),
      span: true,
    ),
    GallerySpecimen(
      '空图(空点阵,零文案)',
      (_) => const AnRelationGraph(nodes: [], edges: []),
      stress: true,
      span: true,
    ),
    GallerySpecimen(
      '孤立实体(不进力场·底部安静带) + 单边叶子',
      (_) => AnRelationGraph(
        nodes: [
          _n(
            'function',
            'fn_a',
            'lonely-fn',
          ), // zero-degree isolate → quiet band
          _n('handler', 'hd_a', 'lib-a'),
          _n('agent', 'ag_a', 'uses-a'),
        ],
        edges: [_e('x1', 'agent', 'ag_a', 'handler', 'hd_a')],
        framed: true,
        nodeSemanticLabel: _nodeLabel,
        edgeSemanticLabel: _edgeLabel,
      ),
      stress: true,
      span: true,
    ),
  ],
);
