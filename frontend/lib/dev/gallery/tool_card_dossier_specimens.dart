import 'dart:convert';

import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F09 get-record (B5.8) — the thin dossiers over one execution/call/activation record. fn/hd/mcp share
// the RunDossier (status head → input/output → double-ended log drawer → provenance line); a failed
// record auto-expands; an MCP stderr tail splits into its own danger segment; get_activation is a
// bespoke fire record. F09 卷宗卡真机。

BlockNode _get(String name, String args, Map<String, dynamic> record) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': jsonEncode(record)},
      );

final toolCardDossierGalleryItem = GalleryItem(
  'ChatToolCard · F09 卷宗卡(get)',
  'F09 get 族(函数执行/处理器调用/MCP 调用/活动):收起回执=status·elapsed(失败/超时红自动展开——来 triage)。'
      '体=RunDossier(状态头条 + 输入/输出机器窗 + 日志抽屉[双端保留、MCP stderr 尾独立染红段] + 出处行'
      '[对话/触发器可点、消息/节点 mono]);活动=薄 fire 卷宗(fire 结论 + returnValue + payload + 无因果链)。',
  [
    GallerySpecimen(
      'get_function_execution · 成功(输入/输出 + 日志抽屉 + 出处行)',
      (c) => ChatToolCard(
        node: _get(
          'get_function_execution',
          '{"executionId":"fnexec_1a2b3c4d"}',
          {
            'id': 'fnexec_1a2b3c4d',
            'functionId': 'fn_1',
            'versionId': 'fnv_3',
            'status': 'ok',
            'triggeredBy': 'chat',
            'input': {'url': 'https://x.io/api', 'retries': 3},
            'output': {'status': 200, 'bytes': 18422},
            'logs': 'fetch page 1/3\nfetch page 2/3\nfetch page 3/3\ndone',
            'elapsedMs': 942,
            'startedAt': '2026-07-05T14:03:00Z',
            'endedAt': '2026-07-05T14:03:01Z',
            'conversationId': 'conv_abc123',
            'messageId': 'msg_def456',
            'createdAt': '2026-07-05T14:03:01Z',
          },
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_function_execution · 失败(auto-expand + errorMessage + flowrun 出处)',
      (c) => ChatToolCard(
        node: _get('get_function_execution', '{"executionId":"fnexec_bad"}', {
          'id': 'fnexec_bad',
          'functionId': 'fn_1',
          'status': 'failed',
          'triggeredBy': 'workflow',
          'input': {'url': 'https://down'},
          'errorMessage': 'ConnectionError: max retries exceeded (3)',
          'elapsedMs': 30021,
          'startedAt': '2026-07-05T14:03:00Z',
          'endedAt': '2026-07-05T14:03:30Z',
          'flowrunId': 'fr_9a8b7c6d5e4f3a2b',
          'flowrunNodeId': 'fetch',
          'flowrunIteration': 0,
          'createdAt': '2026-07-05T14:03:30Z',
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_handler_call · method() 头徽 + instanceId',
      (c) => ChatToolCard(
        node: _get('get_handler_call', '{"callId":"hdcall_1"}', {
          'id': 'hdcall_1',
          'handlerId': 'hd_1',
          'status': 'ok',
          'method': 'charge',
          'instanceId': 'inst_88a1',
          'triggeredBy': 'agent',
          'input': {'account': 'acct_88'},
          'output': {'result': 18240.5},
          'elapsedMs': 610,
          'startedAt': '2026-07-05T14:03:00Z',
          'endedAt': '2026-07-05T14:03:00Z',
          'createdAt': '2026-07-05T14:03:00Z',
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_mcp_call · 失败 + stderr 尾独立染红段',
      (c) => ChatToolCard(
        node: _get('get_mcp_call', '{"callId":"mcl_1"}', {
          'id': 'mcl_1',
          'serverId': 'mcp_acme',
          'tool': 'fetch_page',
          'status': 'failed',
          'triggeredBy': 'agent',
          'input': {'url': 'https://x'},
          'errorMessage': 'tool call failed',
          'logs':
              'connecting to acme…\ninvoking fetch_page\n'
              '--- server stderr tail (server-level, may predate this call) ---\n'
              'Traceback (most recent call last):\n  File "server.py", line 42\n    raise TimeoutError()\nTimeoutError',
          'elapsedMs': 5000,
          'startedAt': '2026-07-05T14:03:00Z',
          'endedAt': '2026-07-05T14:03:05Z',
          'createdAt': '2026-07-05T14:03:05Z',
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_activation · fired(returnValue + payload + 扇出 + 触发器出处)',
      (c) => ChatToolCard(
        node: _get('get_activation', '{"activationId":"act_1"}', {
          'id': 'act_1',
          'triggerId': 'trg_7a8b9c0d1e2f3a4b',
          'kind': 'sensor',
          'fired': true,
          'firingCount': 2,
          'returnValue': {'temp': 31.4, 'threshold': 30},
          'payload': {'manual': false, 'temp': 31.4},
          'createdAt': '2026-07-05T14:03:00Z',
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_activation · not fired(condition false,无因果链)',
      (c) => ChatToolCard(
        node: _get('get_activation', '{"activationId":"act_2"}', {
          'id': 'act_2',
          'triggerId': 'trg_7a8b9c0d1e2f3a4b',
          'kind': 'sensor',
          'fired': false,
          'firingCount': 0,
          'detail': 'condition evaluated false',
          'returnValue': {'temp': 22.0, 'threshold': 30},
          'createdAt': '2026-07-05T13:03:00Z',
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_agent_execution · 成功(modelId/provider 微标 + TranscriptPeek 轨迹)',
      (c) => ChatToolCard(
        node: _get('get_agent_execution', '{"executionId":"agexec_1a2b3c4d"}', {
          'id': 'agexec_1a2b3c4d',
          'agentId': 'ag_1',
          'modelId': 'claude-sonnet-5',
          'provider': 'anselm',
          'status': 'ok',
          'triggeredBy': 'chat',
          'input': {'quarter': '2026Q2'},
          'output': '共 312 张发票已归类,无异常。',
          'elapsedMs': 8400,
          'startedAt': '2026-07-05T14:03:00Z',
          'endedAt': '2026-07-05T14:03:08Z',
          'conversationId': 'conv_abc123',
          'transcript': [
            {
              'type': 'reasoning',
              'content': '先取本季度全部发票,再按类目归并。',
              'status': 'completed',
            },
            {
              'id': 'tc_1',
              'type': 'tool_call',
              'content': '{"functionId":"fn_1","args":{}}',
              'attrs': {'tool': 'run_function', 'summary': '取发票'},
              'status': 'completed',
            },
            {
              'id': 'tr_1',
              'parentBlockId': 'tc_1',
              'type': 'tool_result',
              'content': '{"ok":true,"output":312}',
              'status': 'completed',
            },
            {'type': 'text', 'content': '归并完成,输出汇总。', 'status': 'completed'},
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_agent_execution · 失败(auto-expand + 轨迹取首尾)',
      (c) => ChatToolCard(
        node: _get('get_agent_execution', '{"executionId":"agexec_bad"}', {
          'id': 'agexec_bad',
          'agentId': 'ag_1',
          'modelId': 'claude-sonnet-5',
          'provider': 'anselm',
          'status': 'failed',
          'triggeredBy': 'workflow',
          'input': {'quarter': 'bad'},
          'errorMessage':
              'AGENT_OUTPUT_NOT_STRUCTURED: model returned prose but outputSchema requires {total:int}',
          'elapsedMs': 2400,
          'startedAt': '2026-07-05T14:03:00Z',
          'endedAt': '2026-07-05T14:03:02Z',
          'transcript': [
            {
              'type': 'reasoning',
              'content': '解析 quarter 参数。',
              'status': 'completed',
            },
            {'type': 'text', 'content': '季度值无效,无法继续。', 'status': 'error'},
          ],
        }),
      ),
      span: true,
    ),
  ],
);
