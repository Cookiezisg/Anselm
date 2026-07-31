import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_term_viewport.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// BashOutput + KillShell cards (B4.6/B4.7) — poll snapshot honesty (exited never auto-expands, session
// gone does) + KillShell three states + copyable bsh_id. BashOutput/KillShell 卡。

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
      body: SingleChildScrollView(child: SizedBox(width: 640, child: c)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'BashOutput running: bsh_id chip + terminal body + status receipt',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'BashOutput',
              '{"bash_id":"bsh_1a2b3c4d5e6f"}',
              'VITE ready\n  ➜ localhost:5173\n\n[status: running]',
            ),
          ),
        ),
      );
      await tester.pump();
      // collapsed receipt = 运行中 (running). 收起回执=运行中。
      expect(find.textContaining(t.chat.tool.statusRunning), findsWidgets);
      await tester.tap(find.textContaining('已读取输出'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is AnChip && w.copyValue != null),
        findsOneWidget,
      ); // the bsh_id copy chip (ref pills are chips too now) 复制芯片谓词
      expect(find.byType(AnTermViewport), findsOneWidget); // terminal body
    },
  );

  testWidgets(
    'BashOutput exited(0) does NOT auto-expand (poll snapshot honesty); session-gone DOES',
    (tester) async {
      // exited: danger receipt but the terminal body is NOT shown until tapped. exited 不自动展开。
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'BashOutput',
              '{"bash_id":"bsh_9"}',
              '(no new output since last poll)\n\n[status: exited (code 0)]',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is AnChip && w.copyValue != null),
        findsNothing,
      ); // body not expanded (no bsh chip visible yet)

      // session not found → auto-expands (the one exception). 会话不存在→自动展开。
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'BashOutput',
              '{"bash_id":"bsh_dead"}',
              'Background shell process not found: bsh_dead',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Background shell process not found'),
        findsOneWidget,
      );
      expect(
        find.textContaining(t.chat.tool.bashSessionGoneHint),
        findsOneWidget,
      ); // neutral hint
    },
  );

  testWidgets('KillShell three states use honest primary verbs', (
    tester,
  ) async {
    // killed → the primary verb states the action. killed 主行动词直接说清事实。
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'KillShell',
            '{"bash_id":"bsh_1"}',
            'Killed background shell bsh_1.',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining(t.chat.tool.killed3),
      findsOneWidget,
    ); // 已终止 verb

    // finished → the primary verb states that no kill was needed. 已自行结束。
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'KillShell',
            '{"bash_id":"bsh_9"}',
            'Background shell bsh_9 already finished; removed from registry.',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining(t.chat.tool.killFinished), findsOneWidget);

    // not-found → an idempotent no-op, not a contradictory success verb or orange warning.
    // 未找到 → 幂等无操作,不能同时显示矛盾的成功动词或橙色警告。
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'KillShell',
            '{"bash_id":"bsh_ghost"}',
            'Background shell process not found: bsh_ghost',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining(t.chat.tool.killNotFound), findsOneWidget);
    expect(find.textContaining(t.chat.tool.killed3), findsNothing);
    expect(find.textContaining(t.chat.tool.statusNotFound), findsNothing);
  });
}
