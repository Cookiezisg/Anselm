import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/an_version_diff.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Edit two-act live pane + settled diff (B4 F01.4) — − old streams, then + new; settled = AnVersionDiff
// + replace_all note. Edit 两幕活窗 + 落定 diff。

BlockNode _settled(String args, String result) => BlockNode(id: 'tc_e', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'Edit', 'arguments': args}
  ..children.add(BlockNode(id: 'tr_e', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

BlockNode _streaming(String chunk) {
  const scope = StreamScope(kind: 'conversation', id: 'cv_e');
  final r = BlockTreeReducer()
    ..apply(const StreamEnvelope(
        seq: 1, scope: scope, id: 'tc_es',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'Edit'}))))
    ..apply(StreamEnvelope(seq: 0, scope: scope, id: 'tc_es', frame: FrameDelta(chunk: chunk)));
  return r.roots.single;
}

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('LIVE two-act behind the chevron: collapsed by default, TAP opens − old then + new (WRK-065)',
      (tester) async {
    // old_string arrived, new_string still open. old 到、new 未闭合。
    await tester.pumpWidget(_host(ChatToolCard(
        node: _streaming('{"file_path":"/ws/a.py","old_string":"return x","new_string":"return y + z'))));
    await tester.pump();
    expect(find.textContaining('− return x'), findsNothing); // default collapsed 默认收起
    await tester.tap(find.textContaining('正在编辑'), warnIfMissed: false);
    // Bounded pumps — the live shimmer never settles. 有界 pump(活流光永不安定)。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('− return x'), findsOneWidget); // the removed segment
    expect(find.textContaining('+ return y + z'), findsOneWidget); // the added segment (streaming)
  });

  testWidgets('SETTLED: a unified AnVersionDiff (before=old, after=new)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _settled(
        r'{"file_path":"/ws/a.py","old_string":"a = 1","new_string":"a = 2"}',
        'Replaced 1 occurrence in /ws/a.py.'))));
    await tester.pump();
    await tester.tap(find.textContaining('已编辑'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnVersionDiff), findsOneWidget);
  });

  testWidgets('SETTLED replace_all: an «N 处全部替换» note', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _settled(
        r'{"file_path":"/ws/a.py","old_string":"x","new_string":"y","replace_all":true}',
        'Replaced 4 occurrences in /ws/a.py.'))));
    await tester.pump();
    await tester.tap(find.textContaining('已编辑'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.replaceAllNote(n: '4')), findsOneWidget);
  });
}
