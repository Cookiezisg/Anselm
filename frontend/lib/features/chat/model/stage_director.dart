/// The sidestage DIRECTOR (WRK-061 §2 · G2 camera-lock retirement) — one pure state machine per
/// conversation that arbitrates who AUTO-OPENS. Framework-free (no widgets, no timers): every input
/// carries `now`, timing rules are expressed as DEADLINES the host schedules ([nextDeadline] → call
/// [advance] when it fires), so the whole choreography — entrance debounce, switch arbitration,
/// dwell, curtain — is unit-testable to the millisecond. [FollowMode] carries the user's standing
/// intent. The single-stage era's camera lock (pinned) retired with the accordion (G2): user
/// ownership is a ROW-level claim in the panel, so no interaction can ever freeze the follow
/// pipeline — the director always keeps flowing.
///
/// 侧幕导演器(G2 镜头锁退役)——每对话一只纯状态机,仲裁**自动展开谁**。零框架:每个输入带 `now`,
/// 时序规则全部表达为「期限」([nextDeadline] 由宿主排定时器、到点调 [advance]),登台防抖/换台仲裁/
/// 驻留/谢幕全程可毫秒级单测。FollowMode 承载用户全局意愿;单舞台时代的镜头锁(pinned)随手风琴退役
/// (G2):用户所有权改为面板的**行级认领**,任何交互都不再冻结跟随流水线——导演器永远流动。
library;

// FollowMode lives in core (settings/follow_mode.dart) so this pure model imports it without Riverpod,
// and the settings panel + chat both consume it without importing each other. Re-exported so existing
// consumers of this file keep seeing FollowMode. 跟随枚举在 core;re-export 保持既有消费者可见。
import '../../../core/settings/follow_mode.dart';

export '../../../core/settings/follow_mode.dart' show FollowMode;

/// §2 three states (G2): the machine only ever rests (idle), flows (following) or holds a failure
/// on stage (failedHold). The old `pinned` froze the whole pipeline behind an exit users could not
/// find, and `curtain` was declared but never entered — both retired; user ownership lives at the
/// panel's row level. 三态(G2):歇/流/failedHold 驻败。旧 pinned 冻结整条流水线且无出口、curtain
/// 声明而不可达——双双退役;用户所有权在面板行级。
enum StagePhase { idle, following, failedHold }

/// Why a subject is on stage — the §2 priority ladder, higher wins a switch. 优先级梯(高者可插队)。
enum StagePriority { subagent, execution, build, humanGate }

/// R-10: how an activity's lifecycle SETTLES. [toolClose] = the close IS the settle (builds, sync
/// executions). [poll] = the close is only an enqueue receipt (trigger_workflow's 202) — the stage
/// must NOT curtain on it; the real terminal arrives by polling/durable frames (W6 backend).
/// R-10 生命周期源:toolClose=关帧即落定;poll=关帧只是入队回执(202),绝不据此谢幕。
enum LifecycleSource { toolClose, poll }

/// One activity the director tracks — a tool_call open from the §3.4 stage-worthy closed set.
/// 导演器追踪的一项活动(登台闭表内的 tool_call open)。
class StageActivity {
  StageActivity({
    required this.blockId,
    required this.toolName,
    required this.kind,
    required this.priority,
    required this.openedAt,
    this.lifecycle = LifecycleSource.toolClose,
  }) : lastActivityAt = openedAt;

  final String blockId;
  final String toolName;

  /// The stage kind this routes to (function/document/workflow/…/subagent/terminal). 舞台 kind。
  final String kind;
  final StagePriority priority;
  final DateTime openedAt;

  /// R-10: how this activity settles (poll = the close never curtains). 生命周期源(poll 关帧不谢幕)。
  final LifecycleSource lifecycle;

  /// Last stream activity (delta arrival) — feeds the switch arbitration's idle test. 最近活动时刻。
  DateTime lastActivityAt;

  /// Set on close. live = not yet closed. 关帧时刻;live=未关。
  DateTime? closedAt;
  bool closedOk = true;

