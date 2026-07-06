import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The chassis behaviour contract: verb per phase (registry voice), failure auto-expands once
// (user toggle wins after), the elapsed counter appears only past 3s and never ticks under
// reduced motion (the gallery battery's pumpAndSettle must stay safe), oversized content is
// excerpted with the honest note, weird tool names render (schema-less fallback).
// 底盘行为契约:相位动词(注册表声音)/失败自动展开一次(此后用户开关优先)/读秒仅 3s 后现且
// reduced 下绝不 tick(gallery 电池 pumpAndSettle 安全)/超限节选+诚实注记/离谱工具名可渲。

BlockNode _call(String name,
    {String status = 'completed', Map<String, dynamic>? extra}) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = status
      ..content = {'name': name, ...?extra};

BlockNode _result(String text, {bool error = false}) =>
    BlockNode(id: 'tr_x', kind: BlockKind.toolResult)
      ..status = error ? 'error' : 'completed'
      ..error = error ? text : null
      ..content = {'content': text};

Widget _host(Widget child, {bool reduced = false}) => TranslationProvider(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp(
          theme: AnTheme.light(),
          // The real transcript hosts cards inside a scroll viewport — mirror that so tall
          // bodies never overflow the test surface. 真 transcript 在滚动视口里托卡,测试同构。
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SizedBox(width: 560, child: Center(child: child)))),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('phases speak the registry verbs', (tester) async {
    final running = _call('run_function');
    await tester.pumpWidget(_host(ChatToolCard(node: running), reduced: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在调用'), findsOneWidget);
    expect(find.text('run_function'), findsOneWidget);

    final denied = _call('delete_agent')
      ..children.add(_result('The user denied running this tool. Do not retry it.'));
    await tester.pumpWidget(_host(ChatToolCard(node: denied), reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('已拒绝执行'), findsOneWidget);

    final cancelled = _call('run_function', status: 'cancelled');
    await tester.pumpWidget(_host(ChatToolCard(node: cancelled), reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('已中断'), findsOneWidget);
  });

  testWidgets('failure auto-expands once and shows the error body; user can re-collapse',
      (tester) async {
    final failed = _call('edit_gizmo', extra: {'arguments': '{"gizmoId":"gz_1"}'})
      ..children.add(_result('GRAPH_CYCLE: sync reaches itself', error: true));
    await tester.pumpWidget(_host(ChatToolCard(node: failed), reduced: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('GRAPH_CYCLE'), findsOneWidget); // auto-expanded 自动展开
    expect(find.textContaining('失败'), findsOneWidget);

    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    // AnExpandReveal keeps the subtree mounted while closed — assert the reveal is closed
    // instead of the text's absence. 收起后子树仍挂载,断言 reveal 关闭。
    final reveal = tester.widget<AnExpandReveal>(find.byType(AnExpandReveal).first);
    expect(reveal.open, isFalse);
  });

  testWidgets('success stays collapsed; tapping reveals intent/args/result sections',
      (tester) async {
    final ok = _call('summon_gizmo', extra: {
      'summary': 'Build the rollup',
      'arguments': '{"ops":[{"op":"set_meta"}]}',
    })
      ..children.add(_result('{"id":"fn_1","version":1}'));
    await tester.pumpWidget(_host(ChatToolCard(node: ok), reduced: true));
    await tester.pumpAndSettle();
    final reveal = tester.widget<AnExpandReveal>(find.byType(AnExpandReveal).first);
    expect(reveal.open, isFalse); // default collapsed 默认收起

    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    expect(find.text('意图'), findsOneWidget);
    expect(find.text('Build the rollup'), findsOneWidget);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    // Small JSON renders as airy pretty mono (no tree chrome). 小 JSON 走美化等宽、无树壳。
    expect(find.byType(AnJsonTree), findsNothing);
    expect(find.textContaining('"set_meta"'), findsOneWidget);
    expect(find.textContaining('"fn_1"'), findsOneWidget);
  });

  testWidgets('big JSON result gets the virtualized tree inside a bounded viewport',
      (tester) async {
    final entries = [for (var i = 0; i < 40; i++) '"k$i":{"v":$i}'].join(',');
    // An UNCATALOGED tool (MCP-style) → the generic body (get_workflow now has its own F06 exhibit).
    // 未编目工具 → 通用体(get_workflow 已有自己的 F06 陈列体)。
    final big = _call('mcp:acme/analyze', extra: {'arguments': '{}'})
      ..children.add(_result('{$entries}'));
    await tester.pumpWidget(_host(ChatToolCard(node: big), reduced: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    expect(find.byType(AnJsonTree), findsOneWidget); // >14 行 → 虚拟树
  });

  testWidgets('elapsed counter: hidden before 3s, ticking after; absent under reduced motion',
      (tester) async {
    final running = _call('run_function');
    await tester.pumpWidget(_host(ChatToolCard(node: running)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('秒'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('秒'), findsOneWidget);
    // Kill the ticker before teardown (running card ticks by design). 收尾前停表。
    await tester.pumpWidget(const SizedBox.shrink());

    final running2 = _call('run_function');
    await tester.pumpWidget(_host(ChatToolCard(node: running2), reduced: true));
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('秒'), findsNothing); // reduced: no ticker, battery-safe 降级无表
    await tester.pumpAndSettle(); // must settle instantly 必须立即安定
  });

  testWidgets('oversized prose result is excerpted with the honest truncation note',
      (tester) async {
    // An UNCATALOGED tool → the generic body's prose excerpt (read_document now parses its template).
    // 未编目工具 → 通用体散文摘录(read_document 已解析自己的模板)。
    final big = _call('mcp:acme/fetch')..children.add(_result('长' * 9000));
    await tester.pumpWidget(_host(ChatToolCard(node: big), reduced: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('已截断'), findsOneWidget);
    expect(find.textContaining('9000'), findsOneWidget);
  });

  testWidgets('an absurd mcp__ name + unparseable args routes to the MCP skin and still renders',
      (tester) async {
    // B4 F01.5: an mcp__ name now routes to the MCP skin (not the generic fallback). mcp__ 路由 MCP 皮。
    final weird = _call('mcp__x__y____z!!', extra: {'arguments': '{"broken": tru'})
      ..children.add(_result('not json at all'));
    await tester.pumpWidget(_host(ChatToolCard(node: weird), reduced: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('MCP'), findsOneWidget); // the MCP verb / chip, not a crash
    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('not json at all'), findsOneWidget); // raw mono body 原始等宽体
  });

  testWidgets('a genuinely un-cataloged name (no mount pattern) falls to the generic body', (tester) async {
    final weird = _call('frobnicate!!', extra: {'arguments': '{"broken": tru'})
      ..children.add(_result('not json at all'));
    await tester.pumpWidget(_host(ChatToolCard(node: weird), reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('frobnicate!!'), findsOneWidget); // generic target = the tool name
    await tester.tap(find.byType(AnInteractive).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('not json at all'), findsOneWidget);
  });
}
