import 'dart:convert';

import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F09 run-log search (B5.6) — the aggregate families over their {list, hasMore, aggregates} shells. The
// body is a page-health bead strip + a slim RunLedger; the receipt is the ok✓/failed✗ rollup. Slim
// projection: even though every list row ships full input/output/logs (agent: transcript), the card
// renders id/status/timing/method ONLY. F09 检索卡真机:珠串 + slim 台账。

BlockNode _search(String name, String args, String result) => BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

String _exec(String id, String status, {String by = 'chat', int elapsed = 800, String? extra}) =>
    '{"id":"$id","status":"$status","triggeredBy":"$by","elapsedMs":$elapsed,"startedAt":"2026-07-05T14:03:00Z"${extra ?? ''}}';

String _page(String listKey, List<String> rows, {int ok = 0, int failed = 0, bool hasMore = false}) => jsonEncode({
      listKey: rows.map(jsonDecode).toList(),
      'hasMore': hasMore,
      'aggregates': {'okCount': ok, 'failedCount': failed},
    });

final toolCardRunlogGalleryItem = GalleryItem(
  'ChatToolCard · F09 检索族(聚合)',
  'F09 检索族(函数执行/处理器调用/智能体执行/MCP 调用):共享 {list, hasMore, aggregates} 壳。收起回执='
      'ok✓·failed✗ 滚账(恒灰——档案里的失败非本次调用失败);体=页健康珠串 + slim RunLedger(id/状态/时长/'
      '方法名,input/output/logs/transcript 一字不渲)。✗ 含取消/超时。',
  [
    GallerySpecimen('search_function_executions · 混合(ok/failed/timeout 珠 + hasMore)',
        (c) => ChatToolCard(node: _search('search_function_executions', '{"functionId":"fn_1a2b3c4d5e6f7a8b"}',
            _page('executions', [
              _exec('fnexec_01', 'ok', elapsed: 942),
              _exec('fnexec_02', 'failed', by: 'agent', elapsed: 30021),
              _exec('fnexec_03', 'ok', elapsed: 610),
              _exec('fnexec_04', 'timeout', by: 'workflow', elapsed: 60000),
              _exec('fnexec_05', 'ok', by: 'manual', elapsed: 1200),
            ], ok: 41, failed: 4, hasMore: true))),
        span: true),
    GallerySpecimen('search_handler_calls · method() chip + instanceId 次行',
        (c) => ChatToolCard(node: _search('search_handler_calls', '{"handlerId":"hd_5c4b3a2f1e0d9c8b"}',
            _page('calls', [
              _exec('hdcall_01', 'ok', by: 'agent', extra: ',"method":"charge","instanceId":"inst_88a1"'),
              _exec('hdcall_02', 'failed', by: 'chat', extra: ',"method":"refund","instanceId":"inst_88a1"'),
            ], ok: 12, failed: 1))),
        span: true),
    GallerySpecimen('search_agent_executions · timeout 琥珀珠(transcript 已丢弃)',
        (c) => ChatToolCard(node: _search('search_agent_executions', '{"agentId":"ag_9f8e7d6c5b4a3f2e"}',
            _page('executions', [
              // Each row ships a fat transcript — the card must render NONE of it. 每行背 transcript,卡一字不渲。
              _exec('agexec_01', 'ok', elapsed: 8400, extra: ',"transcript":"[...30KB of blocks...]"'),
              _exec('agexec_02', 'timeout', by: 'workflow', elapsed: 120000, extra: ',"transcript":"[...30KB...]"'),
            ], ok: 7, failed: 2))),
        span: true),
    GallerySpecimen('search_mcp_calls · tool chip',
        (c) => ChatToolCard(node: _search('search_mcp_calls', '{"serverId":"mcp_acme"}',
            _page('calls', [
              _exec('mcl_01', 'ok', by: 'agent', extra: ',"tool":"search_docs"'),
              _exec('mcl_02', 'ok', by: 'agent', extra: ',"tool":"fetch_page"'),
            ], ok: 20, failed: 0))),
        span: true),
    GallerySpecimen('search_function_executions · 无记录(回执即卡、无体)',
        (c) => ChatToolCard(node: _search('search_function_executions', '{"functionId":"fn_never_run"}',
            _page('executions', [], ok: 0, failed: 0))),
        span: true),
    GallerySpecimen('search_flowruns · 珠串本页 + replay 微章 + 失败 subtext',
        (c) => ChatToolCard(node: _search('search_flowruns', '{"workflowId":"wf_1a2b3c4d5e6f7a8b"}',
            jsonEncode({
              'runs': [
                {'id': 'fr_01', 'workflowId': 'wf_1', 'status': 'completed', 'replayCount': 0, 'startedAt': '2026-07-05T14:03:00Z', 'updatedAt': '2026-07-05T14:03:00Z'},
                {'id': 'fr_02', 'workflowId': 'wf_1', 'status': 'failed', 'replayCount': 2, 'error': 'node charge failed', 'startedAt': '2026-07-05T14:02:00Z', 'updatedAt': '2026-07-05T14:02:00Z'},
                {'id': 'fr_03', 'workflowId': 'wf_1', 'status': 'running', 'replayCount': 0, 'startedAt': '2026-07-05T14:01:00Z', 'updatedAt': '2026-07-05T14:01:00Z'},
              ],
              'hasMore': false,
            }))),
        span: true),
    GallerySpecimen('search_firings · 处置词章五色 + started 缀 flowrunId',
        (c) => ChatToolCard(node: _search('search_firings', '{"triggerId":"trg_7a8b9c0d1e2f3a4b"}',
            jsonEncode({
              'count': 3,
              'firings': [
                {'id': 'frg_01', 'triggerId': 'trg_1', 'workflowId': 'wf_1', 'activationId': 'act_1', 'status': 'started', 'flowrunId': 'fr_9a8b7c6d5e4f3a2b', 'dedupKey': 'cron:2026-07-05T14', 'createdAt': '2026-07-05T14:03:00Z'},
                {'id': 'frg_02', 'triggerId': 'trg_1', 'workflowId': 'wf_1', 'activationId': 'act_2', 'status': 'skipped', 'dedupKey': 'cron:2026-07-05T13', 'createdAt': '2026-07-05T13:03:00Z'},
                {'id': 'frg_03', 'triggerId': 'trg_1', 'workflowId': 'wf_1', 'activationId': 'act_3', 'status': 'pending', 'dedupKey': 'cron:2026-07-05T15', 'createdAt': '2026-07-05T15:03:00Z'},
              ],
            }))),
        span: true),
    GallerySpecimen('search_activations · fire 标记 + returnValue 惰性行内树',
        (c) => ChatToolCard(node: _search('search_activations', '{"triggerId":"trg_7a8b9c0d1e2f3a4b"}',
            jsonEncode({
              'count': 2,
              'activations': [
                {'id': 'act_01', 'triggerId': 'trg_1', 'kind': 'sensor', 'fired': true, 'firingCount': 2, 'returnValue': {'temp': 31.4, 'threshold': 30}, 'createdAt': '2026-07-05T14:03:00Z'},
                {'id': 'act_02', 'triggerId': 'trg_1', 'kind': 'sensor', 'fired': false, 'firingCount': 0, 'detail': 'condition evaluated false', 'returnValue': {'temp': 22.0, 'threshold': 30}, 'createdAt': '2026-07-05T13:03:00Z'},
              ],
            }))),
        span: true),
  ],
);
