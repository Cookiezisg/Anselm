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
    seq: 1, scope: _scope, id: id,
    frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': tool})));
StreamEnvelope _delta(String id) =>
    StreamEnvelope(seq: 0, scope: _scope, id: id, frame: const FrameDelta(chunk: '{"x":'));
StreamEnvelope _close(String id, {String status = 'completed'}) =>
    StreamEnvelope(seq: 2, scope: _scope, id: id, frame: FrameClose(status: status));

void main() {
  testWidgets('a stage-worthy open stages after the debounce timer fires', (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_function'));
    await tester.pump();
    expect(c.read(stageDirectorProvider(_conv)).stageOpen, isFalse); // debouncing 防抖中
    await tester.pump(const Duration(milliseconds: 600));
    final s = c.read(stageDirectorProvider(_conv));
    expect(s.stageOpen, isTrue);
    expect(s.subject!.kind, 'function');
  });

  testWidgets('C-020 a content delta does NOT re-publish the stage state (no re-allocation)',
      (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
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
    expect(identical(c.read(stageDirectorProvider(_conv)), before), isTrue,
        reason: 'delta 不重造/不通知,state 实例不变');
  });

  testWidgets('a short op (open+close inside the window) never stages; curtain returns to idle',
      (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'edit_document'));
    await tester.pump();
    repo.emitFrame(_conv, _close('b1'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(c.read(stageDirectorProvider(_conv)).stageOpen, isFalse);

    // A real one: open → stage → close → breath → curtain → idle. 真场:登台→关→停拍→谢幕。
    repo.emitFrame(_conv, _open('b2', 'create_workflow'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.read(stageDirectorProvider(_conv)).stageOpen, isTrue);
    repo.emitFrame(_conv, _close('b2'));
    await tester.pump();
    expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.following); // breath 停拍
    await tester.pump(const Duration(milliseconds: 2000));
    expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.idle);
  });

  testWidgets('deltas on the SUBJECT do not broadcast (value equality); channel deltas badge unread',
      (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
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
    await tester.pump(const Duration(milliseconds: 100)); // in channels (debouncing) 频道中
    c.read(stageDirectorProvider(_conv).notifier).pin(); // hold the camera 持镜
    repo.emitFrame(_conv, _delta('b2'));
    await tester.pump(const Duration(milliseconds: 600));
    final s = c.read(stageDirectorProvider(_conv));
    expect(s.phase, StagePhase.pinned);
    expect(s.channels.single.unread, greaterThan(0)); // badge moved 未读徽动了
  });

  testWidgets('failed close → failed-hold; dismiss → idle', (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_agent'));
    await tester.pump(const Duration(milliseconds: 600));
    repo.emitFrame(_conv, _close('b1', status: 'error'));
    await tester.pump();
    expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.failedHold);
    c.read(stageDirectorProvider(_conv).notifier).dismiss();
    expect(c.read(stageDirectorProvider(_conv)).phase, StagePhase.idle);
  });

  testWidgets('followMode never (from the notch) blocks auto-staging', (tester) async {
    final repo = FixtureChatRepository();
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.read(followModeProvider.notifier).set(FollowMode.never);
    c.listen(stageDirectorProvider(_conv), (_, _) {});
    await tester.pump();
    repo.emitFrame(_conv, _open('b1', 'create_function'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(c.read(stageDirectorProvider(_conv)).stageOpen, isFalse);
  });
}
