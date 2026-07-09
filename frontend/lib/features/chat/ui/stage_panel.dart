import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/partial_json.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../model/stage_director.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../state/conversation_stream_provider.dart';
import '../state/rundown_provider.dart';
import '../state/stage_director_provider.dart';
import '../state/touchpoint_ledger.dart';
import '../state/exhibit_provider.dart';
import '../state/transcript_jump_provider.dart';
import 'stages/stage_registry.dart';
import 'stages/stage_scene.dart';
import 'tool_card_skins.dart';
import 'exhibit_stage.dart';
import '../state/flowrun_progress.dart';
import 'tool_card_nav.dart';

/// The SIDESTAGE (WRK-061 §1/§6) — the chat right island's content: head band → channel strip →
/// the stage (the director's subject rendered live) → follow/gate pills → the Cast (touchpoint
/// ledger). W1 ships the spine + the GENERIC STAGE (subject brow + closed-args KV + live tail window
/// + RunStatBar) — the per-kind bespoke stages replace the generic body from W2 onward.
///
/// 侧幕——chat 右岛内容:头带→频道条→舞台(导演器主角活渲)→跟随/人闸药丸→演员表(触点台账)。
/// W1 落脊柱+**通用舞台**(主角眉+闭合 args KV 陈列+活尾窗+RunStatBar);逐 kind 量身舞台自 W2 起替换通用体。
class StagePanel extends ConsumerWidget {
  const StagePanel({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final stage = ref.watch(stageDirectorProvider(conversationId));
    final director = ref.read(stageDirectorProvider(conversationId).notifier);
    // The a11y four announcements (WRK-061 §11 a11y 章): staging / human gate / failure / settle —
    // polite interruptions for screen-reader users who cannot see the silent stage swaps.
    // a11y 四播报:登台/人闸/失败/落定——对看不见无声换台的读屏用户礼貌插话。
    ref.listen(stageDirectorProvider(conversationId), (prev, next) {
      if (prev == null) return;
      final t2 = Translations.of(context);
      String subjectWord(StageActivityView? a) => a?.itemId ?? a?.kind ?? '';
      void announce(String msg) => SemanticsService.sendAnnouncement(
          View.of(context), msg, Directionality.of(context));
      if (next.subject != null &&
          (prev.subject?.blockId != next.subject!.blockId || (!prev.stageOpen && next.stageOpen))) {
        announce(t2.chat.stage.a11y.staged(name: subjectWord(next.subject)));
      }
      if (!prev.gateWaiting && next.gateWaiting) announce(t2.chat.stage.a11y.gate);
      if (prev.phase != StagePhase.failedHold && next.phase == StagePhase.failedHold) {
        announce(t2.chat.stage.a11y.failed);
      }
      if (prev.stageOpen && !next.stageOpen && prev.phase != StagePhase.failedHold) {
        announce(t2.chat.stage.a11y.settled(name: subjectWord(prev.subject)));
      }
    });
    // The user-held exhibit wins the stage area until dismissed (pinned semantics — automatic
    // staging never displaces it; live activity stays visible on the channel strip).
    // 用户持有的展品占舞台区直到关闭(pinned 语义——自动登台不顶;活动仍在频道条)。
    final exhibit = ref.watch(exhibitProvider(conversationId));
    final transcript =
        ref.watch(conversationStreamProvider(conversationId).notifier).transcript;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnInspectorHead(
        icon: AnIcons.subagent,
        label: t.chat.stage.title,
        // The follow three-notch (WRK-061 §12-1): every-time / first-per-conversation / never —
        // persisted, and the settings module (路线⑤) reads the same provider. (Step-7 rebuild adds
        // expand-all / collapse-all here.) 跟随三档;步7 重构在此加展开/收起全部。
        actions: [_FollowMenu()],
        onClose: stage.stageOpen ? director.dismiss : null,
        closeSemantics: t.chat.stage.title,
      ),
      if (stage.channels.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(AnSpace.s8, AnSpace.s4, AnSpace.s8, AnSpace.s4),
          child: AnChannelStrip(
            channels: [
              for (final ch in stage.channels)
                AnChannel(id: ch.blockId, kind: ch.kind, unread: ch.unread, live: ch.live, failed: ch.failed),
            ],
            activeId: stage.subject?.blockId,
            onTap: (id) => director.pin(blockId: id),
          ),
        ),
      if (exhibit != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          child: ExhibitStage(conversationId: conversationId, subject: exhibit),
        ),
      AnExpandReveal(
        open: exhibit == null && stage.stageOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          child: stage.subject == null
              ? const SizedBox.shrink()
              : _GenericStage(
                  conversationId: conversationId,
                  subject: stage.subject!,
                  phase: stage.phase,
                  transcript: transcript,
                  onPin: () => director.pin(),
                  onItemResolved: (itemId) => director.itemResolved(stage.subject!.blockId, itemId),
                  // R-14: a settle hands off to the transcript anchor — jump to the turn that
                  // contains the subject block (a role-式 Subagent's ONLY anchor).
                  // R-14:谢幕交棒 transcript 锚——跳到含主角块的回合(role 式 Subagent 唯一的锚)。
                  onJumpAnchor: () {
                    final mid = transcript.value.messageIdOf(stage.subject!.blockId);
                    if (mid != null) {
                      ref
                          .read(transcriptJumpProvider(conversationId).notifier)
                          .request(mid, blockId: stage.subject!.blockId);
                    }
                  },
                ),
        ),
      ),
      if (stage.gateWaiting || stage.followPillTarget != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(AnSpace.s8, AnSpace.s4, AnSpace.s8, 0),
          child: Row(children: [
            Flexible(
              child: stage.gateWaiting
                  // The amber pill pierces everything; deciding happens in the transcript gate only.
                  // 琥珀药丸破一切静默;决策只在 transcript 白岛门。
                  ? AnFollowPill(kind: AnFollowPillKind.gate, onTap: () {})
                  : AnFollowPill(
                      kind: AnFollowPillKind.live,
                      subjectName: stage.followPillTarget!.itemId ?? stage.followPillTarget!.kind,
                      onTap: director.resume,
                    ),
            ),
          ]),
        ),
      _RundownSection(conversationId: conversationId),
      const SizedBox(height: AnSpace.s6),
      Container(height: AnSize.hairline, color: c.line),
      Expanded(child: _CastList(conversationId: conversationId, stage: stage)),
    ]);
  }
}

