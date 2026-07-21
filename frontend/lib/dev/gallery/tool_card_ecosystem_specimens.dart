import 'dart:convert';

import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F12 relations + F13 mcp-mgmt + capability/model (B7.2) — the ecosystem-tail cards over their real
// structured results. F12/F13 生态收尾真机。

BlockNode _n(String name, String args, Map<String, dynamic> result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': jsonEncode(result)},
      );

final toolCardEcosystemGalleryItem = GalleryItem(
  'ChatToolCard · B7 生态收尾',
  'F12 get_relations(依赖边列,可导航)· capability_check_workflow(ok/问题红/警示琥珀)· F13 install/'
      'reconnect_mcp(ServerStatus 连接章+工具数+末错)· list_mcp_marketplace(服务器目录)· get_model_config'
      '(默认模型+密钥+可用模型)。',
  [
    GallerySpecimen(
      'get_relations · 依赖边列(可导航)',
      (c) => ChatToolCard(
        node: _n('get_relations', '{"kind":"agent","id":"ag_1"}', {
          'count': 3,
          'edges': [
            {
              'fromKind': 'agent',
              'fromId': 'ag_1',
              'fromName': 'invoice_triager',
              'toKind': 'function',
              'toId': 'fn_1',
              'toName': 'fetch_with_retry',
            },
            {
              'fromKind': 'agent',
              'fromId': 'ag_1',
              'fromName': 'invoice_triager',
              'toKind': 'handler',
              'toId': 'hd_1',
              'toName': 'charge',
            },
            {
              'fromKind': 'workflow',
              'fromId': 'wf_1',
              'fromName': 'quarter_close',
              'toKind': 'agent',
              'toId': 'ag_1',
              'toName': 'invoice_triager',
            },
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'capability_check_workflow · 有问题(红自动展开)',
      (c) => ChatToolCard(
        node: _n('capability_check_workflow', '{"workflowId":"wf_1"}', {
          'id': 'wf_1',
          'ok': false,
          'structurallyValid': true,
          'resolved': false,
          'problems': [
            'node "charge" references handler hd_x which was deleted',
            'entry trigger has no downstream edge',
          ],
          'warnings': [
            'agent "triager" has no outputSchema — downstream nodes read free text',
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'capability_check_workflow · 可运行(带警示)',
      (c) => ChatToolCard(
        node: _n('capability_check_workflow', '{"workflowId":"wf_2"}', {
          'id': 'wf_2',
          'ok': true,
          'structurallyValid': true,
          'resolved': true,
          'problems': [],
          'warnings': ['no approval gate on a payment path'],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'reconnect_mcp · 已连接(工具章)',
      (c) => ChatToolCard(
        node: _n('reconnect_mcp', '{"name":"acme"}', {
          'id': 'mcp_1',
          'name': 'acme',
          'status': 'connected',
          'consecutiveFailures': 0,
          'totalCalls': 42,
          'totalFailures': 1,
          'tools': [
            {'name': 'search_docs'},
            {'name': 'fetch_page'},
            {'name': 'create_issue'},
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'install_mcp_server · 连接失败(红自动展开 + 末错)',
      (c) => ChatToolCard(
        node: _n('install_mcp_server', '{"name":"broken"}', {
          'id': 'mcp_2',
          'name': 'broken',
          'status': 'error',
          'consecutiveFailures': 3,
          'totalCalls': 0,
          'totalFailures': 3,
          'lastError':
              'spawn failed: MCP_SERVER_ENV_MISSING (API_TOKEN required)',
          'tools': [],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'list_mcp_marketplace · 服务器目录',
      (c) => ChatToolCard(
        node: _n('list_mcp_marketplace', '{"query":"web"}', {
          'count': 2,
          'servers': [
            {
              'name': 'fetch',
              'description': '抓取网页并转 markdown',
              'runtime': 'node',
              'env': [
                {'name': 'USER_AGENT', 'required': false},
              ],
            },
            {
              'name': 'brave-search',
              'description': 'Brave 搜索 API',
              'runtime': 'node',
              'env': [
                {'name': 'BRAVE_API_KEY', 'required': true},
              ],
            },
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_model_config · 默认模型 + 密钥 + 可用',
      (c) => ChatToolCard(
        node: _n('get_model_config', '{}', {
          'defaultModels': {
            'chat': 'claude-sonnet-5',
            'agent': 'claude-opus-4-8',
          },
          'apiKeys': [
            {'id': 'k1'},
            {'id': 'k2'},
          ],
          'availableModels': [
            {'id': 'claude-sonnet-5'},
            {'id': 'claude-opus-4-8'},
            {'id': 'claude-haiku-4-5'},
          ],
        }),
      ),
      span: true,
    ),
  ],
);
