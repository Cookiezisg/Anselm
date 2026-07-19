import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:anselm/features/chat/ui/tool_card_lifecycle.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F05 lifecycle (B3.6) — receipt parser group + «green but broken» reclassification + dynamic rename
// verb + delete audit (JSON + string forms). F05 回执群 + 结果内失败 + 动态改名 + 删除审计。

ToolCardState _s(String name, String result, {String args = '{}'}) => ToolCardState(
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

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('receipt parsers', () {
    test('revertReceipt: ↩ vN', () {
      expect(revertReceipt('{"id":"fn_1","version":3}', rewind: (v) => 'r$v')!.text, 'r3');
      expect(revertReceipt('{}', rewind: (v) => 'r$v'), isNull);
    });

    test('parseDependents JSON: count + refs; parseAgentDependents string: prefix-derived kinds', () {
      final j = parseDependents('{"dependentCount":2,"dependents":[{"kind":"agent","id":"ag_1"},{"kind":"workflow","id":"wf_2"}]}');
      expect(j!.count, 2);
      expect(j.refs.first.kind, 'agent');
      final s = parseAgentDependents('Referenced by: [wf_1 ctl_2 zz_9]');
      expect(s!.count, 3);
      expect(s.refs[0].kind, 'workflow'); // wf_ → workflow
      expect(s.refs[1].kind, 'control'); // ctl_ → control
      expect(s.refs[2].kind, '?'); // unknown prefix → inert
    });

    test('deleteReceipt: dependents → danger; none → neutral', () {
      final d = deleteReceipt('{"id":"fn_1","deleted":true,"dependentCount":3,"dependents":[{"kind":"agent","id":"ag_1"}]}',
          deleted: 'del', affected: (n) => 'aff$n');
      expect(d!.text, 'aff3');
      expect(d.tone, ToolReceiptTone.danger);
      final none = deleteReceipt('{"id":"fn_1","deleted":true}', deleted: 'del', affected: (n) => 'aff$n');
      expect(none!.tone, ToolReceiptTone.none);
    });

    test('killReceipt: N>0 danger, N==0 neutral', () {
      expect(killReceipt('{"killed":3}', killedN: (n) => 'k$n', none: 'z')!.tone, ToolReceiptTone.danger);
      expect(killReceipt('{"killed":0}', killedN: (n) => 'k$n', none: 'z')!.text, 'z');
    });

    test('restartReceipt: error key → danger + surfaces the actual error; runtimeState words', () {
      // The real error must surface (not a generic label) — the «green but broken» reason was invisible.
      final e = restartReceipt('{"error":"boom"}', label: (s) => s, errored: (err) => 'ERR: $err')!;
      expect(e.tone, ToolReceiptTone.danger);
      expect(e.text, contains('boom'));
      expect(restartReceipt('{"runtimeState":"running"}', label: (s) => s, errored: (err) => err)!.tone, ToolReceiptTone.none);
      expect(restartReceipt('{"runtimeState":"crashed"}', label: (s) => s, errored: (err) => err)!.tone, ToolReceiptTone.danger);
    });

    test('movedReceipt / deletedDocReceipt templates', () {
      expect(movedReceipt('Moved "x" to /a (new path: /a/x).', toPath: (p) => '>$p')!.text, '>/a/x');
      expect(deletedDocReceipt('Deleted document doc_1 along with 4 descendant(s).', deleted: 'd', withDescendants: (n) => 'w$n')!.text, 'w4');
    });
  });

  test('restart_handler resultFailed: the error key flips a completed result to failed', () {
    final spec = toolCardSpecFor('restart_handler');
    expect(spec.resultFailed!(_s('restart_handler', '{"id":"hd_1","runtimeState":"crashed","error":"boom"}')), isTrue);
    expect(spec.resultFailed!(_s('restart_handler', '{"id":"hd_1","runtimeState":"running"}')), isFalse);
  });

  test('update_meta dynamic verb: rename when ONLY name; update-info otherwise', () {
    final spec = toolCardSpecFor('update_function_meta');
    final rename = _s('update_function_meta', '{"id":"fn_1","name":"x"}', args: '{"functionId":"fn_1","name":"x"}');
    expect(spec.verbOf!(t, rename, live: false), t.chat.tool.renamed);
    final full = _s('update_function_meta', '{"id":"fn_1"}', args: '{"functionId":"fn_1","name":"x","tags":["a"]}');
    expect(spec.verbOf!(t, full, live: false), t.chat.tool.updatedMeta);
  });

  testWidgets('delete tombstone chip is plain mono (NOT a tappable pill)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('delete_function', '{"functionId":"fn_1"}', '{"id":"fn_1","deleted":true}'))));
    await tester.pump();
    // The collapsed row shows the id as a plain target chip; there is no ref pill in the row. 墓碑纯 mono。
    expect(find.text('fn_1'), findsOneWidget);
  });

  testWidgets('delete audit: N refs affected (danger) + jump-to-fix pills, auto-expanded', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('delete_function', '{"functionId":"fn_1"}',
        '{"id":"fn_1","deleted":true,"dependentCount":2,"dependents":[{"kind":"agent","id":"ag_1"},{"kind":"workflow","id":"wf_2"}]}'))));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDependentsBlock), findsOneWidget); // auto-expanded (danger)
    expect(find.text(t.chat.tool.depsAffected(n: '2')), findsOneWidget);
    expect(find.text('ag_1'), findsOneWidget); // jump-to-fix pill
  });
}