/// The generic stage body — every kind's fallback until its bespoke stage lands (W2–W5). Designed,
/// not a stub (§10-W1): subject brow (kind glyph + resolving name + phase章 + pin), the honesty
/// ribbon, closed top-level args as a KV list, the in-flight tail in a machine window, RunStatBar on
/// settle. Rides the transcript coalescer (≤1 rebuild/frame) — content cost is session-incremental.
///
/// 通用舞台——量身舞台落地前的兜底,但按设计做非空窗:主角眉(kind 字形+候名+相位章+pin)、诚实丝带、
/// 闭合顶层 args KV 陈列、在途尾值机器窗、落定 RunStatBar。骑 transcript coalescer(每帧≤1 重建)。
class _GenericStage extends StatefulWidget {
  const _GenericStage({
    required this.conversationId,
    required this.subject,
    required this.phase,
    required this.transcript,
    required this.onPin,
    required this.onItemResolved,
    required this.onJumpAnchor,
  });

  final String conversationId;
  final StageActivityView subject;
  final StagePhase phase;
  final CoalescingNotifier<ConversationTranscript> transcript;
  final VoidCallback onPin;
  final void Function(String itemId) onItemResolved;
  final VoidCallback onJumpAnchor;

  @override
  State<_GenericStage> createState() => _GenericStageState();
}

class _GenericStageState extends State<_GenericStage> {
  String? _resolved;