  /// G5 — a POLL activity's real terminal arrived (`run_terminal`). Until then a closed-ok poll
  /// block must NOT leave the live set: its 202 close is an enqueue receipt, and dropping it made
  /// running workflows vanish from the island whenever they weren't the subject (A1-6/A2-6).
  /// G5:poll 活动的真终态已到;此前 close-ok 不许离场——202 只是入队回执,旧丢法让非主角的
  /// 运行中工作流从岛上凭空消失。
  bool terminalSeen = false;

  /// The primary target entity id, once the args stream resolved it (feeds the Cast pulse, R-6).
  /// 主目标实体 id(args 流解出后喂入;驱动 Cast 脉冲)。
  String? itemId;

  /// Unread beats while OFF stage — a MACHINE-observable activity counter (G12 adjudication: the
  /// channel-tab badge it once fed retired with the accordion; tests read it to prove owner-mapped
  /// activity routing, and it stays excluded from StageState equality so it can never re-create the
  /// per-delta rebuild storm). 不在台上的未读拍数——机器可观测活性计数(G12 裁决:频道 tab 徽已随
  /// 手风琴退役;测试以它证属主活性路由,且仍被排除在值相等外、绝不复发逐 delta 重建风暴)。
  int unread = 0;

  bool get live => closedAt == null;
}

/// An activity as the island RENDERS it — an IMMUTABLE snapshot taken at emission time. The director's
/// working [StageActivity] records are mutable (deltas bump them in place); snapshotting here is what
/// makes [StageState]'s value equality sound (a mutable reference would read "unchanged" because
/// previous and next share the object — the close broadcast would be swallowed).
///
/// 活动的渲染视图——发射时刻的**不可变快照**。导演器工作记录是可变的(delta 原地累加);快照化使
/// StageState 的值相等成立(可变引用会让 previous/next 同对象、close 广播被吞)。
class StageActivityView {
  const StageActivityView({
    required this.blockId,
    required this.toolName,
    required this.kind,
    required this.live,
    required this.failed,
    required this.unread,
    this.itemId,
    this.poll = false,
  });

  StageActivityView.of(StageActivity a)
    : blockId = a.blockId,
      toolName = a.toolName,
      kind = a.kind,
      live = a.live,
      failed = !a.closedOk,
      unread = a.unread,
      itemId = a.itemId,
      poll = a.lifecycle == LifecycleSource.poll;

  final String blockId;
  final String toolName;
  final String kind;
  final bool live;
  final bool failed;
  final int unread;
  final String? itemId;

  /// R-10 poll lifecycle (G3): a CLOSED-but-held poll view means the flowrun is still RUNNING —
  /// the row head must say so, not «settling». Immutable per block, so excluded from equality.
  /// poll 生命周期(G3):已关仍驻留=flowrun 还在跑,行头须如实说「运行中」;随块不变,不入相等性。
  final bool poll;

  // [unread] is DELIBERATELY excluded from value equality (C-003): it is a beat counter for a
  // not-yet-built channel-tab badge — NOTHING renders it and no logic reads it. Including it meant every
  // delta on a NON-subject channel (unread++) broke StageState equality → the whole _AccordionList
  // rebuilt + _computeRows re-ran EVERY frame during parallel-tool streaming. Equality tracks only what
  // the island RENDERS. unread 刻意不入值相等:它是未建的频道 tab 徽的拍数、无处渲染无处读;曾令非主角每
  // delta 破坏 StageState 相等→并行流式时整手风琴每帧重建。相等只追可渲染面。
  @override
  bool operator ==(Object other) =>
      other is StageActivityView &&
      other.blockId == blockId &&
      other.live == live &&
      other.failed == failed &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(blockId, live, failed, itemId);
}

/// What the island renders — the director's full output, immutable per emission. 导演器输出快照。
class StageState {
  const StageState({
    required this.phase,
    this.subject,
    this.channels = const [],
    this.gateWaiting = false,
  });

  final StagePhase phase;

