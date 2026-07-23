import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/settings/app_prefs_providers.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/state/stage_director_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The director HOST (WRK-061 W1): frame feed → pure machine, deadline timer, gate flag threading,
// user passthroughs. The machine's own choreography is unit-tested in stage_director_test — here we
// prove the wiring: frames drive it, the timer advances it, equality suppresses no-op broadcasts.
// 宿主接线电池:帧驱动/闹钟推进/人闸旗/用户直通;编排细节在纯状态机测试,此处证接线。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

StreamEnvelope _open(String id, String tool) => StreamEnvelope(
  seq: 1,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    node: StreamNode(type: 'tool_call', content: {'name': tool}),
  ),
);
StreamEnvelope _delta(String id) => StreamEnvelope(
  seq: 0,
  scope: _scope,
  id: id,
  frame: const FrameDelta(chunk: '{"x":'),
);
StreamEnvelope _close(String id, {String status = 'completed'}) =>
    StreamEnvelope(
      seq: 2,
      scope: _scope,
      id: id,
      frame: FrameClose(status: status),
    );
StreamEnvelope _callClose(
  String id, {
  String status = 'completed',
  String arguments = '{}',
}) => StreamEnvelope(
  seq: 2,
  scope: _scope,
  id: id,
  frame: FrameClose(
    status: status,
    result: StreamNode(type: 'tool_call', content: {'arguments': arguments}),
  ),
);
StreamEnvelope _resultOpen(String id, String parent) => StreamEnvelope(
  seq: 3,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    parentId: parent,
    node: const StreamNode(type: 'tool_result', content: {'content': ''}),
  ),
);
StreamEnvelope _resultClose(String id, {String status = 'completed'}) =>
    StreamEnvelope(
      seq: 4,
      scope: _scope,
      id: id,
      frame: FrameClose(
        status: status,
        result: const StreamNode(
          type: 'tool_result',
          content: {'content': 'ok'},
        ),
      ),
    );