  static const _frameworkKeys = {'summary', 'danger', 'execution_group'};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    return ValueListenableBuilder<ConversationTranscript>(
      valueListenable: widget.transcript,
      builder: (context, transcript, _) {
        final node = transcript.liveBlock(widget.subject.blockId);
        if (node == null) {
          // Not in the live reducer (island opened mid-run after a reload) — honest placeholder.
          // live reducer 里没有(重载后中途开岛)——诚实占位。
          return Padding(
            padding: const EdgeInsets.all(AnSpace.s8),
            child: AnHonestyRibbon(widget.subject.live ? AnHonesty.gap : AnHonesty.live),
          );
        }
        final state = ToolCardState.of(node);
        final session = state.argsSession;
        final name = _subjectName(state, session);
        // R-6: hand the resolved primary id to the director for the Cast pulse. 主目标 id 喂导演器。
        final id = session.liveStringNamed('id') ??
            session.closedValueAt(['functionId']) as String? ??
            (name.isNotEmpty ? name : null);
        if (id is String && id.isNotEmpty && id != _resolved) {
          _resolved = id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onItemResolved(id);
          });
        }
        final live = node.isOpen;
        final failed = widget.phase == StagePhase.failedHold;
        // The bespoke stage for this kind (W2+), else the designed generic body. 量身舞台,缺则通用体。
        final bespoke = stageBodies[widget.subject.kind];
        final scene = StageScene(
          conversationId: widget.conversationId,
          subject: widget.subject,
          phase: widget.phase,
          node: node,
          state: state,
          session: session,
        );
        return NotificationListener<ScrollStartNotification>(
          // Reading = holding the camera: scrolling INSIDE the stage pins it just like a tap
          // (§2 anchored — a user mid-read must never be auto-switched away). Only USER-initiated
          // scrolls count (dragDetails != null); programmatic settles stay free.
          // 阅读即持镜:舞台内滚动与点按同样占用(§2 anchored——读到一半的人绝不被自动换台)。只认用户
          // 手势(dragDetails != null),程序性滚动不占。
          onNotification: (n) {
            if (n.dragDetails != null) widget.onPin();
            return false;
          },
          child: GestureDetector(
          // ANY stage interaction = the user occupies the camera (§2 following→pinned d). 舞台交互=占用。
          onTapDown: (_) => widget.onPin(),
          behavior: HitTestBehavior.translucent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _brow(context, c, t, name, live, failed),
            const SizedBox(height: AnSpace.s4),
            // The ribbon guards LIVE dictation and holds the failure truth; a clean settle IS the
            // truth — no ribbon. 丝带守活听写与失败真相;干净落定即真相,无丝带。
            if (failed || live) ...[
              AnHonestyRibbon(failed ? AnHonesty.failed : AnHonesty.live),
              const SizedBox(height: AnSpace.s6),
            ],
            // A poll-type subject (trigger_workflow) carries the LIVE RUN SCROLL: node ticks off
            // the entities stream roll in as quiet rows while the 202 hold listens (the streaming
            // centerpiece — calm, line-by-line, no theatrics). poll 主体带活运行卷:节点 tick 逐行
            // 静静落下(流式核心——克制、逐行、不演)。
            if (stageRouteOf(widget.subject.toolName)?.lifecycle == LifecycleSource.poll)
              _RunProgressSection(blockId: widget.subject.blockId),
            // LIVE streaming content is semantics-noise for a screen reader (word-by-word churn) —
            // the four announcements + the settled truth carry the meaning (a11y 章). 流式区静音。
            ExcludeSemantics(
              excluding: live,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bespoke != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: AnSpace.s8),
                        child: bespoke(context, scene))
                  else
                    ..._body(context, c, state, session, live, failed),
                ],
              ),
            ),
          ]),
          ),
        );
      },
    );
  }

  String _subjectName(ToolCardState state, PartialJsonSession session) {
    if (state.entityName.isNotEmpty) return state.entityName;
    // TOP-LEVEL name only — a depth-blind lookup would grab nested names (agent tools[0].name).
    // 只取顶层 name:深度盲查会误抓嵌套名(agent 的 tools[0].name)。
    final n = session.closedStringAt(['name']) ?? session.inFlightStringAt(['name']);
    if (n != null && n.isNotEmpty) return n;
    return '';
  }

  Widget _brow(BuildContext context, AnColors c, Translations t, String name, bool live, bool failed) {
    final subject = widget.subject;
    return SizedBox(
      height: AnSize.row,
      child: Row(children: [
        Icon(AnIcons.entityKindGlyph(subject.kind), size: AnSize.icon, color: c.inkMuted),
        const SizedBox(width: AnSpace.s6),
        Expanded(
          child: name.isEmpty
              ? AnShimmerText(subject.toolName, style: AnText.body.copyWith(color: c.inkFaint))
              : Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
        ),
        const SizedBox(width: AnSpace.s6),
        AnBadge(
          failed
              ? t.chat.stage.failed
              : live
                  ? t.chat.stage.live
                  : t.chat.stage.settled,
          tone: failed
              ? AnTone.danger
              : live
                  ? AnTone.accent
                  : AnTone.ok,
        ),
        if (widget.phase == StagePhase.pinned) ...[
          const SizedBox(width: AnSpace.s4),
          Text(t.chat.stage.pinned, style: AnText.meta.copyWith(color: c.inkFaint)),
        ],
        if (!live) ...[
          const SizedBox(width: AnSpace.s4),
          // R-14: the settled stage's handoff to the transcript anchor. 落定舞台交棒 transcript 锚。
          AnTooltip(
            message: t.chat.stage.jumpToScene,
            child: AnButton.iconOnly(
              AnIcons.locate,
              size: AnButtonSize.sm,
              semanticLabel: t.chat.stage.jumpToScene,
              onPressed: widget.onJumpAnchor,
            ),
          ),
        ],
      ]),
    );
  }

  List<Widget> _body(BuildContext context, AnColors c, ToolCardState state, PartialJsonSession session,
      bool live, bool failed) {
    // Closed TOP-LEVEL scalar args → the KV display (framework keys stripped, long values elided —
    // the full text belongs to the tail window / the bespoke stages). 闭合顶层标量 → KV(剥框架键)。
    final kv = <AnKvRow>[];
    for (final e in session.events) {
      if (e.path.length != 1 || e.path.first is! String) continue;
      final key = e.path.first as String;
      if (_frameworkKeys.contains(key)) continue;
      final v = e.value;
      if (v is Map || v is List) continue;
      var text = '$v';
      if (text.length > 80) text = '${text.substring(0, 80)}…';
      kv.add(AnKvRow(key, text));
    }
    final tail = session.inFlightString;
    return [
      if (kv.isNotEmpty) AnKv(rows: kv, dense: true),
      if (live && tail != null && tail.text.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        ToolWindow(
          child: Text(
            tailLines(tail.text, 8),
            style: AnText.code.copyWith(color: c.inkMuted),
          ),
        ),
      ],
      if (!live && !failed) ...[
        const SizedBox(height: AnSpace.s6),
        RunStatBar(state: state),
      ],
      if (failed && state.errorText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        Text(state.errorText, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.danger)),
      ],
      const SizedBox(height: AnSpace.s8),
    ];
  }
}

