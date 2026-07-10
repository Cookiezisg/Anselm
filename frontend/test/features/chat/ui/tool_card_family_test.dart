import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_skins.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V3b family behaviors: Read is receipt-only (no chevron, tap inert); a danger-toned receipt
// (Bash exit≠0 / timeout) auto-expands like a failure; the live terminal tail shows while
// running and leaves when settled; Edit renders the diff window, Write the code window;
// family verbs/receipts speak on the line.
// V3b 族行为:Read 回执即卡(无 chevron、点了不动);危险色回执(Bash 非零 exit/超时)视同失败
// 自动展开;活终端尾巴运行中在、落定即走;Edit 渲 diff 窗、Write 渲代码窗;族动词/回执上行。

BlockNode _call(String name,
    {String status = 'completed', Map<String, dynamic>? extra}) =>
    BlockNode(id: 'tc_1', kind: BlockKind.toolCall)
      ..status = status
      ..content = {'name': name, ...?extra};

BlockNode _result(String text, {bool error = false}) =>
    BlockNode(id: 'tr_1', kind: BlockKind.toolResult)
      ..status = error ? 'error' : 'completed'
      ..error = error ? text : null
      ..content = {'content': text};

BlockNode _progress(String text, {bool live = false}) =>
    BlockNode(id: 'pr_1', kind: BlockKind.progress)
      ..status = live ? 'open' : 'completed'
      ..content = {'text': text};

