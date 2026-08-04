import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_ecosystem.dart';
import 'package:anselm/features/chat/ui/tool_hit_list.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F12 relations + F13 mcp-mgmt + capability/model (B7.2) — receipts + bodies.

BlockNode _n(String name, String args, Map<String, dynamic> result) =>
    BlockNode(id: 'tc_e', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_e', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': jsonEncode(result)},
      );

BlockNode _raw(
  String name,
  String args,
  String result,
) => BlockNode(id: 'tc_raw', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(
    BlockNode(id: 'tr_raw', kind: BlockKind.toolResult)
      // The loop closes a failed Execute with status=error; keep this fixture on the real wire shape.
      // loop 对 Execute 错误以 status=error 关帧；夹具必须保持真实线缆形状。
      ..status = 'error'
      ..content = {'content': result},
  );

Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 660, child: c)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('receipts', () {
    test('relations: N edges / none', () {
      expect(
        relationsReceipt(
          t,
          jsonEncode({
            'count': 3,
            'edges': [1, 2, 3],
          }),
        )!.text,
        contains('3'),
      );
      expect(
        relationsReceipt(t, jsonEncode({'count': 0, 'edges': []}))!.text,
        t.chat.tool.relNoEdges,
      );
    });
    test('capability: ok→grey/warn, problems→danger', () {
      expect(
        capabilityReceipt(t, jsonEncode({'ok': true, 'warnings': []}))!.tone,
        isNot(ToolReceiptTone.danger),
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': true,
            'warnings': ['w'],
          }),
        )!.tone,
        ToolReceiptTone.warn,
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': false,
            'problems': ['p1', 'p2'],
          }),
        )!.tone,
        ToolReceiptTone.danger,
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': true,
            'warnings': ['w'],
          }),
        )!.text,
        t.chat.tool.capWarning(n: '1'),
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': true,
            'warnings': ['w', 'w2'],
          }),
        )!.text,
        t.chat.tool.capWarnings(n: '2'),
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': false,
            'problems': ['p'],
          }),
        )!.text,
        t.chat.tool.capProblem(n: '1'),
      );
      expect(
        capabilityReceipt(
          t,
          jsonEncode({
            'ok': false,
            'problems': ['p1', 'p2'],
          }),
        )!.text,
        t.chat.tool.capProblems(n: '2'),
      );
      expect(capabilityFailed(jsonEncode({'ok': false})), isTrue);
    });
    test(
      'mcp status: ready is healthy, degraded warns, terminal states fail',
      () {
        expect(
          mcpStatusReceipt(
            t,
            jsonEncode({
              'status': 'ready',
              'tools': [1, 2],
            }),
          )!.tone,
          isNot(ToolReceiptTone.danger),
        );
        expect(mcpStatusFailed(jsonEncode({'status': 'ready'})), isFalse);
        expect(
          mcpStatusReceipt(
            t,
            jsonEncode({'status': 'degraded', 'tools': []}),
          )!.tone,
          ToolReceiptTone.warn,
        );
        expect(mcpStatusFailed(jsonEncode({'status': 'degraded'})), isFalse);
        expect(
          mcpStatusReceipt(
            t,
            jsonEncode({'status': 'error', 'tools': []}),
          )!.tone,
          ToolReceiptTone.danger,
        );
        expect(mcpStatusFailed(jsonEncode({'status': 'error'})), isTrue);
      },
    );

    test('mcp lifecycle plain execution errors stay visibly failed', () {
      const missing =
          'required environment variables missing (missing=[ENTRA_CLIENT_ID])';
      expect(mcpStatusFailed(missing), isTrue);
      expect(mcpStatusReceipt(t, missing)!.tone, ToolReceiptTone.danger);
      expect(mcpStatusReceipt(t, missing)!.text, t.chat.tool.mcpError);
      expect(mcpStatusFailed('Uninstalled MCP server "github".'), isFalse);
    });
    test('marketplace: N servers; model: N available', () {
      expect(
        marketplaceReceipt(t, jsonEncode({'count': 5, 'servers': []}))!.text,
        contains('5'),
      );
      expect(
        modelConfigReceipt(
          t,
          jsonEncode({
            'availableModels': [1, 2, 3],
          }),
        )!.text,
        contains('3'),
      );
    });
  });

  testWidgets('get_relations: navigable from→to edge rows', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _n('get_relations', '{"kind":"agent","id":"ag_1"}', {
            'count': 1,
            'edges': [
              {
                'kind': 'equip',
                'fromKind': 'agent',
                'fromId': 'ag_1',
                'fromName': 'triager',
                'toKind': 'function',
                'toId': 'fn_1',
                'toName': 'fetcher',
              },
            ],
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.textContaining(t.chat.tool.gotRelations),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('triager'), findsOneWidget);
    expect(find.textContaining('fetcher'), findsOneWidget);
    expect(find.text(t.entities.graph.verb.equip), findsOneWidget);
    expect(find.text(t.chat.tool.relArrow), findsOneWidget);
  });

  testWidgets('capability_check failed auto-expands with red problems', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _n('capability_check_workflow', '{"workflowId":"wf_1"}', {
            'id': 'wf_1',
            'ok': false,
            'structurallyValid': true,
            'problems': ['DANGLING_REF_TO_HD_X'],
            'warnings': [],
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('DANGLING_REF_TO_HD_X', findRichText: true),
      findsOneWidget,
    ); // auto-expanded problem
  });

  testWidgets('mcp reconnect ready: status + tool chips', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _n('reconnect_mcp', '{"name":"acme"}', {
            'name': 'acme',
            'status': 'ready',
            'connectedAt': '2026-08-04T07:30:18Z',
            'tools': [
              {'name': 'search_docs'},
              {'name': 'fetch_page'},
            ],
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.textContaining(t.chat.tool.reconnectedMcp),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.mcpConnected), findsOneWidget);
    expect(find.text(t.chat.tool.mcpDisconnected), findsNothing);
    expect(find.text('search_docs'), findsOneWidget);
    expect(find.text(t.chat.tool.mcpConnectedAt), findsOneWidget);
    expect(find.text('2026-08-04 15:30'), findsOneWidget);
  });

  testWidgets('mcp install error auto-expands with the last error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _n('install_mcp_server', '{"name":"broken"}', {
            'name': 'broken',
            'status': 'error',
            'consecutiveFailures': 3,
            'lastError': 'MCP_SERVER_ENV_MISSING',
            'tools': [],
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('MCP_SERVER_ENV_MISSING'),
      findsOneWidget,
    ); // auto-expanded
  });

  testWidgets('mcp install plain missing-env result is red and expanded', (
    tester,
  ) async {
    const missing =
        'required environment variables missing (missing=[ENTRA_CLIENT_ID])';
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _raw(
            'install_mcp_server',
            '{"name":"io.github.microsoft/EnterpriseMCP"}',
            missing,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().contains(t.chat.tool.mcpError) ==
                true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ENTRA_CLIENT_ID'), findsOneWidget);
  });

  testWidgets(
    'list_mcp_marketplace: renders installable rows and required-env badge',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _n('list_mcp_marketplace', '{"query":"database"}', {
              'count': 2,
              'servers': [
                {
                  'name': 'acme/database',
                  'description': 'Query an Acme database',
                  'runtime': 'node',
                  'env': [
                    {'name': 'ACME_TOKEN', 'required': true},
                    {'name': 'ACME_REGION', 'required': false},
                  ],
                },
                {
                  'name': 'acme/remote-db',
                  'description': 'Hosted database tools',
                  'runtime': 'remote',
                  'env': const [],
                },
              ],
            }),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.textContaining(t.chat.tool.browsedMarket),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToolHitList), findsOneWidget);
      expect(find.text('acme/database'), findsOneWidget);
      expect(find.text('acme/remote-db'), findsOneWidget);
      expect(find.text('node'), findsOneWidget);
      expect(find.text(t.chat.tool.mcpEnvRequired(n: '1')), findsOneWidget);
    },
  );

  testWidgets(
    'list_mcp_marketplace: over-cap list keeps an honest first/total escape hatch',
    (tester) async {
      final servers = [
        for (var i = 0; i < 31; i++)
          {
            'name': 'acme/server-$i',
            'description': 'Server $i',
            'runtime': 'remote',
            'env': const [],
          },
      ];
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _n('list_mcp_marketplace', '{}', {
              'count': servers.length,
              'servers': servers,
            }),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.textContaining(t.chat.tool.browsedMarket),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(t.chat.tool.cappedFooter(n: '30', total: '31')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'get_model_config: reads modelId from the real wire — NEVER dumps the map or leaks apiKeyId',
    (tester) async {
      // Real wire (config.go): defaultModels values are {apiKeyId, modelId} maps; availableModels entries
      // are {apiKeyId, provider, modelId, displayName, contextWindow}. The card must show only the modelId.
      // 真线缆:值是含 apiKeyId 的 map,卡片只显 modelId、绝不倾倒 map / 泄漏 apiKeyId。
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _n('get_model_config', '{}', {
              'defaultModels': {
                'chat': {
                  'apiKeyId': 'key_SECRET_LEAK',
                  'modelId': 'claude-sonnet-5',
                },
                'agent': 'not configured',
              },
              'apiKeys': [
                {
                  'id': 'k1',
                  'displayName': 'Primary key',
                  'provider': 'anselm',
                  'keyMasked': 'sk-abcd...wxyz',
                  'baseUrl': 'https://api.example.test/v1',
                  'testStatus': 'ok',
                },
                {
                  'id': 'k2',
                  'displayName': 'Backup key',
                  'provider': 'openai',
                  'keyMasked': 'sk-efgh...uvwx',
                  'baseUrl': 'https://backup.example.test/v1',
                  'testStatus': 'failed',
                },
              ],
              'availableModels': [
                {
                  'apiKeyId': 'key_SECRET_LEAK',
                  'provider': 'anselm',
                  'modelId': 'claude-sonnet-5',
                  'displayName': 'Sonnet 5',
                  'contextWindow': 200000,
                  'maxOutput': 16000,
                  'vision': true,
                  'video': false,
                  'audio': false,
                  'nativeOptions': [
                    {'key': 'thinking', 'label': 'Thinking'},
                  ],
                },
                {
                  'apiKeyId': 'key_SECRET_LEAK',
                  'provider': 'anselm',
                  'modelId': 'claude-opus-4-8',
                  'displayName': 'Opus 4.8',
                  'contextWindow': 128000,
                },
              ],
            }),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.textContaining(t.chat.tool.gotModelConfig),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('claude-sonnet-5'),
        findsWidgets,
      ); // default row + available chip show the modelId
      expect(find.text('claude-opus-4-8'), findsOneWidget); // available chip
      expect(find.text('sk-abcd...wxyz'), findsOneWidget);
      expect(find.text('Primary key'), findsWidgets);
      expect(find.text('https://api.example.test/v1'), findsOneWidget);
      expect(find.text('200k'), findsOneWidget);
      expect(find.text('16k'), findsOneWidget);
      expect(find.text(t.chat.tool.modelVision), findsOneWidget);
      expect(find.text('Thinking'), findsOneWidget);
      // The apiKeyId must NEVER reach the widget tree (privacy) — no raw map dump either.
      expect(find.textContaining('key_SECRET_LEAK'), findsNothing);
      expect(find.textContaining('apiKeyId'), findsNothing);
    },
  );
}