/// The RUNDOWN under the stage (WRK-061 §6-②): appears only when a board exists — the task-ring brow
/// (completed/total) + the read-only list; subagent boards follow with their own micro-titles.
/// 场记(舞台下沿):有清单才现——进度环眉(完成/总数)+只读清单;subagent 清单随后,各带微标题。
class _RundownSection extends ConsumerWidget {
  const _RundownSection({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final boards = ref.watch(rundownProvider(conversationId));
    final nonEmpty = [
      for (final e in boards.entries)
        if (e.value.todos.isNotEmpty) e.value,
    ]..sort((a, b) => a.subagentId.compareTo(b.subagentId)); // main ("") first 主清单在前
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    final total = nonEmpty.fold(0, (n, b) => n + b.todos.length);
    final done = nonEmpty.fold(0, (n, b) => n + b.completed);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AnSpace.s8, AnSpace.s6, AnSpace.s8, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnTaskRing(completed: done, total: total),
          const SizedBox(width: AnSpace.s6),
          Text('$done/$total', style: AnText.meta.copyWith(color: c.inkFaint)),
        ]),
        const SizedBox(height: AnSpace.s4),
        for (final board in nonEmpty) ...[
          if (board.subagentId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4, bottom: AnSpace.s2),
              child: Text(t.chat.stage.boardOf(name: board.subagentId),
                  style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
          AnRundownList(todos: board.todos),
        ],
      ]),
    );
  }
}

/// The backstage Cast — the aggregated ledger as [AnCastRow]s, with the empty state and load-more.
/// 后台演员表:聚合台账渲 AnCastRow,空态+翻页。
class _CastList extends ConsumerStatefulWidget {
  const _CastList({required this.conversationId, required this.stage});