Widget _host(Widget child) => TranslationProvider(
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SizedBox(width: 560, child: Center(child: child)))),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('Read: receipt-only card — verb+basename+lines, no chevron, tap inert',
      (tester) async {
    final read = _call('Read', extra: {'arguments': '{"file_path":"/ws/rollup.py"}'})
      ..children.add(_result('    1\ta\n    2\tb\n'));
    await tester.pumpWidget(_host(ChatToolCard(node: read)));
    await tester.pumpAndSettle();
    expect(find.text('已读取'), findsOneWidget);
    expect(find.text('rollup.py'), findsOneWidget);
    expect(find.textContaining('2 行'), findsOneWidget);
    expect(find.byIcon(AnIcons.chevronRight), findsNothing); // bodyless 无 chevron
    await tester.tap(find.text('已读取'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.widget<AnExpandReveal>(find.byType(AnExpandReveal).last).open, isFalse);
  });

  testWidgets('Bash exit≠0: danger receipt on the line AND auto-expanded terminal window',
      (tester) async {
    final bash = _call('Bash', extra: {'arguments': '{"command":"npm test"}'})
      ..children.add(_result('boom\n[exit code: 1]'));
    await tester.pumpWidget(_host(ChatToolCard(node: bash)));
    await tester.pumpAndSettle();
    // B4.5: «exit 1» now appears TWICE — the collapsed-row receipt + the stripped-footer bottom bar chip.
    expect(find.textContaining('exit 1'), findsNWidgets(2));
    expect(find.byType(ToolWindow), findsOneWidget); // auto-expanded 自动展开
    expect(find.textContaining('\$ npm test'), findsOneWidget); // command echo header 命令回显头
    // The [exit code: 1] footer is STRIPPED from the terminal body (it's a chip now). footer 剥离出正文。
    expect(find.textContaining('[exit code:'), findsNothing);
  });

  testWidgets('Bash running: collapsed by default; TAP opens the live terminal (WRK-065)',
      (tester) async {
    final running = _call('Bash', extra: {'arguments': '{"command":"npm test"}'})
      ..children.add(_progress('line 1\nline 2\nline 3\nline 4', live: true));
    await tester.pumpWidget(_host(ChatToolCard(node: running, key: const ValueKey('run'))));
    await tester.pumpAndSettle();
    // Default collapsed while running — no auto machine window (WRK-065). 运行中默认收起,不自动弹窗。
    expect(find.byType(ToolWindow), findsNothing);
    expect(find.textContaining('line 4'), findsNothing);
    // TAP → the body's live face: the full live terminal (progress preferred, $ cmd echo header).
    // 点开=活脸:完整活终端(progress 优先、$ 命令回显头)。
    await tester.tap(find.textContaining('正在执行'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolWindow), findsOneWidget);
    expect(find.textContaining('\$ npm test'), findsOneWidget); // in-flight command echo 在途命令回显
    expect(find.textContaining('line 4'), findsOneWidget);

    final settled = _call('Bash', extra: {'arguments': '{"command":"npm test"}'})
      ..children.add(_progress('line 1\nline 2'))
      ..children.add(_result('done\n[exit code: 0]'));
    await tester.pumpWidget(_host(ChatToolCard(node: settled, key: const ValueKey('settled'))));
    await tester.pumpAndSettle();
    expect(tester.widget<AnExpandReveal>(find.byType(AnExpandReveal).first).open, isFalse);
    expect(find.textContaining('exit 0'), findsOneWidget);
  });

  testWidgets('Edit renders the diff window; Write renders the code window', (tester) async {
    final edit = _call('Edit', extra: {
      'arguments':
          '{"file_path":"/ws/a.py","old_string":"x = 1","new_string":"x = 2"}'
    })
      ..children.add(_result('Edited /ws/a.py'));
    await tester.pumpWidget(_host(ChatToolCard(node: edit, key: const ValueKey('edit'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已编辑'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnVersionDiff), findsOneWidget);

    final write = _call('Write', extra: {
      'arguments': '{"file_path":"/ws/b.py","content":"print(1)\\nprint(2)"}'
    })
      ..children.add(_result('Wrote /ws/b.py'));
    await tester.pumpWidget(_host(ChatToolCard(node: write, key: const ValueKey('write'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 行'), findsOneWidget); // receipt from args content 回执自 args
    await tester.tap(find.text('已写入'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnCodeEditor), findsOneWidget);
  });

  testWidgets('Grep: count receipt + hit window; honest no-match', (tester) async {
    final grep = _call('Grep', extra: {'arguments': '{"pattern":"amount"}'})
      ..children.add(_result('a.py:1: amount\nb.py:2: amount\n'));
    await tester.pumpWidget(_host(ChatToolCard(node: grep, key: const ValueKey('grep'))));
    await tester.pumpAndSettle();
    expect(find.text('"amount"'), findsOneWidget); // quoted query chip 引号包 query
    expect(find.textContaining('2 处匹配'), findsOneWidget);

    final none = _call('Grep', extra: {'arguments': '{"pattern":"xyzzy"}'})
      ..children.add(_result('No matches for "xyzzy" in /ws.'));
    await tester.pumpWidget(_host(ChatToolCard(node: none, key: const ValueKey('none'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('无匹配'), findsOneWidget);
  });

  testWidgets('mid-stream: family verb + target appear while args still streaming',
      (tester) async {
    const scope = StreamScope(kind: 'conversation', id: 'cv_1');
    final r = BlockTreeReducer()
      ..apply(const StreamEnvelope(
          seq: 1, scope: scope, id: 'tc_s',
          frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'Bash'}))))
      ..apply(const StreamEnvelope(
          seq: 0, scope: scope, id: 'tc_s',
          frame: FrameDelta(chunk: '{"command":"npm test","summary":"Run the')));
    await tester.pumpWidget(_host(ChatToolCard(node: r.roots.single)));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在执行命令'), findsOneWidget);
    expect(find.text('npm test'), findsOneWidget); // closed field extracted mid-stream 流中提取
  });

  testWidgets('call_handler RUNNING opened: live yields directly visible, NO fake «无返回值» (WRK-065)',
      (tester) async {
    // args closed, no result yet = running; yields streaming. args 闭、无 result=running,yield 在流。
    final running = _call('call_handler',
        extra: {'arguments': '{"handlerId":"hd_1","method":"run","args":{}}'})
      ..children.add(_progress('yield 1\nyield 2', live: true));
    await tester.pumpWidget(_host(ChatToolCard(node: running)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnInteractive).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('yield 2'), findsOneWidget); // live tail direct, not behind a drawer 直显
    expect(find.text(t.chat.tool.noReturn), findsNothing); // never lie mid-run 在飞绝不渲「无返回值」
  });

  testWidgets('mcp mount RUNNING opened: the progress tail shows, no empty result shell (WRK-065)',
      (tester) async {
    final running = _call('mcp__github__create_issue',
        extra: {'arguments': '{"title":"bug"}'})
      ..children.add(_progress('contacting server…', live: true));
    await tester.pumpWidget(_host(ChatToolCard(node: running)));
    await tester.pumpAndSettle();
    // Collapsed by default. 默认收起。
    expect(find.byType(ToolWindow), findsNothing);
    await tester.tap(find.byType(AnInteractive).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('contacting server'), findsOneWidget); // live progress 活进度
    expect(find.byType(ToolWindow), findsOneWidget); // ONLY the tail — no empty result shell 无空结果壳
  });

  testWidgets('ToolLiveTail: whitespace-only progress renders NO empty machine window', (tester) async {
    await tester.pumpWidget(_host(const ToolLiveTail(text: '\n')));
    await tester.pumpAndSettle();
    expect(find.byType(ToolWindow), findsNothing); // trim guard 空白守卫
  });
}
