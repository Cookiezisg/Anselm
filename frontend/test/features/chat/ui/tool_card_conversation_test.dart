import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_conversation.dart';
import 'package:anselm/features/chat/ui/tool_hit_list.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F17 conversation (B3.7) — action-dispatched verb + soft-fail neutral degrade + status echo; list/
// search mini-rail + truncation notes. F17 对话薄卡:动词分派 + 软失败中性 + 迷你 rail。

ToolCardState _s(String name, String result, {String args = '{}'}) =>
    ToolCardState(
      phase: ToolCardPhase.succeeded,
      toolName: name,
      summary: '',
      danger: '',
      argsText: args,
      resultText: result,
      errorText: '',
      progressText: '',
      progressLive: false,
    );

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
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

  group('manage_conversation verb dispatch', () {
    ToolCardState st(String action, {String? title}) => _s(
      'manage_conversation',
      '{"conversationId":"cv_1","action":"$action"${title == null ? '' : ',"title":"$title"'},"archived":false,"pinned":false}',
      args: '{"action":"$action"}',
    );

    test('settled verb reads output.action (5 pairs)', () {
      expect(
        manageConversationVerb(t, st('archive'), live: false),
        t.chat.tool.cvArchived,
      );
      expect(
        manageConversationVerb(t, st('pin'), live: false),
        t.chat.tool.cvPinned,
      );
      expect(
        manageConversationVerb(t, st('rename', title: 'x'), live: false),
        t.chat.tool.cvRenamed,
      );
    });

    test(
      'soft-fail (no conversation in ctx) → NEUTRAL 已调用, never a lying 已置顶对话',
      () {
        final soft = _s(
          'manage_conversation',
          'manage_conversation is only available inside a conversation (no conversationId in context).',
          args: '{"action":"pin"}',
        );
        expect(
          manageConversationVerb(t, soft, live: false),
          t.chat.tool.called,
        );
      },
    );
  });

  group('receipts', () {
    test('list: N 条 / N+ 条 (nextCursor) / 无对话', () {
      expect(
        listConversationsReceipt(t, '{"count":3,"conversations":[{}]}')!.text,
        t.chat.tool.cvCount(n: '3'),
      );
      expect(
        listConversationsReceipt(
          t,
          '{"count":3,"conversations":[{}],"nextCursor":"x"}',
        )!.text,
        t.chat.tool.cvCountMore(n: '3'),
      );
      expect(
        listConversationsReceipt(t, '{"count":0,"conversations":[]}')!.text,
        t.chat.tool.cvEmpty,
      );
    });

    test('search: N 命中 / 无匹配 (uses total, not count)', () {
      expect(
        searchConversationsReceipt(t, '{"total":9,"hits":[{}]}')!.text,
        t.chat.tool.cvHits(n: '9'),
      );
      expect(
        searchConversationsReceipt(t, '{"total":0,"hits":[]}')!.text,
        t.chat.tool.cvNoMatch,
      );
    });
  });

  testWidgets('list_conversations → a mini-rail of tappable conversation rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'list_conversations',
            '{}',
            '{"count":2,"conversations":[{"conversationId":"cv_1","title":"alpha","archived":false,"pinned":true,"lastMessageAt":"2026-07-05T14:00:00Z"},{"conversationId":"cv_2","title":"beta","archived":true,"pinned":false,"lastMessageAt":"2026-07-04T09:00:00Z"}]}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已列出对话'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(
      find.text(t.chat.tool.cvArchivedBadge),
      findsOneWidget,
    ); // beta is archived
  });

  testWidgets(
    'search_conversations → hits with snippet + truncation note (total > shown)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'search_conversations',
              '{"query":"x"}',
              '{"total":9,"hits":[{"conversationId":"cv_1","title":"alpha","snippet":"a snippet","matchedChunks":3}]}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已搜索对话'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('a snippet'), findsOneWidget);
      expect(
        find.text(t.chat.tool.cvShownOfTotal(n: '1', total: '9')),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty search/list → «receipt IS the card» (no body)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'search_conversations',
            '{"query":"x"}',
            '{"total":0,"hits":[]}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已搜索对话'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsNothing);
  });
}
