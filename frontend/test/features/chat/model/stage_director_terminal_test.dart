import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:flutter_test/flutter_test.dart';

// W7: the R-10 retirement — a poll-type stage held past its 202 close settles the moment the
// flowrun's durable `run_terminal` arrives (clean → breath→curtain; failed → red hold); a terminal
// BEFORE the enqueue receipt closes the block is impossible and therefore ignored.
// W7:R-10 退役——202 后驻留的 poll 舞台在 durable run_terminal 到达瞬间落定(净→停拍谢幕;败→红纱);
// 早于入队回执关块的终态不可能存在、因此忽略。

void main() {
  final t0 = DateTime.utc(2026, 7, 8, 12);

  test('clean terminal: the held poll stage settles into breath → curtain', () {
    final d = StageDirector();
    d.onToolOpen('b1', 'trigger_workflow', t0);
    d.advance(t0.add(const Duration(milliseconds: 500)));
    d.onToolClose('b1', t0.add(const Duration(seconds: 2))); // the 202 receipt 入队回执
    d.advance(t0.add(const Duration(seconds: 60)));
    expect(d.state.stageOpen, isTrue, reason: 'R-10: the 202 close never curtains 202 不谢幕');

    d.onRunTerminal('b1', t0.add(const Duration(seconds: 90)));
    // breath then curtain — the normal settle rhythm takes over. 停拍→谢幕,回归正常落定节奏。
    d.advance(t0.add(const Duration(seconds: 90)).add(d.settleBreath));
    d.advance(d.nextDeadline ?? t0.add(const Duration(seconds: 120)));
    expect(d.state.stageOpen, isFalse, reason: 'the run truly ended — the hold retires 驻留退役');
  });

  test('failed terminal: the poll stage flips to the red hold', () {
    final d = StageDirector();
    d.onToolOpen('b1', 'trigger_workflow', t0);
    d.advance(t0.add(const Duration(milliseconds: 500)));
    d.onToolClose('b1', t0.add(const Duration(seconds: 2)));

    d.onRunTerminal('b1', t0.add(const Duration(seconds: 30)), ok: false);
    expect(d.state.phase, StagePhase.failedHold);
    d.advance(t0.add(const Duration(minutes: 5)));
    expect(d.state.stageOpen, isTrue, reason: 'a failure holds until dismissed 失败驻留');
  });

  test('a terminal before the receipt close — or for a non-poll block — is a no-op', () {
    final d = StageDirector();
    d.onToolOpen('b1', 'trigger_workflow', t0);
    d.advance(t0.add(const Duration(milliseconds: 500)));
    d.onRunTerminal('b1', t0.add(const Duration(seconds: 1))); // still open 还没关
    expect(d.state.stageOpen, isTrue);
    expect(d.state.phase, StagePhase.following);

    final d2 = StageDirector();
    d2.onToolOpen('b2', 'create_document', t0); // toolClose lifecycle 非 poll
    d2.advance(t0.add(const Duration(milliseconds: 500)));
    d2.onToolClose('b2', t0.add(const Duration(seconds: 2)));
    d2.onRunTerminal('b2', t0.add(const Duration(seconds: 3)), ok: false);
    expect(d2.state.phase, isNot(StagePhase.failedHold),
        reason: 'run_terminal only speaks to poll-type activities 只对 poll 型说话');
  });
}