void main() {
  testWidgets('a stage-worthy open stages after the debounce timer fires', (
    tester,
  ) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_function'));
    await tester.pump();
    expect(
      c.read(stageDirectorProvider(_conv)).stageOpen,
      isFalse,
    ); // debouncing 防抖中
    await tester.pump(const Duration(milliseconds: 600));
    final s = c.read(stageDirectorProvider(_conv));
    expect(s.stageOpen, isTrue);
    expect(s.subject!.kind, 'function');
  });

  testWidgets(
    'C-020 a content delta does NOT re-publish the stage state (no re-allocation)',
    (tester) async {
      final repo = FixtureChatRepository();
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(stageDirectorProvider(_conv), (_, _) {});
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      final before = c.read(stageDirectorProvider(_conv));
      expect(before.stageOpen, isTrue);
      // A streaming content delta bumps only unread/lastActivity (never the published view), so the
      // provider's state instance stays IDENTICAL — no per-delta StageState re-allocation. 内容 delta 不换 state。
      repo.emitFrame(_conv, _delta('b1'));
      await tester.pump();
      expect(
        identical(c.read(stageDirectorProvider(_conv)), before),
        isTrue,
        reason: 'delta 不重造/不通知,state 实例不变',
      );
    },
  );

  testWidgets(
    'a short op (open+close inside the window) never stages; curtain returns to idle',
    (tester) async {
      final repo = FixtureChatRepository();
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(stageDirectorProvider(_conv), (_, _) {});
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'edit_document'));
      await tester.pump();
      repo.emitFrame(_conv, _callClose('b1'));
      repo.emitFrame(_conv, _resultOpen('r1', 'b1'));
      repo.emitFrame(_conv, _resultClose('r1'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(c.read(stageDirectorProvider(_conv)).stageOpen, isFalse);

      // A real one: open → stage → close → breath → curtain → idle. 真场:登台→关→停拍→谢幕。
      repo.emitFrame(_conv, _open('b2', 'create_workflow'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.read(stageDirectorProvider(_conv)).stageOpen, isTrue);
      repo.emitFrame(_conv, _callClose('b2'));
      expect(
        c.read(stageDirectorProvider(_conv)).stageOpen,
        isTrue,
        reason:
            'the model finished arguments, but the real tool execution is still live',
      );
      repo.emitFrame(_conv, _resultOpen('r2', 'b2'));
      repo.emitFrame(_conv, _resultClose('r2'));
      await tester.pump();
      expect(
        c.read(stageDirectorProvider(_conv)).phase,
        StagePhase.following,
      ); // breath 停拍
      await tester.pump(const Duration(milliseconds: 2000));
      expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.idle);
    },
  );

  testWidgets(
    'deltas on the SUBJECT do not broadcast (value equality); channel deltas badge unread',
    (tester) async {
      final repo = FixtureChatRepository();
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      var notifications = 0;
      c.listen(stageDirectorProvider(_conv), (_, _) => notifications++);
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      final base = notifications;
      for (var i = 0; i < 20; i++) {
        repo.emitFrame(_conv, _delta('b1'));
      }
      await tester.pump();
      expect(notifications, base); // subject deltas are silent here 主角 delta 静默

      repo.emitFrame(_conv, _open('b2', 'create_document'));
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // in channels (debouncing) 频道中
      repo.emitFrame(_conv, _delta('b2'));
      repo.emitFrame(
        _conv,
        _delta('b1'),
      ); // subject stays hot → no switch 主角活跃不换台
      await tester.pump(const Duration(milliseconds: 600));
      final s = c.read(stageDirectorProvider(_conv));
      expect(s.phase, StagePhase.following); // G2: never frozen 永不冻结
      expect(s.subject!.blockId, 'b1'); // idle unmet → camera stays 未静默镜头不动
      expect(s.channels.single.unread, greaterThan(0)); // badge moved 未读徽动了
      // Drain the arbitration retry deadline (G2: it always keeps flowing — no phase clears it).
      // 排干仲裁重试闹钟(G2 流水线恒流动,无相位会清它)。
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('failed close → failed-hold; row-level clear → idle (G3)', (
    tester,
  ) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_agent'));
    await tester.pump(const Duration(milliseconds: 600));
    repo.emitFrame(_conv, _close('b1', status: 'error'));
    await tester.pump();
    expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.failedHold);
    c.read(stageDirectorProvider(_conv).notifier).clearActivity('b1');
    final s = c.read(stageDirectorProvider(_conv));
    expect(s.phase, StagePhase.idle);
    expect(s.channels, isEmpty); // truly gone, not a ghost 真离场,非幽灵
  });

  testWidgets(
    'G4: execution progress on nested children feeds the OWNING call (A1-17)',
    (tester) async {
      final repo = FixtureChatRepository();
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(stageDirectorProvider(_conv), (_, _) {});
      await tester.pump();
      repo.emitFrame(_conv, _open('b0', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600)); // b0 = subject
      repo.emitFrame(_conv, _open('b1', 'run_function'));
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // b1 = channel (build outranks execution, no switch)
      repo.emitFrame(_conv, _callClose('b1'));
      repo.emitFrame(_conv, _resultOpen('r1', 'b1'));
      await tester.pump();
      final before = c
          .read(stageDirectorProvider(_conv))
          .channels
          .firstWhere((a) => a.blockId == 'b1')
          .unread;

      // A progress child under the RESULT: its open + deltas must land on b1's activity clock —
      // the old per-id path no-opped them all. result 下的 progress 子块:开帧+delta 必须记到 b1。
      repo.emitFrame(
        _conv,
        StreamEnvelope(
          seq: 5,
          scope: _scope,
          id: 'p1',
          frame: const FrameOpen(
            parentId: 'r1',
            node: StreamNode(type: 'progress', content: {'text': ''}),
          ),
        ),
      );
      repo.emitFrame(_conv, _delta('p1'));
      repo.emitFrame(_conv, _delta('p1'));
      // Force a publish so the snapshot is fresh (deltas deliberately never publish). 借一次发布取新快照。
      repo.emitFrame(_conv, _open('bx', 'write_memory'));
      await tester.pump();
      final after = c
          .read(stageDirectorProvider(_conv))
          .channels
          .firstWhere((a) => a.blockId == 'b1')
          .unread;
      expect(after, before + 3); // open + 2 deltas, all owned 开帧+两 delta 全计入属主
      await tester.pump(const Duration(seconds: 4)); // drain deadlines 排干闹钟
    },
  );

  testWidgets('followMode never (from the notch) blocks auto-staging', (
    tester,
  ) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.read(followModeProvider.notifier).set(FollowMode.never);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_function'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(c.read(stageDirectorProvider(_conv)).stageOpen, isFalse);
  });
}
