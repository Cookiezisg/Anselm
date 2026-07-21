import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_ref_pill.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_trigger.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F04 create/edit_trigger — the TriggerConfigCard four faces (cron/webhook/fsnotify/sensor) + the
// listening receipt (create=未监听, edit=热更新). trigger 四 kind 配置脸 + 监听回执。

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

ToolCardState _state(String name, String args, String result) => ToolCardState(
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

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('triggerReceipt: create → 未监听 (none); edit on live → 热更新 (warn)', () {
    final create = triggerReceipt(
      t,
      _state('create_trigger', '{}', '{"id":"trg_1","listening":false}'),
    );
    expect(create!.text, t.chat.tool.trgNotListening);
    expect(create.tone, ToolReceiptTone.none);
    final edit = triggerReceipt(
      t,
      _state('edit_trigger', '{}', '{"id":"trg_1","listening":true}'),
    );
    expect(edit!.text, t.chat.tool.trgHotUpdate);
    expect(edit.tone, ToolReceiptTone.warn);
    // Unparseable result → no receipt (degrade, never throw). 无法解析→无回执。
    expect(triggerReceipt(t, _state('create_trigger', '{}', 'boom')), isNull);
  });

  testWidgets('cron face: expression prominent + create-not-listening note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_trigger',
            '{"name":"每日收盘","kind":"cron","config":{"expression":"0 30 17 * * MON-FRI"}}',
            '{"id":"trg_1","version":1,"listening":false}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建触发器'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('0 30 17 * * MON-FRI'), findsOneWidget);
    expect(find.textContaining('active workflow'), findsOneWidget); // 未监听注记
  });

  testWidgets(
    'webhook face: copyable URL + secret lock chip (value never shown)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'create_trigger',
              '{"name":"入站","kind":"webhook","config":{"path":"invoice","secret":"whsec_SUPER","signatureAlgo":"hmac-sha256"}}',
              '{"id":"trg_9","version":1,"listening":false}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已创建触发器'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // The full URL is copyable, id woven in from the result. 完整 URL 可复制。
      expect(
        find.byWidgetPredicate((w) => w is AnChip && w.copyValue != null),
        findsOneWidget,
      ); // the URL copy chip URL 复制芯片
      expect(find.text('POST /api/v1/webhooks/trg_9/invoice'), findsOneWidget);
      // The secret VALUE is never rendered — only the 🔒 marker. 密钥值绝不显。
      expect(find.textContaining('whsec_SUPER'), findsNothing);
      expect(find.textContaining(t.chat.tool.trgSecret), findsOneWidget);
    },
  );

  testWidgets('fsnotify face: path + event chips + glob', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_trigger',
            '{"name":"落盘","kind":"fsnotify","config":{"path":"/inbox","events":["create","write"],"pattern":"*.pdf"}}',
            '{"id":"trg_2","version":1,"listening":false}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建触发器'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('/inbox'), findsOneWidget);
    expect(find.textContaining('create'), findsWidgets);
    expect(find.textContaining('*.pdf'), findsOneWidget);
  });

  testWidgets('sensor face: target ref pill + interval + CEL condition/output', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'edit_trigger',
            '{"triggerId":"trg_3","kind":"sensor","config":{"targetKind":"function","targetId":"fn_abc","method":"rollup","intervalSec":60,"condition":"result.total > 10000","output":"{x: 1}"}}',
            '{"id":"trg_3","version":4,"listening":true}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已更新触发器'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnRefPill), findsOneWidget); // the polled target
    expect(find.textContaining('rollup'), findsOneWidget);
    expect(
      find.textContaining('result.total > 10000'),
      findsOneWidget,
    ); // CEL condition
    expect(find.textContaining(t.chat.tool.trgEvery(n: '60')), findsOneWidget);
  });

  testWidgets('unknown kind degrades to a raw JSON window (never throws)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_trigger',
            '{"name":"x","kind":"quantum","config":{"foo":"bar"}}',
            '{"id":"trg_x","version":1,"listening":false}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建触发器'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('foo'), findsOneWidget);
  });
}