  /// The on-stage activity (null in idle). 台上主角。
  final StageActivityView? subject;

  /// OTHER live activities, entrance order (≥1 means parallel work). 其余活动(入场序)。
  final List<StageActivityView> channels;

  /// A human-gate is awaiting — the amber pill that pierces every silence (§2). 人闸琥珀态。
  final bool gateWaiting;

  bool get stageOpen => phase != StagePhase.idle && subject != null;

  // Value equality over what the island RENDERS so the provider skips no-op broadcasts — a delta on
  // the on-stage subject changes nothing here (its content flows through the transcript coalescer).
  // 按可渲染面值比较:主角自身 delta 不惊动 watcher(内容走 transcript coalescer)。
  @override
  bool operator ==(Object other) =>
      other is StageState &&
      other.phase == phase &&
      other.subject == subject &&
      other.gateWaiting == gateWaiting &&
      other.channels.length == channels.length &&
      () {
        for (var i = 0; i < channels.length; i++) {
          if (other.channels[i] != channels[i]) return false;
        }
        return true;
      }();

  @override
  int get hashCode =>
      Object.hash(phase, subject, gateWaiting, Object.hashAll(channels));
}

/// §3.4 stage-worthy closed set → its stage kind + priority; null = never stages (get/read/search/
/// list/delete/attachment/conversation and the human-gate verbs, which ride the pill instead).
/// 登台闭表→舞台 kind+优先级;null=不登台。
({String kind, StagePriority priority, LifecycleSource lifecycle})?
stageRouteOf(String toolName) {
  if (toolName == 'Subagent') {
    return (
      kind: 'subagent',
      priority: StagePriority.subagent,
      lifecycle: LifecycleSource.toolClose,
    );
  }
  if (toolName.startsWith('mcp__')) {
    return (
      kind: 'mcp',
      priority: StagePriority.execution,
      lifecycle: LifecycleSource.toolClose,
    );
  }
  switch (toolName) {
    case 'run_function':
      return (
        kind: 'function',
        priority: StagePriority.execution,
        lifecycle: LifecycleSource.toolClose,
      );
    case 'call_handler':
      return (
        kind: 'handler',
        priority: StagePriority.execution,
        lifecycle: LifecycleSource.toolClose,
      );
    case 'invoke_agent':
      return (
        kind: 'agent',
        priority: StagePriority.execution,
        lifecycle: LifecycleSource.toolClose,
      );
    case 'trigger_workflow':
      // 202: the close is an ENQUEUE receipt, not the run's terminal (R-10 poll type). 202 入队回执。
      return (
        kind: 'workflow',
        priority: StagePriority.execution,
        lifecycle: LifecycleSource.poll,
      );
    case 'fire_trigger':
      return (
        kind: 'trigger',
        priority: StagePriority.execution,
        lifecycle: LifecycleSource.toolClose,
      );
    case 'write_memory':
      return (
        kind: 'memory',
        priority: StagePriority.build,
        lifecycle: LifecycleSource.toolClose,
      );
    case 'install_mcp_server':
      return (
        kind: 'mcp',
        priority: StagePriority.build,
        lifecycle: LifecycleSource.toolClose,
      );
  }
  const buildKinds = [
    'function',
    'handler',
    'agent',
    'workflow',
    'trigger',
    'control',
    'approval',
    'document',
    'skill',
  ];
  for (final k in buildKinds) {
    if (toolName == 'create_$k' || toolName == 'edit_$k') {
      return (
        kind: k,
        priority: StagePriority.build,
        lifecycle: LifecycleSource.toolClose,
      );
    }
  }
  return null;
}

/// The director. Feed it events (each with `now`); read [state]; schedule [nextDeadline] and call
/// [advance] when it fires. All §2 timing constants are injectable for tests.
/// 导演器:喂事件(带 now)、读 state、按 nextDeadline 排闹钟到点调 advance。时序常量可注入。
class StageDirector {
  StageDirector({
    this.followMode = FollowMode.always,
    this.entranceDebounce = const Duration(milliseconds: 500),
    this.switchIdle = const Duration(milliseconds: 800),
    this.minDwell = const Duration(milliseconds: 2400),
    this.settleBreath = const Duration(milliseconds: 1800),
  });

