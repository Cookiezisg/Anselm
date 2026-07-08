import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/model/partial_json.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_skins.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V3c builds behaviors: the kind-noun verb; the LIVE code window streaming a STILL-OPEN
// set_code value; the settled highlighted editor + result bar (id · vN · env); env-failed is
// a danger receipt that auto-expands with the red envError; argStringPartial contract.
// V3c 构建族行为:类名词动词;活代码窗流**未闭合** set_code 值;落定高亮编辑器+结果条;
// env 失败=危险色回执+自动展开+红 envError;argStringPartial 契约。

BlockNode _call(String name, {String? args, String? result}) {
  final node = BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {'name': name, 'arguments': ?args};
  if (result != null) {
    node.children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': result});
  }
  return node;
}

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

  test('argStringPartial: closed value, open value, absent key', () {
    expect(argStringPartial('{"code":"done"}', 'code'), 'done');
    expect(argStringPartial('{"code":"def f():\\n    ret', 'code'), 'def f():\n    ret');
    expect(argStringPartial('{"other":"x"}', 'code'), isNull);
  });

  test('buildContentOf routes per entity kind', () {
    expect(buildContentOf('create_function', PartialJsonSession()..append('{"ops":[{"op":"set_code","code":"x = 1"}]}')), 'x = 1');
    expect(buildContentOf('edit_agent', PartialJsonSession()..append('{"agentId":"ag_1","prompt":"be sharp"}')), 'be sharp');
    expect(buildContentOf('create_document', PartialJsonSession()..append('{"name":"n","content":"# t"}')), '# t');
    expect(buildContentOf('create_workflow', PartialJsonSession()..append('{"graph":{}}')), isNull); // JSON fallback 配置走 JSON
  });

  testWidgets('mid-stream: kind-noun verb + streaming name target + LIVE code window',
      (tester) async {
    const scope = StreamScope(kind: 'conversation', id: 'cv_1');
    final r = BlockTreeReducer()
      ..apply(const StreamEnvelope(
          seq: 1, scope: scope, id: 'tc_b',
          frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'create_function'}))))
      ..apply(const StreamEnvelope(
          seq: 0, scope: scope, id: 'tc_b',
          frame: FrameDelta(
              chunk: '{"ops":[{"op":"set_meta","name":"rollup"},{"op":"set_code","code":"import json\\ndef rol')));
    await tester.pumpWidget(_host(ChatToolCard(node: r.roots.single)));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在创建函数'), findsOneWidget);
    expect(find.text('rollup'), findsOneWidget); // streaming name target 流中名字目标
    expect(find.byType(ToolWindow), findsOneWidget); // live code window 活代码窗
    expect(find.textContaining('def rol'), findsOneWidget); // still-open value streams 未闭合值在流
  });

  testWidgets('settled: highlighted editor + result bar id·vN·env ready', (tester) async {
    final ok = _call('create_function',
        args: '{"ops":[{"op":"set_meta","name":"rollup"},{"op":"set_code","code":"x = 1\\n"}]}',
        result: '{"id":"fn_1","versionId":"fnv_1","version":1,"envStatus":"ready","opsApplied":2}');
    await tester.pumpWidget(_host(ChatToolCard(node: ok, key: const ValueKey('ok'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('已创建函数'), findsOneWidget);
    expect(find.textContaining('v1'), findsOneWidget); // receipt 回执
    await tester.tap(find.textContaining('已创建函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnCodeEditor), findsOneWidget); // settled → highlighted 落定高亮
    // Result bar: a provenance RefPill (label = the function name, id = fn_1 as its tap target) + env.
    // 结果条:凭据 RefPill(label=函数名、id=fn_1 作点击目标)+ env。
    expect(find.byType(AnRefPill), findsOneWidget);
    expect(find.textContaining('env 就绪', findRichText: true), findsWidgets);
  });

  testWidgets('env failed: danger receipt + auto-expanded + red envError', (tester) async {
    final bad = _call('create_function',
        args: '{"ops":[{"op":"set_code","code":"x = 1"}]}',
        result:
            '{"id":"fn_1","version":1,"envStatus":"failed","envError":"pip install nope==9: not found"}');
    await tester.pumpWidget(_host(ChatToolCard(node: bad, key: const ValueKey('bad'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('env 失败'), findsWidgets); // receipt (danger) 危险色回执
    expect(find.textContaining('pip install nope'), findsOneWidget); // auto-expanded 自动展开
  });

  testWidgets('edit: kind verb + id target; prose-output create has no result bar',
      (tester) async {
    final edit = _call('edit_agent',
        args: '{"agentId":"ag_1","prompt":"be sharp"}',
        result: '{"id":"ag_1","versionId":"agv_2","version":3}');
    await tester.pumpWidget(_host(ChatToolCard(node: edit, key: const ValueKey('e'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('已更新智能体'), findsOneWidget);
    expect(find.text('ag_1'), findsOneWidget); // collapsed-row edit target chip (result bar is in the body)
    expect(find.textContaining('v3'), findsOneWidget);

    final doc = _call('create_document',
        args: '{"name":"口径","content":"# t"}',
        result: 'Created document "口径" (id=doc_1, path=/口径)');
    await tester.pumpWidget(_host(ChatToolCard(node: doc, key: const ValueKey('d'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('已创建文档'), findsOneWidget);
    expect(find.text('口径'), findsOneWidget); // name target 名字目标
  });

  testWidgets('env self-heal: envFixAttempts renders the EnvFixTimeline (fail then ok)', (tester) async {
    final n = _call('create_function',
        args: '{"ops":[{"op":"set_code","code":"x=1\\n"}]}',
        result:
            '{"id":"fn_1","version":2,"envStatus":"ready","opsApplied":1,"envFixAttempts":[{"attempt":1,"deps":["pandas==9.9.9"],"ok":false,"error":"No matching distribution"},{"attempt":2,"deps":["pandas"],"ok":true}]}');
    await tester.pumpWidget(_host(ChatToolCard(node: n, key: const ValueKey('heal'))));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('已创建函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('环境自愈'), findsOneWidget); // the timeline header
    expect(find.textContaining('尝试 1'), findsOneWidget);
    expect(find.textContaining('尝试 2'), findsOneWidget);
    expect(find.textContaining('No matching distribution'), findsOneWidget); // attempt 1 error
  });

  testWidgets('edit_handler crashed: danger receipt auto-expands + red runtimeWarning', (tester) async {
    final n = _call('edit_handler',
        args: '{"handlerId":"hd_1","ops":[{"op":"add_method","method":{"name":"m","body":"raise"}}]}',
        result:
            '{"id":"hd_1","version":5,"envStatus":"ready","opsApplied":1,"runtimeState":"crashed","runtimeWarning":"the resident instance is not running after this edit — revert_handler to the last good version"}');
    await tester.pumpWidget(_host(ChatToolCard(node: n, key: const ValueKey('crash'))));
    await tester.pumpAndSettle();
    // crashed → danger receipt → auto-expanded (no tap needed). crashed=危险回执→自动展开。
    expect(find.textContaining('实例已崩溃'), findsWidgets); // receipt + body badge
    expect(find.textContaining('revert_handler to the last good'), findsOneWidget); // red warning line
  });

  testWidgets('edit_handler stopped: benign muted badge, NO warning line, NOT auto-expanded', (tester) async {
    final n = _call('edit_handler',
        args: '{"handlerId":"hd_1","ops":[{"op":"set_meta","name":"renamed"}]}',
        result: '{"id":"hd_1","version":3,"envStatus":"ready","opsApplied":1,"runtimeState":"stopped",'
            '"runtimeWarning":"the resident instance is not running after this edit — may need config"}');
    await tester.pumpWidget(_host(ChatToolCard(node: n, key: const ValueKey('stop'))));
    await tester.pumpAndSettle();
    // stopped is benign → NOT auto-expanded (collapsed), so no warning line shows. 良性→不自动展开。
    expect(find.textContaining('may need config'), findsNothing); // warning suppressed for stopped
    // Expand → the stopped badge shows, still no red warning line (census correction). 展开→静音徽、仍无红警。
    await tester.tap(find.textContaining('已更新处理器'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('实例未运行'), findsWidgets); // muted badge
    expect(find.textContaining('may need config'), findsNothing); // still no warning (benign)
  });

  testWidgets('RunStatBar dual-key id: falls back to <entity>Id when there is no top-level id',
      (tester) async {
    // A result carrying only `functionId` (no `id`) still yields a provenance pill. 只有 functionId 也出 pill。
    final n = _call('edit_function',
        args: '{"functionId":"fn_9","ops":[{"op":"set_code","code":"y = 2\\n"}]}',
        result: '{"functionId":"fn_9","version":4}');
    await tester.pumpWidget(_host(ChatToolCard(node: n, key: const ValueKey('dk'))));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('已更新函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnRefPill), findsOneWidget); // pill from the fallback id 兜底 id 出 pill
    expect(find.textContaining('v4'), findsWidgets);
  });
}
