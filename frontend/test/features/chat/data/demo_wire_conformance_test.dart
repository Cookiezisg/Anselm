import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// G8 guard — the demo fixture must speak the REAL wire (A3-6): every tool_call CLOSE snapshot's
// content keys must be a subset of the backend snapshot key set (loop/stream.go toolCallContent:
// name/arguments/summary/danger/entityName). The fixture once invented description/tokens/
// stopReason keys, which made the demo look perfect while real backends rendered blank labels and
// empty settles — a lying fixture is the most expensive kind of green.
// G8 守卫:demo 帧形=真线缆——tool_call 关帧快照键集 ⊆ 后端快照键集。fixture 曾自造
// description/tokens/stopReason,demo 全绿、真机全灰;撒谎的 fixture 是最贵的绿。

void main() {
  testWidgets('demo tool_call close snapshots use ONLY real wire keys', (
    tester,
  ) async {
    const conv = 'cv_wire';
    final repo = DemoChatRepository(
      conversations: [
        Conversation(
          id: conv,
          title: 'wire',
          createdAt: DateTime.utc(2026, 7, 8),
          updatedAt: DateTime.utc(2026, 7, 8),
          lastMessageAt: DateTime.utc(2026, 7, 8),
        ),
      ],
    );
    final frames = <StreamEnvelope>[];
    final sub = repo.conversationFrames(conv).listen(frames.add);
    addTearDown(sub.cancel);
    await repo.sendMessage(conv, content: '演一遍全剧本');
    // Drain the whole scripted playback on the fake clock, then cancel any stragglers so the
    // binding's pending-timer invariant stays clean. 假钟排空全剧本,再取消零星尾闹钟。
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await repo.cancelTurn(conv);
    await tester.pump();

    const allowed = {'name', 'arguments', 'summary', 'danger', 'entityName'};
    var checked = 0;
    for (final env in frames) {
      final f = env.frame;
      if (f is FrameClose && f.result?.type == 'tool_call') {
        final keys = (f.result!.content ?? const {}).keys.toSet();
        expect(
          keys.difference(allowed),
          isEmpty,
          reason: '${env.id} 的关帧快照带发明键:$keys(后端快照键集=$allowed)',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(3), reason: '剧本应至少检查到数个 tool_call 关帧');
  });
}
