import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/ui/turn_actions.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// CH-a 动作排 (WRK-077 §3.2). The user asked for copy first ("我要复制"), so the assertions that matter are
// about what actually lands on the clipboard and when the row is reachable.
//
// CH-a 动作排(WRK-077 §3.2)。用户第一个要的就是复制(「我要复制」),故真正要紧的断言是**究竟什么落到了剪贴板**
// 以及动作排何时可达。
void main() {
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('turnCopyText — the clipboard source is the MODEL', () {
    // Reading the model is not a style choice: Cmd+A inside a lazy list only reaches BUILT items
    // (Flutter #153478), so a selection-based copy truncates a long turn at the viewport edge (TS 必补③).
    // 读 model 不是风格取舍:懒列表里的 Cmd+A 只触及**已建**条目,故基于选区的复制会在视口边缘截断长回合。

    test('an assistant turn joins its TEXT blocks and drops the machinery', () {
      final turn = BlockNode(id: 'm1', kind: BlockKind.message)
        ..content = {'role': 'assistant'};
      turn.children.addAll([
        BlockNode(id: 'b1', kind: BlockKind.reasoning)
          ..content = {'content': 'thinking out loud'},
        BlockNode(id: 'b2', kind: BlockKind.text)
          ..content = {'content': 'First paragraph.'},
        BlockNode(id: 'b3', kind: BlockKind.toolCall)
          ..content = {'content': 'run_function'},
        BlockNode(id: 'b4', kind: BlockKind.text)
          ..content = {'content': 'Second paragraph.'},
      ]);

      final copied = ConversationTranscript.turnCopyText(turn);
      expect(copied, 'First paragraph.\n\nSecond paragraph.');
      expect(
        copied,
        isNot(contains('thinking out loud')),
        reason: 'reasoning is the model thinking, not the reply',
      );
      expect(
        copied,
        isNot(contains('run_function')),
        reason: 'tool machinery is not what "copy this reply" means',
      );
    });

    test(
      'a user turn reads the inline echo, and the child block after a reload',
      () {
        // A live-echoed user turn carries its text inline; a REST reload puts it in a child text block. Both
        // must copy, or copying works before a reload and silently stops after one.
        // live 回声的用户回合文本内联,REST 重载后在子 text 块里。两处都要能复制,否则「重载前能复制、重载后静默失效」。
        final live = BlockNode(id: 'u1', kind: BlockKind.message)
          ..content = {'role': 'user', 'content': 'what I typed'};
        expect(ConversationTranscript.turnCopyText(live), 'what I typed');

        final reloaded = BlockNode(id: 'u2', kind: BlockKind.message)
          ..content = {'role': 'user'};
        reloaded.children.add(
          BlockNode(id: 'b1', kind: BlockKind.text)
            ..content = {'content': 'what I typed'},
        );
        expect(ConversationTranscript.turnCopyText(reloaded), 'what I typed');
      },
    );

    test('an empty turn yields an empty string, not a stray blank line', () {
      final turn = BlockNode(id: 'm', kind: BlockKind.message)
        ..content = {'role': 'assistant'};
      turn.children.add(
        BlockNode(id: 'b', kind: BlockKind.text)..content = {'content': '   '},
      );
      expect(ConversationTranscript.turnCopyText(turn), isEmpty);
    });
  });

  testWidgets(
    'Copy puts the turn text on the clipboard and confirms with a check',
    (tester) async {
      // Capture the real payload rather than an internal flag. 截真实载荷、非内部旗标。
      String? seen;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            seen = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        host(
          const TurnActions(
            copyText: 'the reply body',
            role: TurnActionsRole.assistant,
            alwaysVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();

      expect(seen, 'the reply body');
      // The check-mark is the only feedback there is, so it must actually appear. 对勾是唯一反馈,必须真的出现。
      expect(find.byTooltip('Copied'), findsOneWidget);
    },
  );

  testWidgets(
    'the last turn s row is visible at rest; a historical one is not',
    (tester) async {
      Widget at({required bool alwaysVisible}) => host(
        TurnActions(
          copyText: 'body',
          role: TurnActionsRole.assistant,
          alwaysVisible: alwaysVisible,
        ),
      );

      await tester.pumpWidget(at(alwaysVisible: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
        reason: 'a row that has to be discovered is a row that is not found',
      );

      await tester.pumpWidget(at(alwaysVisible: false));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
        reason: 'dozens of always-on rows down a transcript read as clutter',
      );
    },
  );

  testWidgets(
    'hovering a historical turn reveals its row — WITHOUT remounting it',
    (tester) async {
      await tester.pumpWidget(
        host(
          const TurnActions(
            copyText: 'body',
            role: TurnActionsRole.assistant,
            alwaysVisible: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = tester.element(find.byType(AnimatedOpacity));

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(TurnActions))),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      // Same element across the reveal: opacity, not a conditional subtree. A wrapper that comes and goes
      // would remount the row and drop its "copied" state (CLAUDE.md 禁止条件包装).
      // 揭示前后是**同一个** element:靠不透明度、不靠条件子树。来来去去的包装层会重挂这一行、丢掉它的「已复制」态。
      expect(tester.element(find.byType(AnimatedOpacity)), same(before));
    },
  );

  testWidgets(
    'an empty turn cannot be copied — the button is disabled, not a no-op that looks live',
    (tester) async {
      await tester.pumpWidget(
        host(
          const TurnActions(
            copyText: '',
            role: TurnActionsRole.user,
            alwaysVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy'), findsOneWidget);
      // Tapping must not claim success. 点它不许宣称成功。
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copied'), findsNothing);
    },
  );

  testWidgets(
    'a user row carries no Retry — only an assistant turn can be regenerated',
    (tester) async {
      await tester.pumpWidget(
        host(
          const TurnActions(
            copyText: 'body',
            role: TurnActionsRole.user,
            alwaysVisible: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry (coming in CH-c)'), findsNothing);
      expect(find.byTooltip('Fork from here (coming in CH-b)'), findsOneWidget);
    },
  );
}
