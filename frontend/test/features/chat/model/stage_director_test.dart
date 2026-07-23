import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:flutter_test/flutter_test.dart';

// stageDirector (WRK-061 §2 · G2) — the pure per-conversation state machine. The camera lock
// (pinned) retired in G2: user ownership is a PANEL row claim, so the machine here is only ever
// idle / following / failedHold and NO input can freeze the follow pipeline. Batteries: entrance
// debounce (short ops never stage), followMode notches, switch arbitration (priority ladder /
// idle+dwell), curtain with preemption, failed-hold displacement, dismissal re-earning.
// 导演器电池(G2 镜头锁退役,仅三态、任何输入不冻流水线):登台防抖/跟随三档/换台仲裁/谢幕接场/
// failed 挤台/收场重挣。

final _t0 = DateTime.utc(2026, 7, 8, 12);
DateTime _t(int ms) => _t0.add(Duration(milliseconds: ms));

void main() {
  test(
    'entrance debounce: stages only if still open after 500ms; a short op NEVER stages',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'create_function', _t(0));
      expect(d.state.stageOpen, isFalse); // not yet 防抖中
      expect(d.nextDeadline, _t(500));
      d.advance(_t(500));
      expect(d.state.stageOpen, isTrue);
      expect(d.state.subject!.kind, 'function');
      expect(d.state.phase, StagePhase.following);

      final d2 = StageDirector();
      d2.onToolOpen('b1', 'create_document', _t(0));
      d2.onToolClose('b1', _t(300)); // 0.3s of fact — no 3s of drama 短操作
      d2.advance(_t(500));
      expect(d2.state.stageOpen, isFalse);
      expect(d2.state.phase, StagePhase.idle);
    },
  );

  test(
    'the stage-worthy closed set: get/read/search/delete/gate verbs never stage',
    () {
      expect(stageRouteOf('get_function'), isNull);
      expect(stageRouteOf('search_workflows'), isNull);
      expect(stageRouteOf('list_documents'), isNull);
      expect(stageRouteOf('delete_agent'), isNull);
      expect(stageRouteOf('ask_user'), isNull); // gate rides the pill 人闸走药丸
      expect(stageRouteOf('decide_approval'), isNull);
      expect(stageRouteOf('read_document'), isNull);
      expect(stageRouteOf('edit_workflow')!.kind, 'workflow');
      expect(stageRouteOf('run_function')!.priority, StagePriority.execution);
      expect(stageRouteOf('mcp__github__create_issue')!.kind, 'mcp');
      expect(stageRouteOf('Subagent')!.priority, StagePriority.subagent);
      expect(stageRouteOf('write_memory')!.kind, 'memory');
    },
  );

  test(
    'followMode never: nothing auto-stages; firstPerConversation: only the first',
    () {
      final never = StageDirector(followMode: FollowMode.never);
      never.onToolOpen('b1', 'create_function', _t(0));
      never.advance(_t(600));
      expect(never.state.stageOpen, isFalse);

      final first = StageDirector(followMode: FollowMode.firstPerConversation);
      first.onToolOpen('b1', 'create_function', _t(0));
      first.advance(_t(500));
      expect(first.state.stageOpen, isTrue);
      first.onToolClose('b1', _t(1000));
      first.advance(_t(3000)); // curtain 谢幕
      expect(first.state.phase, StagePhase.idle);
      first.onToolOpen('b2', 'create_document', _t(4000));
      first.advance(_t(4600));
      expect(
        first.state.stageOpen,
        isFalse,
      ); // second act needs the user 第二场要用户开
    },
  );

  test(
    'G2: no input can freeze the pipeline — channel deltas badge unread while arbitration still runs',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'create_function', _t(0));
      d.advance(_t(500));

      d.onToolOpen('b2', 'create_workflow', _t(1100));
      d.advance(_t(1600)); // entrance deadline fires 防抖到点
      d.onActivity('b1', _t(1700)); // subject stays hot 主角保持活跃
      d.onActivity('b2', _t(2000));
      d.onActivity('b2', _t(2100));
      expect(d.state.subject!.blockId, 'b1'); // idle unmet → no switch 未静默不换
      expect(d.state.phase, StagePhase.following); // never frozen 永不冻结
      expect(d.state.channels.single.unread, 2);

      // b1 goes quiet → same-priority arbitration eventually hands over (the retired pinned phase
      // would have blocked this forever with no exit). 静默后仲裁照常交棒(旧 pinned 永久卡死)。
      d.advance(_t(30000));
      expect(d.state.subject!.blockId, 'b2');
      expect(d.state.phase, StagePhase.following);
    },
  );

  test(
    'switch arbitration: same-priority newcomer waits for idle 800ms + dwell 2400ms',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'create_function', _t(0));
      d.advance(_t(500)); // staged at 500 登台
      d.onToolOpen('b2', 'create_document', _t(600));
      d.advance(
        _t(1100),
      ); // b2 entrance due — but b1 active + dwell unmet b1 仍活跃
      d.onActivity('b1', _t(1200));
      d.advance(_t(2000));
      expect(d.state.subject!.blockId, 'b1'); // idle not met 空闲不足
      // b1 goes quiet at 1200; idle met at 2000, dwell (500+2400=2900) not yet. 驻留未满。
      d.advance(_t(2899));
      expect(d.state.subject!.blockId, 'b1');
      d.advance(_t(2950)); // both met → switch 双满足→换台
      expect(d.state.subject!.blockId, 'b2');
    },
  );

  test(
    'priority ladder: a BUILD preempts a subagent broadcast without waiting',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'Subagent', _t(0));
      d.advance(_t(500));
      expect(d.state.subject!.kind, 'subagent');
      d.onActivity('b1', _t(600)); // still hot 仍活跃
      d.onToolOpen('b2', 'edit_function', _t(700));
      d.advance(_t(1200)); // entrance due → outranks → preempt 高优先级插队
      expect(d.state.subject!.blockId, 'b2');
      expect(
        d.state.channels.single.blockId,
        'b1',
      ); // subagent keeps a tab 子代理进频道条
    },
  );

  test('curtain: close + breath → idle; live work preempts the curtain', () {
    final d = StageDirector();
    d.onToolOpen('b1', 'create_function', _t(0));
    d.advance(_t(500));
    d.onToolClose('b1', _t(3000));
    expect(d.state.phase, StagePhase.following); // breath 停拍中
    d.advance(_t(4800)); // 3000+1800 谢幕
    expect(d.state.phase, StagePhase.idle);
    expect(d.state.subject, isNull);

    final d2 = StageDirector();
    d2.onToolOpen('b1', 'create_function', _t(0));
    d2.advance(_t(500));
    d2.onToolOpen('b2', 'create_document', _t(2800));
    d2.onToolClose('b1', _t(3000));
    d2.advance(
      _t(3300),
    ); // b2's entrance (2800+500) lands during the breath 防抖到点在停拍窗内
    d2.advance(_t(4800));
    expect(d2.state.phase, StagePhase.following);
    expect(d2.state.subject!.blockId, 'b2'); // the show goes on 接场
  });

  test(
    'failed close → failed-hold; new work displaces it into a red-dot tab (scene kept)',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'create_function', _t(0));
      d.advance(_t(500));
      d.onToolClose('b1', _t(2000), ok: false);
      expect(d.state.phase, StagePhase.failedHold);
      d.advance(_t(30000));
      expect(
        d.state.subject!.blockId,
        'b1',
      ); // holds until displaced/dismissed 驻留

      d.onToolOpen('b2', 'create_document', _t(31000));
      d.advance(_t(31500));
      expect(d.state.subject!.blockId, 'b2'); // displaced 挤台
      expect(d.state.phase, StagePhase.following);
      final tab = d.state.channels.single;
      expect(tab.blockId, 'b1');
      expect(tab.failed, isTrue); // the red dot survives 红点现场保留
    },
  );

  test(
    'dismiss: still-live activities re-earn the stage through a fresh debounce',
    () {
      final d = StageDirector();
      d.onToolOpen('b1', 'create_function', _t(0));
      d.advance(_t(500));
      d.onToolOpen('b2', 'create_document', _t(600));
      d.advance(_t(1100));
      d.onDismiss(_t(2000));
      expect(d.state.phase, StagePhase.idle);
      d.advance(_t(2500)); // b2 re-earns (2000+500) 重挣登台
      expect(d.state.subject?.blockId, 'b2');
      expect(d.state.phase, StagePhase.following);
    },
  );

  test(
    'gate flag rides the state; unread resets when an activity takes the stage',
    () {
      final d = StageDirector();
      d.onGateWaiting(true);
      expect(d.state.gateWaiting, isTrue);
      d.onToolOpen('b1', 'create_function', _t(0));
      d.onActivity('b1', _t(100));
      d.onActivity('b1', _t(200));
      d.advance(_t(500));
      expect(d.state.subject!.unread, 0); // staged → cleared 登台即清
    },
  );
}
