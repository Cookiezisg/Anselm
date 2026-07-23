import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/model/partial_json.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_control_approval.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F04 control decision ladder + approval form preview — both whole-set replaces, rendered from args.
// control 决策梯 + approval 表单预览。

const _ctlArgs =
    '{"name":"spend-gate","branches":['
    '{"op":"noop","port":"hot","when":"input.amount > 1000","emit":{"tier":"high"}},'
    '{"port":"warm","when":"input.amount > 100"},'
    '{"port":"cold","when":"true"}]}';

const _apfArgs =
    '{"name":"spend-approval",'
    r'"template":"# 采购审批\n金额 {{ input.amount }},供应商 {{ input.vendor }},是否放行?",'
    '"allowReason":true,"timeout":"30d","timeoutBehavior":"reject"}';

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
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

  test('controlBranches parses port / when / emit (whole set)', () {
    final b = controlBranches(PartialJsonSession()..append(_ctlArgs));
    expect(b.length, 3);
    expect(b[0].port, 'hot');
    expect(b[0].when, 'input.amount > 1000');
    expect(b[0].emit, {'tier': 'high'});
    expect(b[2].when, 'true'); // the catch-all
  });

  test(
    'approvalTemplateToMarkdown turns {{ input.x }} into an inline-code chip',
    () {
      expect(
        approvalTemplateToMarkdown('金额 {{ input.amount }} 元'),
        '金额 `amount` 元',
      );
      // {{ payload.x }} is server-rejected, so only input.* appears; a non-input moustache is left as-is.
      expect(approvalTemplateToMarkdown('{{ input.a.b }}'), '`a.b`');
    },
  );

  testWidgets(
    'control body: the decision ladder (ordered rows + catch-all + emit)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'create_control',
              _ctlArgs,
              '{"id":"ctl_1","activeVersionId":"ctlv_1","version":1}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已创建控制'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Ordered rows: the numbers 1/2/3 = first-true-wins priority. 有序序号。
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Port badges + a when CEL + emit key ← CEL. port 徽 + CEL + emit。
      expect(find.widgetWithText(AnChip, 'hot'), findsOneWidget);
      expect(find.text('input.amount > 1000'), findsOneWidget);
      expect(find.textContaining('tier ← high'), findsOneWidget);
      // The catch-all (when:"true") reads 否则, not a raw CEL. 兜底显否则。
      expect(find.textContaining('否则'), findsOneWidget);
    },
  );

  testWidgets(
    'approval body: the form preview (rendered template + rules + mock decision)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'create_approval',
              _apfArgs,
              '{"id":"apf_1","activeVersionId":"apfv_1","version":1}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已创建审批'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // The rendered template (a heading from the markdown). 渲染模板。
      expect(find.textContaining('采购审批'), findsOneWidget);
      // The rules strip: timeout badge + behaviour + note-allowed. 规则条。
      expect(find.widgetWithText(AnChip, '30d'), findsOneWidget);
      // The humane sentence, not the raw enum (G10/A3-20). 人话而非裸枚举。
      expect(find.text(t.chat.stage.timeoutReject(d: '30d')), findsOneWidget);
      // Mock decision buttons (disabled preview). mock 决策钮(禁用预览)。
      expect(find.widgetWithText(AnButton, '批准'), findsOneWidget);
      expect(find.widgetWithText(AnButton, '拒绝'), findsOneWidget);
    },
  );

  testWidgets('approval with no timeout says never-times-out', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_approval',
            '{"name":"a","template":"# x"}',
            '{"id":"apf_1","activeVersionId":"apfv_1","version":1}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建审批'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('永不超时'), findsOneWidget);
  });
}
