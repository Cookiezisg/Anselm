import '../../core/contract/entities/relation.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnRelationGraph (WRK-072) — the entity-relationship force graph. What these specimens prove: nodes are
// REAL widgets (a colour dot sized by in-degree + a name label, focusable + Tab-roving), edges are a
// hairline no-arrow underlay, and the layout is deterministic (the same graph settles to the same shape
// every open — reload the gallery and the hub sits in the same place). The framed flavour is the Overview
// preview box; the un-framed + toolbar flavour is the explore page. Hover a node to see the one-hop
// highlight + the rest fade; hover an edge for the relation tooltip.
//
// AnRelationGraph 关系图力导向。样本验:节点=真 widget(色点·半径随入度 + 名字标签,可聚焦 + Tab roving),
// 边=hairline 无箭头底层,布局确定(同图恒同形——重开画廊枢纽在同一处)。framed=总览预览框,非 framed+toolbar=
// 探索页。hover 节点看一跳高亮 + 其余淡;hover 边看关系 tooltip。

EntityNode _n(String kind, String id, String name) => EntityNode(kind: kind, id: id, name: name);
EntityRelation _e(String id, String fk, String from, String tk, String to, {String verb = 'equip'}) =>
    EntityRelation(id: id, kind: verb, fromKind: fk, fromId: from, toKind: tk, toId: to);

// A satisfying "full graph": two star hubs (fn_core referenced by many; wf_pipeline orchestrating), a
// skill + document + mcp edge, and one low-degree leaf. 满态好图:两个星型枢纽 + skill/document/mcp 边 + 低度叶子。
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
];

String _nodeLabel(EntityNode n, int deg) => '${n.name}（${n.kind}），被 $deg 个实体引用';
String _edgeLabel(EntityRelation e) => '${e.fromName.isEmpty ? e.fromId : e.fromName} → '
    '${e.toName.isEmpty ? e.toId : e.toName}（${e.kind}）';

final anRelationGraphGalleryItem = GalleryItem(
  'AnRelationGraph 关系图',
  '力导向节点连线:色点(半径随入度)+ 无箭头细边 + 平移缩放拖拽 + hover 一跳高亮 + Tab roving;framed=总览预览 / toolbar=探索页',
  [
    GallerySpecimen('观赏态 framed(总览预览框)', (_) => AnRelationGraph(
          nodes: _nodes, edges: _edges, framed: true,
          nodeSemanticLabel: _nodeLabel, edgeSemanticLabel: _edgeLabel,
          onExpand: () {}, expandLabel: '展开',
        ), span: true),
    GallerySpecimen('选中枢纽(accent 环)', (_) => AnRelationGraph(
          nodes: _nodes, edges: _edges, framed: true, selectedId: 'fn_core',
          onNodeTap: (_) {}, nodeSemanticLabel: _nodeLabel, edgeSemanticLabel: _edgeLabel,
        ), span: true),
    GallerySpecimen('探索态(非 framed 满幅 + 缩放条)', (_) => AnRelationGraph(
          nodes: _nodes, edges: _edges, toolbar: true, selectedId: 'ag_writer',
          onNodeTap: (_) {}, nodeSemanticLabel: _nodeLabel, edgeSemanticLabel: _edgeLabel,
          semanticSummary: '13 个实体，13 条关系',
        ), span: true, height: 460),
    GallerySpecimen('图例隐藏 skill/mcp/document(仅渲染过滤,布局不变)', (_) => AnRelationGraph(
          nodes: _nodes, edges: _edges, framed: true,
          hiddenKinds: const {'skill', 'mcp', 'document'},
          nodeSemanticLabel: _nodeLabel, edgeSemanticLabel: _edgeLabel,
        ), span: true),
    GallerySpecimen('空图(空点阵,零文案)', (_) => const AnRelationGraph(nodes: [], edges: []),
        stress: true, span: true),
    GallerySpecimen('孤立实体 + 单边叶子', (_) => AnRelationGraph(
          nodes: [
            _n('function', 'fn_a', 'lonely-fn'),
            _n('handler', 'hd_a', 'lib-a'),
            _n('agent', 'ag_a', 'uses-a'),
          ],
          edges: [_e('x1', 'agent', 'ag_a', 'handler', 'hd_a')],
          framed: true, nodeSemanticLabel: _nodeLabel, edgeSemanticLabel: _edgeLabel,
        ), stress: true, span: true),
  ],
);
