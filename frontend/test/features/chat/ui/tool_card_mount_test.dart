import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_json_tree.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/tool_card_mount.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F01 mount skins (B4 F01.5) — name-based routing (mcp__/handler__) + MCP raw string + handler {result}.
// mount 三式:按名字路由 + MCP 纯串 + handler {result}。

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_m', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_m', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: c)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('name parsing + routing', () {
    test('parseMcpName: leftmost split after mcp__', () {
      final p = parseMcpName('mcp__linear__create_issue')!;
      expect(p.server, 'linear');
      expect(p.tool, 'create_issue');
      expect(parseMcpName('not_mcp'), isNull);
    });
    test('parseHandlerName: rightmost split', () {
      final p = parseHandlerName('billing_webhook__charge')!;
      expect(p.handler, 'billing_webhook');
      expect(p.method, 'charge');
      expect(parseHandlerName('bare'), isNull); // no __ → not a handler mount
    });
    test('toolCardSpecFor routes mount names off the exact catalog', () {
      // mcp / handler names resolve to a mount spec (target chip proves routing). 路由到 mount。
      expect(toolCardSpecFor('mcp__x__y').target!(_state('mcp__x__y')), 'x/y');
      expect(toolCardSpecFor('h__m').target!(_state('h__m')), 'h.m()');
    });
  });

  testWidgets('MCP tool: server/tool chip + raw string body (never markdown)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'mcp__linear__create_issue',
            '{}',
            'Created issue ENG-1\nURL: https://linear.app/x',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('linear/create_issue'), findsOneWidget); // chip
    await tester.tap(find.textContaining('已调用 MCP 工具'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // The URL is opaque mono text, NOT a rendered markdown link. URL 是纯 mono 非 markdown。
    expect(find.textContaining('https://linear.app/x'), findsOneWidget);
  });

  testWidgets('MCP resolution error → red receipt + auto-expand', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'mcp__linear__x',
            '{}',
            'mcp server "linear" is not connected: MCP_SERVER_NOT_CONNECTED',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.mcpError), findsOneWidget);
    expect(
      find.textContaining('MCP_SERVER_NOT_CONNECTED'),
      findsOneWidget,
    ); // auto-expanded
  });

  testWidgets('handler method: handler.method() chip + {result} JSON tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'billing_webhook__charge',
            '{}',
            '{"result":{"chargeId":"ch_1","status":"succeeded"}}',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('billing_webhook.charge()'),
      findsOneWidget,
    ); // chip
    await tester.tap(find.textContaining('已调用方法'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnJsonTree), findsOneWidget); // {result} tree
  });
}

// helper to build a state for the target() closure
ToolCardState _state(String name) => ToolCardState(
  phase: ToolCardPhase.succeeded,
  toolName: name,
  summary: '',
  danger: '',
  argsText: '{}',
  resultText: '',
  errorText: '',
  progressText: '',
  progressLive: false,
);
