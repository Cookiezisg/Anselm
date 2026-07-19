import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_fade_collapse.dart';
import 'package:anselm/core/ui/an_path_chip.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Write live window + settled body (B4 F01.3) — the file streams in as the LLM types (last 8 lines),
// then settles to a folded, capped, copyable code window. Write 活窗 + 落定体。

BlockNode _settled(String args, String result) => BlockNode(id: 'tc_w', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'Write', 'arguments': args}
  ..children.add(BlockNode(id: 'tr_w', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

BlockNode _streaming(String chunk) {
  const scope = StreamScope(kind: 'conversation', id: 'cv_w');
  final r = BlockTreeReducer()
    ..apply(const StreamEnvelope(
        seq: 1, scope: scope, id: 'tc_ws',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'Write'}))))
    ..apply(StreamEnvelope(seq: 0, scope: scope, id: 'tc_ws', frame: FrameDelta(chunk: chunk)));
  return r.roots.single;
}

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('LIVE: collapsed by default; TAP opens the growth show (WRK-065)', (tester) async {
    // content value still OPEN — nothing shows until the user opens the card; the live tail then
    // shows what has arrived. content 未闭合——默认收起;点开后活尾显已流入。
    await tester.pumpWidget(_host(ChatToolCard(
        node: _streaming('{"file_path":"/ws/a.py","content":"line1\\nline2\\nline3\\ndef f(): pass'))));
    await tester.pump();
    expect(find.textContaining('def f(): pass'), findsNothing); // default collapsed 默认收起
    await tester.tap(find.textContaining('正在写入'), warnIfMissed: false);
    // Bounded pumps — the live shimmer never settles. 有界 pump(活流光永不安定)。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('def f(): pass'), findsOneWidget); // the streamed-so-far tail
  });

  testWidgets('SETTLED: highlighted code window + path chip + copy full content', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _settled(
        r'{"file_path":"/ws/functions/quarters.py","content":"def q(d):\n    return (d.month-1)//3+1\n"}',
        'Wrote /ws/functions/quarters.py'))));
    await tester.pump();
    await tester.tap(find.textContaining('已写入'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnCodeEditor), findsOneWidget);
    expect(find.byType(AnPathChip), findsOneWidget); // path header
    // basename shows in BOTH the row target chip and the body path chip. row chip + body chip 两处。
    expect(find.text('quarters.py'), findsWidgets);
  });

  testWidgets('SETTLED: a long file stays in the SAME bounded viewport tier (批2 零跳变,折叠退役)',
      (tester) async {
    final big = List.generate(80, (i) => 'line_$i = $i').join(r'\n');
    await tester.pumpWidget(_host(ChatToolCard(node: _settled(
        '{"file_path":"/ws/big.py","content":"$big"}', 'Wrote /ws/big.py'))));
    await tester.pump();
    await tester.tap(find.textContaining('已写入'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Zero-jump (拍板 #2): both faces share AnSize.codeViewport — no expanding fold (a fold IS a
    // height jump). 零跳变:两脸同档,折叠退役(展开即跳变)。
    expect(find.byType(AnFadeCollapse), findsNothing);
    final editor = tester.widget<AnCodeEditor>(find.byType(AnCodeEditor));
    expect(editor.maxHeight, AnSize.codeViewport);
    expect(editor.live, isFalse);
  });

  testWidgets('empty content → no body (receipt says 空文件)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _settled('{"file_path":"/ws/empty.txt","content":""}', 'Wrote /ws/empty.txt'))));
    await tester.pump();
    expect(find.textContaining(t.chat.tool.emptyFile), findsOneWidget); // receipt
    expect(find.byType(AnCodeEditor), findsNothing); // no code body
  });
}
