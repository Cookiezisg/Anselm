import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-061 W0 stream-pressure regression: the 1MB gate run found the real crash — argString's
// backtracking regex capture STACK-OVERFLOWED the Dart regex engine on an MB-scale value (profile
// ErrorWidget = the grey wall), fired every frame because a collapsed settled body is still
// CONSTRUCTED per rebuild. These pin the hand-rolled scanner + the MB-scale streaming card.
// W0 流式压力回归:1MB 门禁真机抓到的崩点——argString 回溯正则在 MB 级值上爆栈(且 settled 体在
// 收起时每帧仍被构造)。钉手写扫描器 + MB 级流中卡。

const _scope = StreamScope(kind: 'conversation', id: 'cv');

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test(
    'argString survives an MB-scale UNCLOSED value (null, no stack overflow)',
    () {
      final frag = '{"name":"war-and-peace.md","content":"${'x' * 1024 * 1024}';
      expect(
        argString(frag, 'content'),
        isNull,
      ); // unclosed → partial's business 未闭合归 partial
      expect(argString(frag, 'name'), 'war-and-peace.md');
      expect(argStringPartial(frag, 'content')!.length, 1024 * 1024);
    },
  );

  test(
    'argString survives an MB-scale CLOSED value (full decode, no stack overflow)',
    () {
      final v = '${'line\\n' * 200000}end'; // ~1.2MB with escapes 带转义
      final frag = '{"content":"$v"}';
      final out = argString(frag, 'content')!;
      expect(
        out.length,
        200000 * 5 + 3,
      ); // \n decoded to 1 char per line 每行转义解码为 1 字符
      expect(out.endsWith('end'), isTrue);
      expect(out.startsWith('line\n'), isTrue);
    },
  );

  test(
    'argString skips a non-value "key" occurrence and honest whitespace',
    () {
      expect(
        argString(
          '{"note":"the \\"content\\" word","content" : "real"}',
          'content',
        ),
        'real',
      );
      expect(
        argString('{"content":42}', 'content'),
        isNull,
      ); // non-string value 非字符串
    },
  );

  testWidgets(
    'a create_document card streaming ~800KB renders live without exceptions',
    (tester) async {
      final r = BlockTreeReducer()
        ..apply(
          const StreamEnvelope(
            seq: 1,
            scope: _scope,
            id: 'tc',
            frame: FrameOpen(
              node: StreamNode(
                type: 'tool_call',
                content: {'name': 'create_document'},
              ),
            ),
          ),
        )
        ..apply(
          const StreamEnvelope(
            seq: 0,
            scope: _scope,
            id: 'tc',
            frame: FrameDelta(chunk: '{"name":"war-and-peace.md","content":"'),
          ),
        );
      final node = r.nodeById('tc')!;
      final line = '${'x' * 61}\\n';
      final chunk = line * 64; // ~4KB
      Widget host() => TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 900, child: ChatToolCard(node: node)),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host());
      for (var i = 0; i < 200; i++) {
        r.apply(
          StreamEnvelope(
            seq: 0,
            scope: _scope,
            id: 'tc',
            frame: FrameDelta(chunk: chunk),
          ),
        );
        await tester.pumpWidget(host());
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // The live window shows the TAIL, bounded — never a page-swallowing wall. 活窗有界示尾,绝不吞页。
      expect(tester.getSize(find.byType(ChatToolCard)).height, lessThan(400));
    },
  );
}