  final String conversationId;
  final StageState stage;

  @override
  ConsumerState<_CastList> createState() => _CastListState();
}

class _CastListState extends ConsumerState<_CastList> {
  String get conversationId => widget.conversationId;
  StageState get stage => widget.stage;

  // The curtain-call landing (AnCurtainCall-lite): a clean settle's subject row takes a soft
  // accent wash that decays over ~1.8s — «the stage folded INTO this ledger row». The full
  // fly-into-row choreography stays a recorded luxury (W7 尾巴).
  // 谢幕落账(AnCurtainCall-lite):干净落定的主角行洗上柔 accent、~1.8s 衰减——「舞台收进了这行台账」。
  // 完整飞入行编舞仍是记账的奢侈项(W7 尾巴)。
  String? _curtainWash;
  Timer? _washTimer;

  @override
  void dispose() {
    _washTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(stageDirectorProvider(conversationId), (prev, next) {
      final subject = prev?.subject;
      if (prev == null || subject == null) return;
      final cleanClose = prev.stageOpen && !next.stageOpen && prev.phase != StagePhase.failedHold;
      final item = subject.itemId;
      if (!cleanClose || item == null) return;
      setState(() => _curtainWash = item);
      _washTimer?.cancel();
      _washTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _curtainWash = null);
      });
    });
    final t = Translations.of(context);
    final ledger = ref.watch(touchpointLedgerProvider(conversationId));
    if (!ledger.hydrated && ledger.loading) {
      return const Padding(padding: EdgeInsets.all(AnSpace.s8), child: AnSkeleton.row());
    }
    if (ledger.failed) {
      return AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: t.chat.stage.castEmpty,
        action: AnButton(
          label: t.chat.retry,
          size: AnButtonSize.sm,
          onPressed: () => ref.read(touchpointLedgerProvider(conversationId).notifier).retry(),
        ),
      );
    }
    if (ledger.isEmpty) {
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        icon: AnIcons.entities,
        title: t.chat.stage.castEmpty,
        hint: t.chat.stage.castEmptyHint,
      );
    }
    final subjectItem = stage.subject?.itemId;
    final entities = ledger.entities;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4, vertical: AnSpace.s4),
      itemCount: entities.length + (ledger.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= entities.length) {
          // The load-more foot — fires on becoming visible. 载更多脚,可见即拉。
          ref.read(touchpointLedgerProvider(conversationId).notifier).loadMore();
          return const Padding(
            padding: EdgeInsets.all(AnSpace.s8),
            child: AnSkeleton.row(),
          );
        }
        final e = entities[i];
        final named = e.displayName != e.key || e.byVerb.values.any((r) => r.itemName.isNotEmpty);
        final lastMessageId = e.primary.lastMessageId;
        final row = AnCastRow(
          kind: e.kind,
          name: e.displayName,
          nameIsRawId: !named,
          verb: e.primary.verb,
          count: e.primary.count,
          secondaryVerbs: [for (final r in e.secondary) r.verb],
          lastAt: e.primary.lastAt,
          tombstoned: e.tombstoned,
          pulsing: subjectItem != null && subjectItem == e.key,
          // Tap = pin the exhibit (settled-truth stage, no tool block needed). 点行=钉展品。
          onTap: () => ref.read(exhibitProvider(conversationId).notifier).pin(ExhibitSubject(
                kind: e.kind,
                id: e.key,
                name: e.displayName,
                lastMessageId: lastMessageId,
                tombstoned: e.tombstoned,
              )),
          // 「跳到发生处」— '' lastMessageId hides it (the contract's own rule). 空即藏。
          onJump: lastMessageId.isEmpty
              ? null
              : () => ref
                  .read(transcriptJumpProvider(conversationId).notifier)
                  .request(lastMessageId),
          // 「去实体页」— hidden for kinds without a panel (the pill rule). 无面板即藏。
          onNav: hasPanelFor(e.kind) && !e.tombstoned
              ? () => toolNavTo(context, e.kind, e.key)
              : null,
        );
        if (e.key != _curtainWash) return row;
        // The landing wash — reduced motion collapses to the end state instantly. 落账洗亮。
        return TweenAnimationBuilder<double>(
          key: ValueKey('curtain-${e.key}'),
          tween: Tween(begin: 1, end: 0),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 1800),
          curve: Curves.easeOut,
          builder: (context, wash, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.accentSoft
                  .withValues(alpha: context.colors.accentSoft.a * wash),
              borderRadius: BorderRadius.circular(AnRadius.button),
            ),
            child: child,
          ),
          child: row,
        );
      },
    );
  }
}

