import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/model/partial_json.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
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
    node.children.add(
      BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result},
    );
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
          child: SizedBox(width: 560, child: Center(child: child)),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('argStringPartial: closed value, open value, absent key', () {
    expect(argStringPartial('{"code":"done"}', 'code'), 'done');
    expect(
      argStringPartial('{"code":"def f():\\n    ret', 'code'),
      'def f():\n    ret',
    );
    expect(argStringPartial('{"other":"x"}', 'code'), isNull);
  });

  // WRK-083 L9 — a create card must name the ENTITY, not whatever key called itself `name` last.
  //
  // Real machine (R05 极值电池): the agent built a function named `echo_unicode` whose OUTPUT fields
  // included one called `codepoints`. The card announced «Created function codepoints». The notice and
  // the sidestage both said `echo_unicode`, and the entity really is `echo_unicode` — only the
  // transcript lied, and it lied about the one thing a reader scrolls back for.
  //
  // The cause is a lookup, not a typo: `liveStringNamed` matches the LAST path segment at ANY depth and
  // scans events BACKWARDS, which is exactly right for its documented job (follow the `code`/`body`
  // that is growing right now, wherever it nests) and exactly wrong for an identity. In an ops payload
  // `ops[0].name` (set_meta = the entity name) is followed by `ops[2].outputs[*].name`, so the last one
  // wins. Any ops-shaped build tool whose inputs/outputs are named is affected — this is not specific to
  // Unicode or to functions.
  //
  // WRK-083 L9——创建卡必须点出**实体**的名字,而不是最后一个自称 `name` 的键。
  //
  // 真机(R05 极值电池):agent 建了个叫 `echo_unicode` 的函数,它的**输出字段**里有一个叫 `codepoints`。
  // 卡片宣布「Created function codepoints」。顶带通知与右岛都说 `echo_unicode`,实体本身也确实是
  // `echo_unicode`——只有转录在撒谎,而且撒的正是读者回头去看的那件事。
  //
  // 病因是**取法**、不是笔误:`liveStringNamed` 匹配任意深度的**末段**键名且**从后往前**扫,这对它被文档化的
  // 职责(跟住此刻正在生长的 code/body,不论嵌多深)完全正确,对**身份**完全错误。ops 形状里 `ops[0].name`
  // (set_meta=实体名)后面还跟着 `ops[2].outputs[*].name`,于是最后一个赢。凡 ops 形状、且输入/输出带名字的
  // 构建工具都中招——与 Unicode 无关、与函数也无关。
  test('a create card names the entity, not a nested output field (L9)', () {
    // The exact args from the real-machine incident, trimmed to the shape that matters.
    // 真机那次的原样参数(裁到要紧的形状)。
    const args =
        '{"ops":['
        '{"op":"set_meta","name":"echo_unicode","description":"echo"},'
        '{"op":"set_inputs","inputs":[{"name":"text","type":"string"}]},'
        '{"op":"set_outputs","outputs":['
        '{"name":"result","type":"string"},'
        '{"name":"length","type":"number"},'
        '{"name":"codepoints","type":"string"}]},'
        '{"op":"set_code","code":"def run(text):\\n    return {}"}]}';

    final state = ToolCardState.of(_call('create_function', args: args));
    expect(
      toolCardSpecFor('create_function').target?.call(state),
      'echo_unicode',
      reason:
          'the card must name the created entity (ops set_meta.name), not the last nested '
          '`name` key in the payload (WRK-083 L9)',
    );

    // The flat shape (tools that take a top-level name) must keep working. 扁平形状照旧。
    final flat = ToolCardState.of(
      _call('create_document', args: '{"name":"口径","content":"# t"}'),
    );
    expect(toolCardSpecFor('create_document').target?.call(flat), '口径');

    // The whole IDENTITY class, not just the build family: any tool whose payload can nest a `name`
    // must still name its own subject. `install_mcp_server` takes `env` as a free-key map, so an env
    // var literally called `name` used to win over the server name.
    // 整**类**身份、不止构建族:凡 payload 可能嵌 `name` 的工具都必须仍点出自己的主体。
    // `install_mcp_server` 的 `env` 是自由键 map,一个字面叫 `name` 的环境变量原本会盖过服务器名。
    final mcp = ToolCardState.of(
      _call(
        'install_mcp_server',
        args:
            '{"name":"io.github.up/context7","env":{"name":"NOT-THE-SERVER"}}',
      ),
    );
    expect(
      toolCardSpecFor('install_mcp_server').target?.call(mcp),
      'io.github.up/context7',
    );

    // Liveness is preserved: a name still TYPING shows through, from its own path.
    // 活性未丢:仍在打字的名字照样透出,且来自它自己的路径。
    final typing = ToolCardState.of(
      _call('create_document', args: '{"name":"半个名'),
    );
    expect(toolCardSpecFor('create_document').target?.call(typing), '半个名');
  });

  test('buildContentOf routes per entity kind', () {
    expect(
      buildContentOf(
        'create_function',
        PartialJsonSession()
          ..append('{"ops":[{"op":"set_code","code":"x = 1"}]}'),
      ),
      'x = 1',
    );
    expect(
      buildContentOf(
        'edit_agent',
        PartialJsonSession()..append('{"agentId":"ag_1","prompt":"be sharp"}'),
      ),
      'be sharp',
    );
    expect(
      buildContentOf(
        'create_document',
        PartialJsonSession()..append('{"name":"n","content":"# t"}'),
      ),
      '# t',
    );
    expect(
      buildContentOf(
        'create_workflow',
        PartialJsonSession()..append('{"graph":{}}'),
      ),
      isNull,
    ); // JSON fallback 配置走 JSON
  });

  testWidgets(
    'mid-stream: collapsed by default; TAP opens the live code window (WRK-065)',
    (tester) async {
      const scope = StreamScope(kind: 'conversation', id: 'cv_1');
      final r = BlockTreeReducer()
        ..apply(
          const StreamEnvelope(
            seq: 1,
            scope: scope,
            id: 'tc_b',
            frame: FrameOpen(
              node: StreamNode(
                type: 'tool_call',
                content: {'name': 'create_function'},
              ),
            ),
          ),
        )
        ..apply(
          const StreamEnvelope(
            seq: 0,
            scope: scope,
            id: 'tc_b',
            frame: FrameDelta(
              chunk:
                  '{"ops":[{"op":"set_meta","name":"rollup"},{"op":"set_code","code":"import json\\ndef rol',
            ),
          ),
        );
      await tester.pumpWidget(_host(ChatToolCard(node: r.roots.single)));
      await tester.pumpAndSettle();
      expect(find.textContaining('正在创建函数'), findsOneWidget);
      expect(
        find.text('rollup'),
        findsOneWidget,
      ); // streaming name target 流中名字目标
      // Default collapsed — no auto machine window while running (WRK-065 user decree). 默认收起,不自动弹窗。
      expect(find.byType(AnCodeEditor), findsNothing);
      // TAP → the body's live face: the editor's live face (批2 一壳两脸). 点开=编辑器 live 脸。
      await tester.tap(find.textContaining('正在创建函数'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final editor = tester.widget<AnCodeEditor>(find.byType(AnCodeEditor));
      expect(editor.live, isTrue); // live face, same shell 活脸同壳
      expect(
        find.textContaining('def rol'),
        findsOneWidget,
      ); // still-open value streams 未闭合值在流
    },
  );

  testWidgets('settled: highlighted editor + result bar id·vN·env ready', (
    tester,
  ) async {
    final ok = _call(
      'create_function',
      args:
          '{"ops":[{"op":"set_meta","name":"rollup"},{"op":"set_code","code":"x = 1\\n"}]}',
      result:
          '{"id":"fn_1","versionId":"fnv_1","version":1,"envStatus":"ready","opsApplied":2}',
    );
    await tester.pumpWidget(
      _host(ChatToolCard(node: ok, key: const ValueKey('ok'))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('已创建函数'), findsOneWidget);
    expect(find.textContaining('v1'), findsOneWidget); // receipt 回执
    await tester.tap(find.textContaining('已创建函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      find.byType(AnCodeEditor),
      findsOneWidget,
    ); // settled → highlighted 落定高亮
    // Result bar: a provenance RefPill (label = the function name, id = fn_1 as its tap target) + env.
    // 结果条:凭据 RefPill(label=函数名、id=fn_1 作点击目标)+ env。
    expect(find.byType(AnRefPill), findsOneWidget);
    expect(find.textContaining('env 就绪', findRichText: true), findsWidgets);
  });

  testWidgets('env failed: danger receipt + auto-expanded + red envError', (
    tester,
  ) async {
    final bad = _call(
      'create_function',
      args: '{"ops":[{"op":"set_code","code":"x = 1"}]}',
      result:
          '{"id":"fn_1","version":1,"envStatus":"failed","envError":"pip install nope==9: not found"}',
    );
    await tester.pumpWidget(
      _host(ChatToolCard(node: bad, key: const ValueKey('bad'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('env 失败'),
      findsWidgets,
    ); // receipt (danger) 危险色回执
    expect(
      find.textContaining('pip install nope'),
      findsOneWidget,
    ); // auto-expanded 自动展开
  });

  testWidgets(
    'edit: kind verb + id target; prose-output create has no result bar',
    (tester) async {
      final edit = _call(
        'edit_agent',
        args: '{"agentId":"ag_1","prompt":"be sharp"}',
        result: '{"id":"ag_1","versionId":"agv_2","version":3}',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: edit, key: const ValueKey('e'))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('已更新智能体'), findsOneWidget);
      expect(
        find.text('ag_1'),
        findsOneWidget,
      ); // collapsed-row edit target chip (result bar is in the body)
      expect(find.textContaining('v3'), findsOneWidget);

      final doc = _call(
        'create_document',
        args: '{"name":"口径","content":"# t"}',
        result: 'Created document "口径" (id=doc_1, path=/口径)',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: doc, key: const ValueKey('d'))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('已创建文档'), findsOneWidget);
      expect(find.text('口径'), findsOneWidget); // name target 名字目标
    },
  );

  testWidgets(
    'env self-heal: envFixAttempts renders the EnvFixTimeline (fail then ok)',
    (tester) async {
      final n = _call(
        'create_function',
        args: '{"ops":[{"op":"set_code","code":"x=1\\n"}]}',
        result:
            '{"id":"fn_1","version":2,"envStatus":"ready","opsApplied":1,"envFixAttempts":[{"attempt":1,"deps":["pandas==9.9.9"],"ok":false,"error":"No matching distribution"},{"attempt":2,"deps":["pandas"],"ok":true}]}',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: n, key: const ValueKey('heal'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('已创建函数'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('环境自愈'),
        findsOneWidget,
      ); // the timeline header
      expect(find.textContaining('尝试 1'), findsOneWidget);
      expect(find.textContaining('尝试 2'), findsOneWidget);
      expect(
        find.textContaining('No matching distribution'),
        findsOneWidget,
      ); // attempt 1 error
    },
  );

  testWidgets(
    'edit_handler crashed: danger receipt auto-expands + red runtimeWarning',
    (tester) async {
      final n = _call(
        'edit_handler',
        args:
            '{"handlerId":"hd_1","ops":[{"op":"add_method","method":{"name":"m","body":"raise"}}]}',
        result:
            '{"id":"hd_1","version":5,"envStatus":"ready","opsApplied":1,"runtimeState":"crashed","runtimeWarning":"the resident instance is not running after this edit — revert_handler to the last good version"}',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: n, key: const ValueKey('crash'))),
      );
      await tester.pumpAndSettle();
      // crashed → danger receipt → auto-expanded (no tap needed). crashed=危险回执→自动展开。
      expect(
        find.textContaining('实例已崩溃'),
        findsWidgets,
      ); // receipt + body badge
      expect(
        find.textContaining('revert_handler to the last good'),
        findsOneWidget,
      ); // red warning line
    },
  );

  testWidgets(
    'edit_handler stopped: benign muted badge, NO warning line, NOT auto-expanded',
    (tester) async {
      final n = _call(
        'edit_handler',
        args: '{"handlerId":"hd_1","ops":[{"op":"set_meta","name":"renamed"}]}',
        result:
            '{"id":"hd_1","version":3,"envStatus":"ready","opsApplied":1,"runtimeState":"stopped",'
            '"runtimeWarning":"the resident instance is not running after this edit — may need config"}',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: n, key: const ValueKey('stop'))),
      );
      await tester.pumpAndSettle();
      // stopped is benign → NOT auto-expanded (collapsed), so no warning line shows. 良性→不自动展开。
      expect(
        find.textContaining('may need config'),
        findsNothing,
      ); // warning suppressed for stopped
      // Expand → the stopped badge shows, still no red warning line (census correction). 展开→静音徽、仍无红警。
      await tester.tap(find.textContaining('已更新处理器'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('实例未运行'), findsWidgets); // muted badge
      expect(
        find.textContaining('may need config'),
        findsNothing,
      ); // still no warning (benign)
    },
  );

  testWidgets(
    'RunStatBar dual-key id: falls back to <entity>Id when there is no top-level id',
    (tester) async {
      // A result carrying only `functionId` (no `id`) still yields a provenance pill. 只有 functionId 也出 pill。
      final n = _call(
        'edit_function',
        args:
            '{"functionId":"fn_9","ops":[{"op":"set_code","code":"y = 2\\n"}]}',
        result: '{"functionId":"fn_9","version":4}',
      );
      await tester.pumpWidget(
        _host(ChatToolCard(node: n, key: const ValueKey('dk'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('已更新函数'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(AnRefPill),
        findsOneWidget,
      ); // pill from the fallback id 兜底 id 出 pill
      expect(find.textContaining('v4'), findsWidgets);
    },
  );
}
