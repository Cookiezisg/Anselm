import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// D-002 — the demo must seed a LIVE ask_user gate (not just the settled ask card): a streaming assistant
// turn carrying a closed ask_user tool_call + an unresolved kind=ask interaction (message + option pills
// + the implicit free-text answer). Opening cv_ask shows the amber ask gate awaiting an answer. 活问闸。
void main() {
  final repo = demoChatRepository();

  test(
    'cv_ask seeds an unresolved ask interaction with a prompt + options',
    () async {
      final pending = await repo.listInteractions('cv_ask');
      expect(pending, isNotEmpty, reason: '有待决 interaction');
      final ask = pending.firstWhere((i) => i.kind == InteractionKind.ask);
      expect(ask.resolved, isFalse, reason: '未决→琥珀活态');
      expect(ask.tool, 'ask_user');
      expect(ask.message, isNotNull);
      expect(ask.options, isNotEmpty, reason: '选项药丸');
    },
  );

  test(
    'the ask gate rides a streaming turn (closed tool_call, no tool_result yet)',
    () async {
      final msgs = (await repo.listMessages('cv_ask')).items;
      final streaming = msgs.firstWhere(
        (m) => m.role == 'assistant' && m.status == 'streaming',
      );
      final gate = streaming.blocks.firstWhere(
        (b) => b.attrs?['tool'] == 'ask_user',
      );
      expect(gate.type, 'tool_call');
      // No tool_result block nested under it → still awaiting the human. 无 result 子块→仍等人答。
      expect(
        msgs.expand((m) => m.blocks).any((b) => b.parentBlockId == gate.id),
        isFalse,
      );
    },
  );
}