  FollowMode followMode;
  // BEHAVIOURAL timing (W2 拍板值) — director semantics, NOT visual motion: exempt from the
  // AnMotion tier law (批7 立法1 成文豁免). 导演器行为时长,非视觉动效——立法1 豁免锚。
  final Duration entranceDebounce;
  final Duration switchIdle;
  final Duration minDwell;
  final Duration settleBreath;

  StagePhase _phase = StagePhase.idle;
  StageActivity? _subject;
  DateTime? _subjectStagedAt;
  final Map<String, StageActivity> _live =
      {}; // by blockId, entrance order 活动集(入场序)
  final List<String> _order = [];
  bool _followedOnceThisConversation = false;
  bool _gateWaiting = false;

  // Pending deadlines (the host schedules the earliest). 待触发期限。
  final Map<String, DateTime> _entranceDue =
      {}; // blockId → stage-entrance due 登台防抖
  DateTime? _curtainDue; // settle breath → curtain 谢幕期限
  DateTime?
  _switchRetryDue; // arbitration retry when dwell/idle not yet met 换台重试期限

  /// The earliest pending deadline, or null when nothing is scheduled. 最早期限。
  DateTime? get nextDeadline {
    DateTime? min;
    for (final d in [..._entranceDue.values, _curtainDue, _switchRetryDue]) {
      if (d != null && (min == null || d.isBefore(min))) min = d;
    }
    return min;
  }

  StageState get state {
    return StageState(
      phase: _phase,
      subject: _subject == null ? null : StageActivityView.of(_subject!),
      channels: [
        for (final id in _order)
          if (_live[id] != null && !identical(_live[id], _subject))
            StageActivityView.of(_live[id]!),
      ],
      gateWaiting: _gateWaiting,
    );
  }

  StageActivity? _freshestLiveNonSubject() {
    StageActivity? best;
    for (final a in _live.values) {
      if (identical(a, _subject) || !a.live) continue;
      if (best == null || a.lastActivityAt.isAfter(best.lastActivityAt)) {
        best = a;
      }
    }
    return best;
  }

  // ── stream-side inputs 流侧输入 ──

  /// A stage-worthy tool_call opened. Entrance is DEBOUNCED (§2): the activity stages only if still
  /// open after [entranceDebounce] (short ops never stage — no 3s of drama for 0.3s of fact).
  /// 登台闭表内 tool_call open。防抖:开后 500ms 仍未关才登台(短操作不登台)。
  void onToolOpen(String blockId, String toolName, DateTime now) {
    final route = stageRouteOf(toolName);
    if (route == null || _live.containsKey(blockId)) return;
    final a = StageActivity(
      blockId: blockId,
      toolName: toolName,
      kind: route.kind,
      priority: route.priority,
      openedAt: now,
      lifecycle: route.lifecycle,
    )..lastActivityAt = now;
    _live[blockId] = a;
    _order.add(blockId);
    // failed-hold may be displaced into a red-dot channel tab by new work (§2) — the hold survives
    // as a tab, the stage moves on. failed-hold 可被新活动挤成红点频道 tab(现场保留)。
    _entranceDue[blockId] = now.add(entranceDebounce);
  }

  /// Delta arrived for an activity (its args/output are growing). 活动来 delta。
  void onActivity(String blockId, DateTime now) {
    final a = _live[blockId];
    if (a == null) return;
    a.lastActivityAt = now;
    if (!identical(a, _subject)) a.unread++;
  }