/// The follow-mode three-notch menu on the sidestage head — the standing «AI 干活自动登台» consent.
/// 侧幕头带跟随三档菜单——「AI 干活自动登台」的常设授权。
class _FollowMenu extends ConsumerWidget {
  const _FollowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final mode = ref.watch(followModeProvider);
    String word(FollowMode m) => switch (m) {
          FollowMode.always => t.chat.stage.follow.always,
          FollowMode.firstPerConversation => t.chat.stage.follow.first,
          FollowMode.never => t.chat.stage.follow.never,
        };
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnTooltip(
        message: '${t.chat.stage.follow.label} · ${word(mode)}',
        child: AnButton.iconOnly(
          AnIcons.eye,
          size: AnButtonSize.sm,
          semanticLabel: '${t.chat.stage.follow.label} · ${word(mode)}',
          onPressed: toggle,
        ),
      ),
      entries: [
        AnMenuSection(t.chat.stage.follow.label),
        for (final m in FollowMode.values)
          AnMenuItem(
            label: word(m),
            checked: mode == m,
            onTap: () => ref.read(followModeProvider.notifier).set(m),
          ),
      ],
    );
  }
}

/// The live run scroll of a poll-type stage: the flowrun's node ticks, newest last — node id in
/// mono, a status word, the taken `port` as a quiet accent badge; the durable terminal closes the
/// scroll with one honest line. Bounded to the last 12 rows (enterprise calm, not a firehose).
///
/// poll 型舞台的活运行卷:flowrun 节点 tick 新者在后——节点 id mono、状态词、选中 `port` 一枚安静
/// accent 徽;durable 终态以一行诚实收卷。只留末 12 行(企业级的静,不做火喉)。
class _RunProgressSection extends ConsumerWidget {
  const _RunProgressSection({required this.blockId});

  final String blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final progress = ref.watch(flowrunProgressProvider(blockId));
    if (progress == null) return const SizedBox.shrink();
    final rows = progress.ticks.length > 12
        ? progress.ticks.sublist(progress.ticks.length - 12)
        : progress.ticks;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (rows.isEmpty && progress.terminal.isEmpty)
          AnShimmerText(t.chat.stage.run.queued,
              style: AnText.meta.copyWith(color: c.inkFaint), reveal: true),
        for (final n in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
            child: Row(children: [
              Icon(
                switch (n.status) {
                  'completed' => AnIcons.success,
                  'failed' => AnIcons.error,
                  _ => AnIcons.circle, // parked 等待
                },
                size: AnSize.iconSm - 2,
                color: switch (n.status) {
                  'completed' => c.ok,
                  'failed' => c.danger,
                  _ => c.warn,
                },
              ),
              const SizedBox(width: AnSpace.s6),
              Expanded(
                child: Text(
                  n.iteration > 0 ? '${n.nodeId} · ${n.iteration}' : n.nodeId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.mono.copyWith(color: c.inkMuted),
                ),
              ),
              if (n.status == 'parked') ...[
                const SizedBox(width: AnSpace.s6),
                Text(t.chat.stage.run.parked, style: AnText.meta.copyWith(color: c.warn)),
              ],
              if (n.port.isNotEmpty) ...[
                const SizedBox(width: AnSpace.s6),
                AnBadge('→ ${n.port}', tone: AnTone.accent),
              ],
            ]),
          ),
        if (progress.terminal.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s4),
          Text(
            switch (progress.terminal) {
              'completed' => t.chat.stage.run.done,
              'failed' => t.chat.stage.run.failed,
              _ => t.chat.stage.run.cancelled,
            },
            style: AnText.meta.copyWith(
                color: switch (progress.terminal) {
              'completed' => c.ok,
              'failed' => c.danger,
              _ => c.inkFaint,
            }),
          ),
        ],
      ]),
    );
  }
}
