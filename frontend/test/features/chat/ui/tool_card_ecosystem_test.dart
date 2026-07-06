import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_ecosystem.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F12 relations + F13 mcp-mgmt + capability/model (B7.2) — receipts + bodies.

BlockNode _n(String name, String args, Map<String, dynamic> result) => BlockNode(id: 'tc_e', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(BlockNode(id: 'tr_e', kind: BlockKind.toolResult)..status = 'completed'..content = {'content': jsonEncode(result)});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 660, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('receipts', () {
    test('relations: N edges / none', () {
      expect(relationsReceipt(t, jsonEncode({'count': 3, 'edges': [1, 2, 3]}))!.text, contains('3'));
      expect(relationsReceipt(t, jsonEncode({'count': 0, 'edges': []}))!.text, t.chat.tool.relNoEdges);
    });
    test('capability: ok→grey/warn, problems→danger', () {
      expect(capabilityReceipt(t, jsonEncode({'ok': true, 'warnings': []}))!.tone, isNot(ToolReceiptTone.danger));
      expect(capabilityReceipt(t, jsonEncode({'ok': true, 'warnings': ['w']}))!.tone, ToolReceiptTone.warn);
      expect(capabilityReceipt(t, jsonEncode({'ok': false, 'problems': ['p1', 'p2']}))!.tone, ToolReceiptTone.danger);
      expect(capabilityFailed(jsonEncode({'ok': false})), isTrue);
    });
    test('mcp status: connected→tool count, else danger', () {
      expect(mcpStatusReceipt(t, jsonEncode({'status': 'connected', 'tools': [1, 2]}))!.tone, isNot(ToolReceiptTone.danger));
      expect(mcpStatusReceipt(t, jsonEncode({'status': 'error', 'tools': []}))!.tone, ToolReceiptTone.danger);
      expect(mcpStatusFailed(jsonEncode({'status': 'error'})), isTrue);
    });
    test('marketplace: N servers; model: N available', () {
      expect(marketplaceReceipt(t, jsonEncode({'count': 5, 'servers': []}))!.text, contains('5'));
      expect(modelConfigReceipt(t, jsonEncode({'availableModels': [1, 2, 3]}))!.text, contains('3'));
    });
  });

  testWidgets('get_relations: navigable from→to edge rows', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _n('get_relations', '{"kind":"agent","id":"ag_1"}', {
      'count': 1,
      'edges': [{'fromKind': 'agent', 'fromId': 'ag_1', 'fromName': 'triager', 'toKind': 'function', 'toId': 'fn_1', 'toName': 'fetcher'}],
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.gotRelations), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('triager'), findsOneWidget);
    expect(find.textContaining('fetcher'), findsOneWidget);
    expect(find.text(t.chat.tool.relArrow), findsOneWidget);
  });

  testWidgets('capability_check failed auto-expands with red problems', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _n('capability_check_workflow', '{"workflowId":"wf_1"}', {
      'id': 'wf_1', 'ok': false, 'structurallyValid': true,
      'problems': ['DANGLING_REF_TO_HD_X'], 'warnings': [],
    }))));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('DANGLING_REF_TO_HD_X', findRichText: true), findsOneWidget); // auto-expanded problem
  });

  testWidgets('mcp reconnect connected: status + tool chips', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _n('reconnect_mcp', '{"name":"acme"}', {
      'name': 'acme', 'status': 'connected', 'tools': [{'name': 'search_docs'}, {'name': 'fetch_page'}],
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.reconnectedMcp), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.mcpConnected), findsOneWidget);
    expect(find.text('search_docs'), findsOneWidget);
  });

  testWidgets('mcp install error auto-expands with the last error', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _n('install_mcp_server', '{"name":"broken"}', {
      'name': 'broken', 'status': 'error', 'consecutiveFailures': 3,
      'lastError': 'MCP_SERVER_ENV_MISSING', 'tools': [],
    }))));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('MCP_SERVER_ENV_MISSING'), findsOneWidget); // auto-expanded
  });

  testWidgets('get_model_config: default models + available chips', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _n('get_model_config', '{}', {
      'defaultModels': {'chat': 'claude-sonnet-5'}, 'apiKeys': [{'id': 'k1'}],
      'availableModels': [{'id': 'claude-sonnet-5'}, {'id': 'claude-opus-4-8'}],
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.gotModelConfig), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('claude-sonnet-5'), findsWidgets); // default + available chip
    expect(find.text('claude-opus-4-8'), findsOneWidget);
  });
}