  /// The activity's primary entity id resolved (args close / create receipt — Cast pulse, R-6).
  /// FIRST resolution wins (G7): identity must never re-key mid-flight — an mcp install resolves
  /// its NAME at args close (the ledger's real join key) and its receipt later carries a raw `id`;
  /// letting the second overwrite the first left the expansion state stranded on the middle key.
  /// 主目标 id 解出;**首解出者胜**(G7)——身份绝不中途换键:mcp 安装参流关先解出名(台账真合流键)、
  /// 回执又带裸 id,后者覆写前者会把展开态搁浅在中间键上。
  void onItemResolved(String blockId, String itemId) {
    final a = _live[blockId];
    if (a == null) return;
    if (a.itemId == null || a.itemId!.isEmpty) a.itemId = itemId;
  }

  /// The activity's tool_call closed. [ok] false → failed/cancelled. 关帧。
  void onToolClose(String blockId, DateTime now, {bool ok = true}) {
    final a = _live[blockId];
    if (a == null) return;
    a.closedAt = now;
    a.closedOk = ok;
    _entranceDue.remove(
      blockId,
    ); // a close inside the debounce = short op, never stages 短操作不登台
    if (identical(a, _subject)) {
      if (!ok) {
        _phase = StagePhase
            .failedHold; // red-hold: stays until dismissed / displaced 红纱驻留
        _curtainDue = null;
      } else if (_phase == StagePhase.following &&
          a.lifecycle == LifecycleSource.toolClose) {
        // settle → breath → curtain (unless something else is live to switch to). A POLL-type close
        // is only an enqueue receipt (R-10) — the stage holds until dismissed or displaced. 落定停拍
        // 再谢幕;poll 型关帧只是入队回执(R-10)——驻留到收场/挤台。
        _curtainDue = now.add(settleBreath);
      }
    } else {
      _dropIfSettled(a, now);
    }
    _arbitrate(now);
  }

  /// The flowrun behind a POLL-type activity reached its terminal (the durable `run_terminal`
  /// entities signal, W6 backend) — the run is truly over, so the R-10 hold retires: a following
  /// stage settles into the normal breath→curtain; a failure flips the red hold. Only meaningful
  /// AFTER the enqueue receipt closed the block (a terminal can't precede its own 202).
  ///
  /// poll 型活动背后的 flowrun 到达终态(durable `run_terminal` entities 信号,W6 后端)——run 真结束,
  /// R-10 驻留退役:following 舞台落定入正常停拍→谢幕;失败翻红纱。仅在入队回执关块**之后**有意义
  /// (终态不可能先于自己的 202)。
  void onRunTerminal(String blockId, DateTime now, {bool ok = true}) {
    final a = _live[blockId];
    if (a == null ||
        a.closedAt == null ||
        a.lifecycle != LifecycleSource.poll) {
      return;
    }
    a.closedOk = ok;
    a.terminalSeen = true;
    if (identical(a, _subject)) {
      if (!ok) {
        _phase = StagePhase.failedHold;
        _curtainDue = null;
      } else if (_phase == StagePhase.following) {
        _curtainDue = now.add(settleBreath);
      }
    } else {
      _dropIfSettled(a, now);
    }
    _arbitrate(now);
  }

  /// G5 — align with DB truth after a stream gap (410 resync / a provider rebuilt mid-run): every
  /// tracked activity whose id is NOT in [liveIds] had its terminal swallowed — clear it, exactly
  /// as a row-level clear would (the transcript/Cast own its settled record). The director is a
  /// pure incremental consumer; this is its one re-grounding path («DB 行是真相、流只为实时»).
  /// G5:对齐 DB 真相(410 重同步/中途重建)——不在 [liveIds] 里的活动=终态被缺口吞了,照行级清除
  /// 处理(落定记录归 transcript/Cast)。导演器是纯增量消费者,此为唯一重新接地之路。
  void onRealign(Set<String> liveIds, DateTime now) {
    // Only DIRECTOR-LIVE activities can be ghosts (their close was swallowed). A closed one the
    // director still holds is deliberate choreography — the settle breath, a poll hold, a failed
    // red row — and must survive the sweep. 只有导演器仍认为 live 的才可能是幽灵;已关仍驻留的是
    // 编排本意(停拍/poll 驻留/失败红行),清扫须豁免。
    final ghosts = [
      for (final a in _live.values)
        if (a.live && !liveIds.contains(a.blockId)) a.blockId,
    ];
    for (final id in ghosts) {
      onClearActivity(id, now);
    }
  }

