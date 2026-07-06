import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F08 flowrun (B5.3) — replay_flowrun over its real {flowrun, nodes, nodeSummary?} composite. The body
// is FlowrunNodeList (see the run's per-node record) + a run footer (status · replay# · workflow pill ·
// flowrunId). Four settle shapes: completed / still-failed (auto-expand) / awaiting-approval (parked
// node, run header still running) / 80-node capped (honest count bar). F08 flowrun 节点台账真机四态。

BlockNode _replay(String result) => BlockNode(id: 'tc_replay', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'replay_flowrun', 'arguments': '{"flowrunId":"fr_9a8b7c6d5e4f3a2b"}'}
  ..children.add(BlockNode(id: 'tr_replay', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

String _node(String nodeId, String kind, String status, {int iteration = 0, String? error}) =>
    '{"id":"frn_${nodeId}_$iteration","flowrunId":"fr_9a8b7c6d5e4f3a2b","nodeId":"$nodeId","iteration":$iteration,'
    '"kind":"$kind","ref":"$kind:x","status":"$status",${error != null ? '"error":"$error",' : ''}'
    '"result":{},"createdAt":"2026-07-05T14:00:00Z","updatedAt":"2026-07-05T14:00:00Z"}';

String _run(String status, List<String> nodes, {int replayCount = 1, String? runError, String? nodeSummary}) =>
    '{"flowrun":{"id":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1a2b3c4d5e6f7a8b","versionId":"wfv_1","status":"$status",'
    '"replayCount":$replayCount,${runError != null ? '"error":"$runError",' : ''}"pinnedRefs":{},'
    '"updatedAt":"2026-07-05T14:05:00Z"},"nodes":[${nodes.join(',')}]${nodeSummary != null ? ',"nodeSummary":$nodeSummary' : ''}}';

final toolCardFlowrunGalleryItem = GalleryItem(
  'ChatToolCard · F08 replay 节点台账',
  'F08 replay_flowrun:同步重放,收 {flowrun, nodes, nodeSummary?} 复合结果。落定体=诚实重放注(原 pin 版本)'
      '+ FlowrunNodeList(每节点一行:kind 字形·nodeId·循环轮·状态点,失败行红摘要,失败/park 置顶)+ run 页脚'
      '(状态词·第 N 次重放·可导航 workflow 药丸·flowrunId 复制)。回执四态,run 头无 parked(park 是节点态)。',
  [
    GallerySpecimen('replay · 完成(多节点全绿)',
        (c) => ChatToolCard(node: _replay(_run('completed', [
              _node('trigger', 'trigger', 'completed'),
              _node('fetch', 'action', 'completed'),
              _node('classify', 'agent', 'completed'),
              _node('route', 'control', 'completed'),
            ], replayCount: 1))),
        span: true),
    GallerySpecimen('replay · 仍失败(auto-expand,失败节点红摘要置顶)',
        (c) => ChatToolCard(node: _replay(_run('failed', [
              _node('trigger', 'trigger', 'completed'),
              _node('fetch', 'action', 'completed'),
              _node('charge', 'action', 'failed', error: 'HANDLER_RPC_TIMEOUT: charge() exceeded 30s'),
            ], replayCount: 2, runError: 'run halted at node charge'))),
        span: true),
    GallerySpecimen('replay · 等待审批(节点 parked,run 头仍 running)',
        (c) => ChatToolCard(node: _replay(_run('running', [
              _node('trigger', 'trigger', 'completed'),
              _node('fetch', 'action', 'completed'),
              _node('approve', 'approval', 'parked'),
            ], replayCount: 1))),
        span: true),
    GallerySpecimen('replay · 80 封顶(nodeSummary 诚实账 + 循环轮次)',
        (c) => ChatToolCard(node: _replay(_run('completed', [
              _node('loop', 'action', 'failed', iteration: 41, error: 'transient: retry budget hit'),
              _node('loop', 'action', 'completed', iteration: 42),
              _node('finalize', 'control', 'completed'),
            ],
                replayCount: 3,
                nodeSummary:
                    '{"totalNodes":213,"shownNodes":80,"byStatus":{"completed":209,"failed":3,"parked":1},"note":"capped"}'))),
        span: true),
  ],
);