  /// The human-gate pending count changed (from pendingInteractions). 人闸待决数变化。
  void onGateWaiting(bool waiting) => _gateWaiting = waiting;

  // ── user-side inputs 用户侧输入 ──
  // G2: the camera lock (onUserPin / onFollowResume) retired with the accordion — user ownership is
  // a row-level claim in the panel, never a director phase, so interaction can't stall the pipeline.
  // G2:镜头锁随手风琴退役——用户所有权是面板行级认领、绝非导演器相位,交互不再冻结流水线。

  /// Row-level clear (G3) — drop ONE activity by blockId: the failed-hold exit (a failed activity
  /// used to squat in the live set forever with no UI way out). Clearing the subject dismisses the
  /// stage; still-live others re-earn through a fresh debounce.
  /// 行级清除(G3)——按 blockId 丢单个活动:失败驻留的出口(旧失败活动永久滞留且无 UI 出路)。清的是
  /// 主角则收场;在场者重新走防抖登台。
  void onClearActivity(String blockId, DateTime now) {
    final a = _live.remove(blockId);
    _order.remove(blockId);
    _entranceDue.remove(blockId);
    if (a == null || !identical(a, _subject)) return;
    _subject = null;
    _subjectStagedAt = null;
    _curtainDue = null;
    _phase = StagePhase.idle;
    for (final b in _live.values) {
      if (b.live && !_entranceDue.containsKey(b.blockId)) {
        _entranceDue[b.blockId] = now.add(entranceDebounce);
      }
    }
  }

  // ── the clock 时钟 ──

  /// Fire every deadline ≤ [now]. The host calls this when its timer lands (and may call it any time —
  /// idempotent). 触发所有到期期限(幂等)。
  void advance(DateTime now) {
    // entrances — simultaneous arrivals stage best-first (priority, then freshest), not map order.
    // 登台:同拍到点者按「优先级→新鲜度」序处理,非 map 序。
    final due = _entranceDue.entries
        .where((e) => !e.value.isAfter(now))
        .map((e) => e.key)
        .toList();
    final dueActs =
        [
          for (final id in due)
            if (_live[id] != null && _live[id]!.live) _live[id]!,
        ]..sort((a, b) {
          final p = b.priority.index.compareTo(a.priority.index);
          return p != 0 ? p : b.lastActivityAt.compareTo(a.lastActivityAt);
        });
    for (final id in due) {
      _entranceDue.remove(id);
    }
    for (final a in dueActs) {
      _tryStage(a, now);
    }
    // curtain 谢幕
    final curtain = _curtainDue;
    if (curtain != null &&
        !curtain.isAfter(now) &&
        _phase == StagePhase.following) {
      _curtainDue = null;
      final next = _freshestLiveNonSubject();
      if (next != null) {
        _stage(next, now); // curtain preempted by live work 谢幕被新活动接场
      } else {
        _dismiss(now, throughCurtain: true);
      }
    }
    // switch retry 换台重试
    if (_switchRetryDue != null && !_switchRetryDue!.isAfter(now)) {
      _switchRetryDue = null;
      _arbitrate(now);
    }
  }

  // ── internals 内部 ──

  bool get _followAllowed => switch (followMode) {
    FollowMode.never => false,
    FollowMode.always => true,
    FollowMode.firstPerConversation => !_followedOnceThisConversation,
  };

  void _tryStage(StageActivity a, DateTime now) {
    if (_subject == null) {
      if (_phase == StagePhase.idle && !_followAllowed) return;
      _stage(a, now);
      _phase = StagePhase.following;
      _followedOnceThisConversation = true;
      return;
    }
    // failed-hold is displaced by new work — the red draft survives as a red-dot channel tab (§2).
    // failed-hold 被新活动挤台:红纱现场保留为红点频道 tab,点回可看。
    if (_phase == StagePhase.failedHold) {
      _stage(a, now);
      _phase = StagePhase.following;
      return;
    }
    _arbitrate(now, candidate: a);
  }

  /// §2 switch arbitration: only in following; the newcomer must outrank OR the current subject must
  /// be idle > [switchIdle] AND dwelled ≥ [minDwell]. A higher-priority candidate (the human gate is
  /// handled by the pill, so effectively build > execution > subagent) preempts the dwell test.
  /// 换台仲裁:仅 following;新者优先级更高可插队,否则须当前主角空闲>800ms 且驻留≥2400ms。
  void _arbitrate(DateTime now, {StageActivity? candidate}) {
    if (_phase != StagePhase.following) return;
    final current = _subject;
    if (current == null) return;
    final next = candidate ?? _bestWaiting(current);
    if (next == null || identical(next, current)) return;
    final outranks = next.priority.index > current.priority.index;
    final subjectSettled = !current.live;
    final idleLong = now.difference(current.lastActivityAt) >= switchIdle;
    final dwelled =
        _subjectStagedAt == null ||
        now.difference(_subjectStagedAt!) >= minDwell;
    if (outranks || subjectSettled || (idleLong && dwelled)) {
      _stage(next, now);
    } else {
      // Re-arbitrate when the earliest of (idle, dwell) can next be satisfied. 待期限再仲裁。
      final idleAt = current.lastActivityAt.add(switchIdle);
      final dwellAt = (_subjectStagedAt ?? now).add(minDwell);
      final retry = idleAt.isAfter(dwellAt) ? idleAt : dwellAt;
      if (_switchRetryDue == null || retry.isBefore(_switchRetryDue!)) {
        _switchRetryDue = retry;
      }
    }
  }

  StageActivity? _bestWaiting(StageActivity current) {
    StageActivity? best;
    for (final a in _live.values) {
      if (identical(a, current) || !a.live) continue;
      if (best == null ||
          a.priority.index > best.priority.index ||
          (a.priority == best.priority &&
              a.lastActivityAt.isAfter(best.lastActivityAt))) {
        best = a;
      }
    }
    return best;
  }

  void _stage(StageActivity a, DateTime now) {
    final prev = _subject;
    _subject = a;
    _subjectStagedAt = now;
    a.unread = 0;
    _curtainDue = null;
    if (prev != null && !identical(prev, a)) _dropIfSettled(prev, now);
    _phase = StagePhase.following;
  }

  // A non-subject activity that closed OK leaves the live set (its record lives in Cast/transcript);
  // a failed one keeps its red row until cleared. A POLL block whose terminal hasn't arrived is NOT
  // settled (G5/A1-6): its close was only the enqueue receipt — dropping it here made running
  // workflows vanish whenever they weren't the subject, and the later run_terminal found nothing.
  // 落定离场;失败留红行待清除;poll 未见终态≠落定(G5)——202 只是回执,旧丢法让非主角运行中
  // 工作流凭空消失、run_terminal 到达时已无人认领。
  void _dropIfSettled(StageActivity a, DateTime now) {
    final pollHeld =
        a.lifecycle == LifecycleSource.poll && a.closedOk && !a.terminalSeen;
    if (!a.live && a.closedOk && !pollHeld) {
      _live.remove(a.blockId);
      _order.remove(a.blockId);
    }
  }

  void _dismiss(DateTime now, {bool throughCurtain = false}) {
    final s = _subject;
    if (s != null && !s.live) {
      _live.remove(s.blockId);
      _order.remove(s.blockId);
    }
    _subject = null;
    _subjectStagedAt = null;
    _curtainDue = null;
    _phase = StagePhase.idle;
    // Anything still live re-earns the stage through a fresh debounce window. 在场者重新走防抖登台。
    for (final a in _live.values) {
      if (a.live && !_entranceDue.containsKey(a.blockId)) {
        _entranceDue[a.blockId] = now.add(entranceDebounce);
      }
    }
  }
}
