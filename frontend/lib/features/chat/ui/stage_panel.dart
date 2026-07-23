import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/contract/touchpoint.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/model/partial_json.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/perf/value_listenable_selector.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../model/stage_director.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../state/conversation_stream_provider.dart';
import '../state/pending_interactions_provider.dart';
import '../state/rundown_provider.dart';
import '../state/stage_director_provider.dart';
import '../state/stage_expansion.dart';
import '../state/stage_group_collapse.dart';
import '../state/touchpoint_ledger.dart';
import 'stages/attachment_pedestal.dart';
import 'stages/scene_from_truth.dart';
import 'stages/stage_frame.dart';
import 'stages/stage_registry.dart';
import 'stages/stage_scene.dart';
import 'stages/subagent_stage.dart';
import 'tool_card_skins.dart';
import '../../../core/run/flowrun_progress.dart';

/// The SIDESTAGE (WRK-061 · rebuilt WRK-064) — the chat right island's content, now a STICKY ACCORDION
/// LIST: the unified head (label · follow · expand/collapse-all · ✕) over one scroll where every touchpoint
/// (the R-2 ledger entity) is a left-island [AnRow] that expands IN PLACE to the carefully-built kind stage.
/// A todo board pins as row zero (a progress-ring lead). A LIVE activity auto-expands its own row + scrolls
/// it into view ONCE — the director's single-subject arbitration is the "which one auto-opens" signal, so
/// parallel tool calls never make the viewport jump; a user who grabs the scroll is never fought (§4 rules).
///
/// 侧幕(重构):chat 右岛内容=**粘性手风琴列表**。统一头 + 单滚:每个 touchpoint(R-2 台账实体)是一条左岛 AnRow,
/// 就地展开精心做的 kind 舞台;todo 板置顶为第 0 行(进度环 lead)。live 活动自动展开自身行 + 滚入一次——导演器
/// 单主角仲裁=「自动展开谁」的信号,并行 tool call 绝不让视口跳;用户接管滚动绝不抢(§4)。
class StagePanel extends ConsumerWidget {
  const StagePanel({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    // The a11y four announcements (WRK-061 §11): staging / human gate / failure / settle — polite
    // interruptions for screen-reader users who cannot see the silent auto-expands. a11y 四播报。
    ref.listen(stageDirectorProvider(conversationId), (prev, next) {
      if (prev == null) return;
      final t2 = Translations.of(context);
      // HUMAN words for the screen reader (G11/A2-20): the ledger's display name when the entity is
      // known, else the tool name — never a bare 16-hex id read aloud. 播报人话:台账显示名→工具名,
      // 绝不裸读 16 进制 id。
      String subjectWord(StageActivityView? a) {
        if (a == null) return '';
        final id = a.itemId;
        if (id != null && id.isNotEmpty) {
          final led = ref.read(touchpointLedgerProvider(conversationId));
          for (final e in led.entities) {
            if (e.kind == a.kind && e.key == id) return e.displayName;
          }
        }
        return a.toolName;
      }

      void announce(String msg) => AnA11y.announce(context, msg);
      if (next.subject != null &&
          (prev.subject?.blockId != next.subject!.blockId ||
              (!prev.stageOpen && next.stageOpen))) {
        announce(t2.chat.stage.a11y.staged(name: subjectWord(next.subject)));
      }
      if (!prev.gateWaiting && next.gateWaiting) {
        announce(t2.chat.stage.a11y.gate);
      }
      if (prev.phase != StagePhase.failedHold &&
          next.phase == StagePhase.failedHold) {
        announce(t2.chat.stage.a11y.failed);
      }
      if (prev.stageOpen &&
          !next.stageOpen &&
          prev.phase != StagePhase.failedHold) {
        announce(t2.chat.stage.a11y.settled(name: subjectWord(prev.subject)));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // §1 身份头 + §2 速览带(三段式文法, 0719): the activity/pulse identity glyph + title, EVERY panel action
        // collapsed into ONE ⋯ (the retired「四钮杂」: follow three-notch · expand-all · collapse-all), a quiet
        // glance strip below (触点·执行·待你处理,零人话律=有信号才在), then the first-class ✕. 身份头收编 ⋯ + 速览带。
        AnPanelHead(
          icon: AnIcons.activity,
          title: t.chat.stage.island,
          menuEntries: _panelMenuEntries(context, ref, conversationId),
          menuSemanticLabel: t.a11y.moreActions,
          sub: _glance(context, ref, conversationId),
          // ✕ collapses the right island (unified across every island, WRK-064). ✕ 收岛(统一)。
          onClose: () =>
              ref.read(rightPanelCollapsedProvider.notifier).set(true),
          closeSemantics: t.shell.togglePanel,
        ),
        Expanded(child: _AccordionList(conversationId: conversationId)),
      ],
    );
  }
}

/// The head ⋯ overflow (三段式文法 §1 — every panel action collapses here): the follow three-notch (a checked
/// single-select radio group) then «展开全部» / «收起全部». Reads [followModeProvider] so the checks are live
/// on the NEXT open (items close on pick). «展开全部» ALSO reveals every collapsed group (openAll) so no row
/// expands behind a folded head; «收起全部» folds the row BODIES only (group heads + row heads stay — behavior-
/// equivalent to the retired button). 头 ⋯:跟随三档(单选勾)+ 展开/收起全部;展开全部顺手掀组,收起全部只收行体。
List<AnMenuEntry> _panelMenuEntries(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) {
  final t = Translations.of(context);
  final mode = ref.watch(followModeProvider);
  String word(FollowMode m) => switch (m) {
    FollowMode.always => t.chat.stage.follow.always,
    FollowMode.firstPerConversation => t.chat.stage.follow.first,
    FollowMode.never => t.chat.stage.follow.never,
  };
  return [
    AnMenuSection(t.chat.stage.follow.label),
    for (final m in FollowMode.values)
      AnMenuItem(
        label: word(m),
        checked: mode == m,
        onTap: () => ref.read(followModeProvider.notifier).set(m),
      ),
    AnMenuItem(
      label: t.chat.stage.expandAll,
      icon: AnIcons.unfold,
      onTap: () {
        // «Expand ALL» includes the TOP region (G11/A2-14): the old list only covered todo+ledger
        // and skipped the very rows the user most wants — live activities and settled delegates.
        // 展开全部含 top 区:旧清单只盖 todo+台账,恰漏最想看的活动层与落定分身行。
        final ledger = ref.read(touchpointLedgerProvider(conversationId));
        final stage = ref.read(stageDirectorProvider(conversationId));
        final tx = ref
            .read(conversationStreamProvider(conversationId).notifier)
            .transcript
            .value;
        ref
            .read(stageGroupCollapseProvider(conversationId).notifier)
            .openAll(); // reveal folds first 先掀组
        ref
            .read(stageExpansionProvider(conversationId).notifier)
            .expandAll(_allRowIds(stage, ledger, tx));
      },
    ),
    AnMenuItem(
      label: t.chat.stage.collapseAll,
      icon: AnIcons.fold,
      onTap: () => ref
          .read(stageExpansionProvider(conversationId).notifier)
          .collapseAll(),
    ),
  ];
}

/// EVERY visible rowId, all three sources (G11/A2-14) — the single derivation «expand all» shares
/// with the accordion so the two never drift. 全部可见 rowId(三源同一条派生,菜单与手风琴不漂移)。
List<String> _allRowIds(
  StageState stage,
  TouchpointLedgerState ledger,
  ConversationTranscript tx,
) {
  String ridOf(StageActivityView v) {
    final id = v.itemId;
    return (id != null && id.isNotEmpty)
        ? '${v.kind}:$id'
        : 'block:${v.blockId}';
  }

  final ids = <String>{'todo'};
  if (stage.stageOpen && stage.subject != null) ids.add(ridOf(stage.subject!));
  for (final ch in stage.channels) {
    ids.add(ridOf(ch));
  }
  for (final n in tx.subagentBlocks) {
    if (!n.isOpen) ids.add('block:${n.id}');
  }
  for (final e in ledger.entities) {
    ids.add('${e.kind}:${e.key}');
  }
  return ids.toList(growable: false);
}

/// The §2 GLANCE STRIP — one quiet [AnText.meta] line of `N 触点 · M 执行 · K 待你处理`, each segment present
/// ONLY when its count > 0 (零人话律 = signal-only, never padded with zeros); ALL zero → null (no band). N =
/// distinct things touched (the Cast size, `ledger.entities.length`); M = distinct things EXECUTED (entities
/// carrying a `deleted`-free `executed` verb row); K = interactions still awaiting the user
/// ([pendingInteractionsProvider]). Returns null → [AnPanelHead] draws no sub band. 速览带:有信号才在,全零→null。
Widget? _glance(BuildContext context, WidgetRef ref, String conversationId) {
  final c = context.colors;
  final t = Translations.of(context);
  final ledger = ref.watch(touchpointLedgerProvider(conversationId));
  final pending = ref.watch(pendingInteractionsProvider(conversationId));
  final n = ledger.entities.length;
  // M skips tombstones as the doc comment always claimed (G11/A2-15). M 按注释豁免墓碑。
  final m = ledger.entities
      .where(
        (e) => !e.tombstoned && e.byVerb.containsKey(TouchpointVerb.executed),
      )
      .length;
  // K counts only interactions WITH a sidestage landing — a bare ask_user renders inline in the
  // transcript (§0 excludes it from existence), so counting it said «1 待你处理» over an island
  // with no such row (G11/A2-15). K 只数有侧幕落点的交互:裸 ask_user 内联渲于对话流,计它=速览带
  // 报「1 待你处理」而岛上无行可寻。
  final k = pending.values
      .where((r) => r.isAwaiting && r.interaction.kind != InteractionKind.ask)
      .length;
  final segs = <String>[
    if (n > 0) t.chat.stage.glanceTouched(n: n),
    if (m > 0) t.chat.stage.glanceExecuted(n: m),
    if (k > 0) t.chat.stage.glanceNeedsYou(n: k),
  ];
  if (segs.isEmpty) return null;
  return Text(
    segs.join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AnText.meta.copyWith(color: c.inkFaint),
  );
}

/// One accordion row's spec — a ledger [entity] and/or a [view] (the live activity overlaying it), OR a
/// settled [subagentNode] (a closed `Subagent` run rehydrated from the transcript — no touchpoint, no
/// ledger row, WRK-064 B6). A pure-live row (no ledger yet) has [entity] null; a settled entity row has
/// [view] null; a settled subagent row has both null and [subagentNode] set. 一行的规格。
class _RowSpec {
  const _RowSpec({
    required this.rowId,
    this.entity,
    this.view,
    this.subagentNode,
    this.liveCount = 0,
  });

  final String rowId;
  final CastEntity? entity;
  final StageActivityView? view;

  /// Parallel live calls aimed at this same entity. The row renders one coherent target, never five
  /// duplicate cards; its compact count says that work is fanned out underneath. 同一实体的并行活调用数；
  /// 一行只代表一个目标，不炸五张重复卡，计数诚实说明其下有并发工作。
  final int liveCount;

  /// A closed subagent tool_call (folded nested trajectory) — the settled subagent row's whole payload.
  /// 落定 subagent 的折好节点(整行载荷)。
  final BlockNode? subagentNode;

  /// The row head's honest state (G3) — derived from the ACTIVITY VIEW's own truth, never from «the
  /// director still remembers it» (that alias rendered failed / breathing / poll-held rows as a blue
  /// «Live» forever). 行头四态(G3):从活动视图自身真相派生——「导演器还记着」曾把失败/停拍/poll 驻留
  /// 全渲成永恒蓝色「进行中」。
  _RowState get state {
    final v = view;
    if (v == null) return _RowState.settled;
    if (v.failed) return _RowState.failed;
    if (v.live) return _RowState.live;
    return v.poll ? _RowState.polling : _RowState.settling;
  }
}

/// live = streaming/executing · polling = closed receipt, flowrun still running (R-10) · settling =
/// the 1.8s breath before the curtain · failed = red hold (row offers the clear exit) · settled =
/// no view left. G3 四态+落定。
enum _RowState { live, polling, settling, failed, settled }

/// The accordion list itself — the scroll + the §4 follow rules (auto-expand once per live block, scroll it
/// into view only when off-screen, never steal a user-held scroll). 手风琴列表:滚动 + §4 跟随规则。
class _AccordionList extends ConsumerStatefulWidget {
  const _AccordionList({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_AccordionList> createState() => _AccordionListState();
}

class _AccordionListState extends ConsumerState<_AccordionList> {
  final ScrollController _scroll = ScrollController();

  /// The tier clock (G11/A2-12): time bucketing used to snapshot `DateTime.now()` at build — rows
  /// froze in «刚刚» on an idle conversation, then the whole grouping JUMPED on the next unrelated
  /// rebuild. One quiet re-bucket per minute, no animation of its own (the tier reveal animates).
  /// 分档钟:旧 build 快照让静置会话冻在「刚刚」、下次无关重建时整组突跳;每分钟安静重分桶一次。
  Timer? _tierClock;

  @override
  void initState() {
    super.initState();
    _tierClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Live blocks already auto-opened once — each live activity claims the viewport at most once (§4-2).
  /// 已自动展开过的 live block(每 live 一生一次)。
  final Set<String> _autoHandled = {};

  /// 缺口B (0719) — the rowId each auto-opened subject expanded, so when the director CURTAINS that subject
  /// (settle → breath → dismiss) we collapse EXACTLY the row we opened (never a row the user expanded). Keyed
  /// by the subject's blockId; migrated when the itemId resolves. 自动展开行(供谢幕收起,只收自己开的)。
  final Map<String, String> _autoOpenedRow = {};

  /// The user grabbed the scroll → suspend all auto-scroll until they return to the bottom (§4-3).
  /// 用户接管滚动 → 挂起自动滚,回底才恢复。
  bool _takeover = false;

  /// Per-row keys for [Scrollable.ensureVisible]. 每行 key(用于滚入视口)。
  final Map<String, GlobalKey> _rowKeys = {};

  // The settled-subagent rows (WRK-064 B6) come from the transcript, which the director / ledger the list
  // watches do NOT track — a reload folds subagents in, a scroll pages more, neither firing a watched
  // provider. Subscribe to the transcript coalescer and rebuild ONLY when the subagent structure changes
  // — the transcript maintains [ConversationTranscript.subagentEpoch] at its write sites (S7), so this is
  // ONE int compare per coalesced frame (the old signature string re-walked the whole tree + allocated
  // every frame). 订阅 transcript,仅 subagent 结构变化才重建——比对写入点维护的 epoch(S7,每帧一个 int;
  // 旧签名串每帧全树重走+分配)。
  CoalescingNotifier<ConversationTranscript>? _tx;
  int _subagentEpoch = -1;

  String get conversationId => widget.conversationId;

  void _syncTranscript(CoalescingNotifier<ConversationTranscript> tx) {
    if (identical(tx, _tx)) return;
    _tx?.removeListener(_onTranscript);
    _tx = tx;
    tx.addListener(_onTranscript);
    _subagentEpoch = tx.value.subagentEpoch;
  }

  void _onTranscript() {
    final tx = _tx;
    if (tx == null) return;
    final epoch = tx.value.subagentEpoch;
    if (epoch != _subagentEpoch && mounted) {
      setState(() => _subagentEpoch = epoch);
    }
  }

  @override
  void didUpdateWidget(_AccordionList old) {
    super.didUpdateWidget(old);
    // The shell mounts StagePanel WITHOUT a per-conversation key, so this State is REUSED across a
    // conversation switch while the per-conversation providers (director / expansion) rebuild. Reset the
    // scroll-follow bookkeeping so a stale takeover / auto-open set from thread A never governs thread B.
    // 壳不按会话给 key → 切会话时本 State 复用而 provider 重建;重置滚动跟随记账,免 A 的残留管到 B。
    if (old.conversationId != widget.conversationId) {
      _takeover = false;
      _autoHandled.clear();
      _autoOpenedRow.clear();
      _rowKeys.clear();
    }
  }

  @override
  void dispose() {
    _tierClock?.cancel();
    _tx?.removeListener(_onTranscript);
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String rowId) =>
      _rowKeys.putIfAbsent(rowId, () => GlobalKey());

  // §4-3 — a USER-initiated scroll (direction ≠ idle) suspends auto-scroll; returning near the bottom
  // resumes it. ScrollUpdateNotification is NEVER treated as takeover (else a programmatic ensureVisible
  // would self-lock). Depth-gated (G2/A2-19): only the accordion's OWN scrollable counts — a nested
  // scroll inside an expanded stage body (code window, live tail) bubbles up with depth > 0 and must
  // not flip the takeover. 用户手动滚即挂起,回底恢复;update 帧不当接管;仅认 depth==0——体内嵌套滚动
  // 冒泡不得翻 takeover(G2/A2-19)。
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
      _takeover = true;
    } else if (n is ScrollEndNotification && _isNearTop) {
      _takeover = false;
    }
    return false;
  }

  // G2 — engaging a stage body (tap / drag inside it) CLAIMS the row for the user: it leaves the
  // auto-opened ledger, so the curtain never collapses a row someone is reading — while the director
  // keeps flowing (the retired camera lock froze the whole follow pipeline behind an exit no UI
  // offered). G2:体内交互=用户认领本行——移出自动展开账本,谢幕绝不收正在读的行;导演器照常流动
  // (退役的镜头锁曾把整条流水线冻死在无出口的 pinned 里)。
  void _claimRow(String rowId) {
    _autoOpenedRow.removeWhere((_, row) => row == rowId);
  }

  // The list is TOP-anchored (todo + live rows ride offset≈0; the oldest ledger + load-more foot sit at the
  // bottom), so auto-follow re-arms when the user returns to the TOP — where live activity lands — NOT the
  // bottom (that would demand scrolling past every paged-in old entity to re-arm). 顶锚列表:回顶即重武装。
  bool get _isNearTop {
    if (!_scroll.hasClients) return false;
    final p = _scroll.position;
    if (!p.hasContentDimensions) return false;
    return p.pixels <=
        p.minScrollExtent + 80; // threshold, never atEdge/exact 阈值,不用 atEdge
  }

  // §4-1/§4-2 — the director staged a NEW subject (follow already gated it): open its row (sticky) and
  // scroll it into view ONCE. Also migrate the expansion key when a subject's itemId finally resolves
  // (block:<id> → kind:<itemId>) so the auto-opened row stays open across the key change.
  // 导演器登了新主角(follow 已放行):展开其行(粘性)+ 滚入视口一次;itemId 解出时迁移展开键。
  void _onDirector(StageState? prev, StageState next) {
    final expNotifier = ref.read(
      stageExpansionProvider(conversationId).notifier,
    );

    // G7① — key migration for EVERY tracked view, subject or channel (A2-7: it used to run for the
    // subject only, so a user-opened channel row snapped shut the instant its itemId resolved).
    // block:<blockId> → kind:<itemId>, expansion + the auto-opened ledger move together.
    // G7①:全员键迁移(旧只迁 subject——用户展开的频道行在 itemId 解出瞬间当面合上)。
    final nextViews = [
      if (next.subject != null) next.subject!,
      ...next.channels,
    ];
    for (final v in nextViews) {
      final id = v.itemId;
      if (id == null || id.isEmpty) continue;
      final blockRow = 'block:${v.blockId}';
      final resolvedRow = '${v.kind}:$id';
      final exp = ref.read(stageExpansionProvider(conversationId));
      if (exp.contains(blockRow) && !exp.contains(resolvedRow)) {
        expNotifier.close(blockRow);
        expNotifier.open(resolvedRow);
      }
      if (_autoOpenedRow[v.blockId] == blockRow) {
        _autoOpenedRow[v.blockId] = resolvedRow;
      }
    }

    // G7② — PER-ACTIVITY curtain (A1-9/A2-9: the old trigger was «subject became null», which only
    // covered the last act — every handoff A→B left A's auto-opened row standing and the ledger
    // leaked until the island was a wall of open stages). An activity that LEFT the director
    // (settled clean, cleared, realign-swept) ends its auto-show: collapse exactly the row WE
    // opened. A still-live displaced subject stays in channels → untouched; user-opened rows were
    // never claimed → untouched. G7②:按活动个体谢幕——旧「subject 变 null」只盖最后一幕,每次接场
    // 都漏收、右岛渐成全展开墙;离场活动收自己那行,被挤而仍活的在 channels 不收,用户行从未认领不收。
    if (prev != null) {
      final nextIds = {for (final v in nextViews) v.blockId};
      for (final v in [
        if (prev.subject != null) prev.subject!,
        ...prev.channels,
      ]) {
        if (nextIds.contains(v.blockId)) continue;
        final row = _autoOpenedRow.remove(v.blockId);
        if (row != null) expNotifier.close(row);
      }
    }

    // §4-1/§4-2 — auto-open the NEW subject once; NEVER claim a row the user already opened
    // (G7/A2-8: claiming it put THEIR row on the curtain's collapse list). 自动展开新主角一次;
    // 用户已开的行绝不认领(旧认领会让谢幕收走用户的行)。
    final subj = next.subject;
    if (subj == null) return;
    final block = subj.blockId;
    if (!next.stageOpen || _autoHandled.contains(block)) return;
    _autoHandled.add(block);
    final id = subj.itemId;
    final rowId = (id != null && id.isNotEmpty)
        ? '${subj.kind}:$id'
        : 'block:$block';
    if (ref.read(stageExpansionProvider(conversationId)).contains(rowId)) {
      _scrollToRow(rowId); // convenience scroll, no claim 顺手滚入,不认领
      return;
    }
    expNotifier.open(rowId);
    _autoOpenedRow[block] = rowId;
    _scrollToRow(rowId);
  }

  void _scrollToRow(String rowId) {
    if (_takeover) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _takeover || !_scroll.hasClients) return;
      final ctx = _rowKeys[rowId]?.currentContext;
      if (ctx == null) {
        return; // not built = far off-screen → don't chase (§4-2) 未构建=远在视口外,不追
      }
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final viewport = RenderAbstractViewport.of(box);
      final lead = viewport.getOffsetToReveal(box, 0.0).offset;
      final trail = viewport.getOffsetToReveal(box, 1.0).offset;
      final px = _scroll.position.pixels;
      // Already fully visible (row shorter than the viewport, current offset between the two reveals) → skip.
      // 已完整可见 → 不动。
      if (lead >= trail && px >= trail && px <= lead) return;
      Scrollable.ensureVisible(
        ctx,
        alignment:
            0.5, // centre-reveal, so it never brushes the bottom edge + re-arms follow 居中揭示
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: AnMotion.mid,
        // ensureVisible scroll = double-ended easing — the ONE legislated curve exemption
        // (批7 立法2). 滚动双端缓动=成文豁免。
        curve: Curves.easeInOut,
      );
    });
  }

  /// Split the sidestage into its TWO regions (三段式文法 §3): [top] = the ACTIVE / DELEGATED layer (synthetic
  /// live rows + settled subagent runs) that always rides UNGROUPED above the fold — so the director's
  /// auto-expand + the「live rides on top」invariant never fight a group; [ledger] = the SETTLED Cast that
  /// [_computeItems] buckets into time tiers. 拆两区:top=活/委派层(合成 live+落定 subagent)恒不分组置顶;
  /// ledger=落定 Cast(下由 _computeItems 按时间档分组)。
  ({List<_RowSpec> top, List<_RowSpec> ledger}) _computeRows(
    StageState stage,
    TouchpointLedgerState ledger,
    ConversationTranscript transcript,
  ) {
    // Live activities by rowId (resolved itemId → kind:itemId; else block:<blockId> so it still shows +
    // can be auto-expanded — resolving migrates the key). 活动按 rowId(未解出用 blockId 键)。
    final viewByRow = <String, StageActivityView>{};
    final liveCountByRow = <String, int>{};
    void addView(StageActivityView? a, {required bool gate}) {
      if (a == null || (gate && !stage.stageOpen)) return;
      final id = a.itemId;
      final rid = (id != null && id.isNotEmpty)
          ? '${a.kind}:$id'
          : 'block:${a.blockId}';
      viewByRow.putIfAbsent(
        rid,
        () => a,
      ); // subject added first wins its slot 主角先占
      // Only LIVE calls count toward «N running» (G3/A1-20) — a settled/failed view held by the
      // director is not running work. 只数活的:导演器还捏着的已关视图不算「正在执行」。
      if (a.live) liveCountByRow[rid] = (liveCountByRow[rid] ?? 0) + 1;
    }

    addView(stage.subject, gate: true);
    for (final ch in stage.channels) {
      addView(ch, gate: false);
    }

    final top = <_RowSpec>[];
    final ledgerRows = <_RowSpec>[];
    final ledgerKeys = {for (final e in ledger.entities) '${e.kind}:${e.key}'};
    // Synthetic live rows (a live activity with no ledger row yet) ride on top, in insertion order
    // (subject first). 合成 live 行置顶(主角先)。
    for (final entry in viewByRow.entries) {
      if (!ledgerKeys.contains(entry.key)) {
        top.add(
          _RowSpec(
            rowId: entry.key,
            view: entry.value,
            liveCount: liveCountByRow[entry.key] ?? 0,
          ),
        );
      }
    }
    // Third source (WRK-064 B6): SETTLED subagent runs. A `Subagent` tool_call has no touchpoint (never a
    // ledger row); once CLOSED and its director channel dropped, list it here with its folded nested
    // trajectory. LIVE subagents ride the director path above (same `block:<id>` rowId → the row stays put
    // through its settle, zero jump); skip any rowId a live view / ledger already covers. Kept in the top
    // region beside the synthetic live rows so a live→settled transition never relocates the row.
    // 第三源:落定 subagent(无触点无 ledger)——谢幕后按 block:<id> 列此,同 live 合成行键→归队零跳。
    for (final node in transcript.subagentBlocks) {
      if (node.isOpen) {
        continue; // a live subagent is the director's job 活的归 director
      }
      final rid = 'block:${node.id}';
      if (viewByRow.containsKey(rid) || ledgerKeys.contains(rid)) continue;
      top.add(_RowSpec(rowId: rid, subagentNode: node));
    }
    // The settled Cast, freshest-first (the ledger's own sort) — time-tier grouped downstream. 落定 Cast(最新先)。
    for (final e in ledger.entities) {
      final rowID = '${e.kind}:${e.key}';
      ledgerRows.add(
        _RowSpec(
          rowId: rowID,
          entity: e,
          view: viewByRow[rowID],
          liveCount: liveCountByRow[rowID] ?? 0,
        ),
      );
    }
    return (top: top, ledger: ledgerRows);
  }

  /// The flat display list (三段式文法 §3, 用户 0719 改判 kind→时间档——kind 轴 12 条 10 头「目录病」被否决):
  /// todo (row 0) · the ungrouped [top] active layer · then the settled Cast bucketed into three TIME tiers by
  /// each row's last-touched time (刚刚 = the current turn / a fixed 10-min window; 早些时候 = earlier today;
  /// 更早 = past days), each a [_TierItem] (head + its rows under one collapse [AnExpandReveal]) · then the
  /// load-more foot. **Two anti-fragmentation rules**: an empty tier is absent; a SINGLE non-empty tier draws
  /// NO head at all — [_EntityItem] BARE rows (an all-刚刚 list needs no scaffolding, 零人话律; short threads
  /// stay a clean column, long ones auto-layer). A tier FORCE-OPENS (never hides live / auto-expanded work)
  /// when it holds a live row or a row the director/deep-jump has expanded — flipping `open` so the reveal
  /// animates the same slide (§3 test-lock). 按最后触碰时间分三档;空档免头、单档全裸行;含 live/展开行的档强制
  /// 展开(翻 open→播同一滑动)。
  List<_Item> _computeItems(
    StageState stage,
    TouchpointLedgerState ledger,
    ConversationTranscript transcript,
    Set<String> expanded,
    Set<String> collapsed,
    bool hasTodo,
  ) {
    final split = _computeRows(stage, ledger, transcript);
    final items = <_Item>[];
    if (hasTodo) items.add(const _TodoItem());
    for (final s in split.top) {
      items.add(_TopItem(s));
    }
    // Bucket into the three time tiers by lastAt (each list stays freshest-first — the ledger's own
    // sort); `now` rides the per-minute tier clock (G11/A2-12). 按 lastAt 分三档;now 走分钟钟。
    final now = DateTime.now();
    final tiers = {for (final k in stageTierOrder) k: <_RowSpec>[]};
    for (final s in split.ledger) {
      tiers[sidestageTierKey(s.entity!.lastAt, now)]!.add(s);
    }
    final nonEmpty = [
      for (final k in stageTierOrder)
        if (tiers[k]!.isNotEmpty) k,
    ];
    // A single non-empty tier → bare rows, no heads (anti-目录病). 单档=裸行、无头。
    final grouped = nonEmpty.length > 1;
    for (final tierKey in nonEmpty) {
      final group = tiers[tierKey]!;
      if (grouped) {
        // The whole tier (head + rows) is ONE list item so the fold rides a single [AnExpandReveal] (the kit
        // standard collapse slide); force-open covers ACTIVE rows and rows WE auto-opened — never a
        // row the USER expanded (G11/A2-13: the old whole-expanded-set test let one user-opened row
        // lock the tier unfoldable, and the moment it closed the stale collapse token slammed the
        // tier shut uninvited). 整档一 item;强制展开=活动行∪自动展开行——绝不含用户自展行(旧口径
        // 让一条用户行锁死档折叠,行一收、残留折叠令又让档自动合拢)。
        final autoRows = ref
            .read(stageExpansionProvider(conversationId).notifier)
            .autoOpened;
        final forced = group.any(
          (s) => s.view != null || autoRows.contains(s.rowId),
        );
        final open = forced || !collapsed.contains(tierKey);
        items.add(_TierItem(tierKey: tierKey, rows: group, open: open));
      } else {
        for (final s in group) {
          items.add(_EntityItem(s));
        }
      }
    }
    if (ledger.hasMore) items.add(const _FootItem());
    // The MIXED failure face (G11/A2-16): the ledger's first fetch failed while other sources have
    // content — the old all-or-nothing error face never showed, so the Cast just silently missed.
    // 混合失败面:台账首拉失败而他源有内容——旧全有全无错误面永不出现,历史触点静默缺失。
    if (ledger.failed && ledger.entities.isEmpty && items.isNotEmpty) {
      items.add(const _LedgerFailItem());
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(stageDirectorProvider(conversationId), _onDirector);
    final t = Translations.of(context);
    final stage = ref.watch(stageDirectorProvider(conversationId));
    final ledger = ref.watch(touchpointLedgerProvider(conversationId));
    final expanded = ref.watch(stageExpansionProvider(conversationId));
    final collapsed = ref.watch(stageGroupCollapseProvider(conversationId));
    final boards = ref.watch(rundownProvider(conversationId));
    final transcript = ref
        .watch(conversationStreamProvider(conversationId).notifier)
        .transcript;
    _syncTranscript(transcript);

    final hasTodo = boards.values.any((b) => b.todos.isNotEmpty);
    final items = _computeItems(
      stage,
      ledger,
      transcript.value,
      expanded,
      collapsed,
      hasTodo,
    );

    // Empty / loading / failed — only when there's nothing to show at all (no group, no todo, no live/foot).
    // 空/加载/失败:仅当全无(无组、无 todo、无 live/脚)。
    if (items.isEmpty) {
      if (!ledger.hydrated && ledger.loading) {
        return const Padding(
          padding: EdgeInsets.all(AnSpace.s8),
          child: AnSkeleton.row(),
        );
      }
      if (ledger.failed) {
        return AnState(
          kind: AnStateKind.error,
          size: AnStateSize.inset,
          title: t.chat.stage.castEmpty,
          action: AnButton(
            label: t.chat.retry,
            size: AnButtonSize.sm,
            onPressed: () => ref
                .read(touchpointLedgerProvider(conversationId).notifier)
                .retry(),
          ),
        );
      }
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        icon: AnIcons.entities,
        title: t.chat.stage.castEmpty,
        hint: t.chat.stage.castEmptyHint,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        controller: _scroll,
        // No horizontal pad — the [AnIsland]'s 12px is the sole island inset (single-source law), so each
        // accordion AnRow洗底 flush to the island pad edge like the LEFT island's rail rows (island 12 + row
        // s8 = text at 20). 水平 0:岛壳 12 即唯一岛级内距,行洗底到 pad 缘,与左岛逐像素同几何。
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            _buildItem(context, items[i], expanded, transcript),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    _Item item,
    Set<String> expanded,
    CoalescingNotifier<ConversationTranscript> transcript,
  ) {
    switch (item) {
      case _TodoItem():
        return KeyedSubtree(
          key: _keyFor('todo'),
          child: _TodoRow(
            conversationId: conversationId,
            open: expanded.contains('todo'),
          ),
        );
      // A ungrouped active-layer row (live / settled subagent) OR a grouped settled Cast row — both render
      // through the same [_StageRow]; only their placement differs. 活层行与分组 Cast 行同渲,仅位置异。
      case _TopItem(:final spec) || _EntityItem(:final spec):
        return KeyedSubtree(
          key: _keyFor(spec.rowId),
          child: _StageRow(
            conversationId: conversationId,
            spec: spec,
            open: expanded.contains(spec.rowId),
            transcript: transcript,
            onEngaged: () => _claimRow(spec.rowId),
          ),
        );
      case _TierItem(:final tierKey, :final rows, :final open):
        return KeyedSubtree(
          key: _keyFor('group:$tierKey'),
          child: _buildTier(tierKey, rows, open, expanded, transcript),
        );
      case _FootItem():
        // A failed page flips the foot to an EXPLICIT retry (G11/A2-17) — the old visible-即拉 foot
        // re-fired on every rebuild, so a persistent failure hammered the backend once per frame.
        // 翻页失败→显式重试脚;旧「可见即拉」逐 rebuild 重打后端。
        final ledgerNow = ref.read(touchpointLedgerProvider(conversationId));
        if (ledgerNow.pageFailed) {
          final t = Translations.of(context);
          return Padding(
            padding: const EdgeInsets.all(AnSpace.s8),
            child: AnButton(
              label: t.chat.retry,
              size: AnButtonSize.sm,
              onPressed: () => ref
                  .read(touchpointLedgerProvider(conversationId).notifier)
                  .loadMore(),
            ),
          );
        }
        // load-more foot — fires on becoming visible, DEFERRED out of build: loadMore() synchronously
        // mutates the ledger provider this widget watches, and calling it inside itemBuilder (a build phase)
        // trips Riverpod's «modify a provider while building» guard. 载更多脚:post-frame 延迟(build 期直调触发守卫)。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(touchpointLedgerProvider(conversationId).notifier)
                .loadMore();
          }
        });
        return const Padding(
          padding: EdgeInsets.all(AnSpace.s8),
          child: AnSkeleton.row(),
        );
      case _LedgerFailItem():
        final t = Translations.of(context);
        return Padding(
          padding: const EdgeInsets.all(AnSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.feedback.cast.loadFailed,
                  style: AnText.meta.copyWith(
                    color: Theme.of(context).extension<AnColors>()!.inkFaint,
                  ),
                ),
              ),
              AnButton(
                label: t.chat.retry,
                size: AnButtonSize.sm,
                onPressed: () => ref
                    .read(touchpointLedgerProvider(conversationId).notifier)
                    .retry(),
              ),
            ],
          ),
        );
    }
  }

  /// A grouped time tier as ONE list item: the [_GroupHead] over an [AnExpandReveal] wrapping the tier's rows,
  /// so a fold/unfold — a user toggle OR a director / deep-jump force-open — rides the kit's STANDARD collapse
  /// slide (chevron rotation [AnRow] + height slide [AnExpandReveal] play together; reduced double-gated inside
  /// the reveal). LAZY (`.builder`): a collapsed tier never builds its rows — matching the pre-animation
  /// behaviour + the row-body reveal nested within (ClipRect+Align nests safely, unlike AnimatedSize). The
  /// per-row [GlobalKey]s stay put so the director's scroll-to-row still resolves once a tier is open. 分组档=
  /// 单 item:组头 + AnExpandReveal 裹行,折叠走 kit 标准滑动(chevron 旋转 + 高度滑动同播,reduced 双闸);惰性,
  /// 收起档不建行;行 GlobalKey 不变,档一开导演器滚动即命中。
  Widget _buildTier(
    String tierKey,
    List<_RowSpec> rows,
    bool open,
    Set<String> expanded,
    CoalescingNotifier<ConversationTranscript> transcript,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupHead(
          conversationId: conversationId,
          tierKey: tierKey,
          count: rows.length,
          open: open,
        ),
        AnExpandReveal.builder(
          open: open,
          childBuilder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final spec in rows)
                KeyedSubtree(
                  key: _keyFor(spec.rowId),
                  child: _StageRow(
                    conversationId: conversationId,
                    spec: spec,
                    open: expanded.contains(spec.rowId),
                    transcript: transcript,
                    onEngaged: () => _claimRow(spec.rowId),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One display-list item (三段式文法 §3) — the accordion flattens to these so index math stays honest across
/// todo / active-layer / tier-block / bare-row / foot. 展平列一项(分组后索引仍诚实)。
sealed class _Item {
  const _Item();
}

class _TodoItem extends _Item {
  const _TodoItem();
}

/// An ungrouped ACTIVE-LAYER row — a synthetic live activity or a settled subagent run, riding above the fold.
class _TopItem extends _Item {
  const _TopItem(this.spec);
  final _RowSpec spec;
}

/// A grouped time tier — its head + rows as ONE list item so the fold rides a single [AnExpandReveal].
/// [tierKey] = the [stageTierOrder] fold token; [open] is the RESOLVED state (user fold ∪ force-open).
/// 分组时间档(单 item,折叠走单 AnExpandReveal)。
class _TierItem extends _Item {
  const _TierItem({
    required this.tierKey,
    required this.rows,
    required this.open,
  });
  final String tierKey;
  final List<_RowSpec> rows;
  final bool open;
}

/// A BARE settled Cast row — the single-tier case (no head, no fold, so no reveal). 单档裸行(无头无折叠)。
class _EntityItem extends _Item {
  const _EntityItem(this.spec);
  final _RowSpec spec;
}

class _FootItem extends _Item {
  const _FootItem();
}

/// The ledger's first fetch failed while OTHER sources render (G11/A2-16) — an inline honest row,
/// never a whole-panel takeover. 台账首拉失败而他源在渲——内联诚实行,不整面接管。
class _LedgerFailItem extends _Item {
  const _LedgerFailItem();
}

/// A top-level TIME-TIER group head (三段式文法 §3, 用户 0719 改判 kind→时间档) — the settled Cast buckets by
/// last-touched time into 刚刚 / 早些时候 / 更早, the head speaking the SAME [AnRow] language as the left
/// island's Pinned/Recents heads + the notification tray's time buckets (照通知托盘): a PERMANENT lead chevron
/// (icon-free collapsible row) + a count meta, NO ⋯ — one grammar across left-island / tray / right-island.
/// Fold state lives in [stageGroupCollapseProvider] keyed by the tier token (orthogonal to the row-level sticky
/// accordion). 顶层时间档组头:常驻箭头 + 计数、无 ⋯,与左岛/托盘同一 AnRow 文法;折叠态按档 key 外置。
class _GroupHead extends ConsumerWidget {
  const _GroupHead({
    required this.conversationId,
    required this.tierKey,
    required this.count,
    required this.open,
  });

  final String conversationId;
  final String tierKey;
  final int count;
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void toggle() => ref
        .read(stageGroupCollapseProvider(conversationId).notifier)
        .toggle(tierKey);
    return AnRow(
      collapsible: true,
      open: open,
      label: _tierLabel(context, tierKey),
      meta: '$count',
      onSelect: toggle,
      onToggle: toggle,
    );
  }
}

/// The localized name of a time tier (三段式文法 §3). 时间档本地化名。
String _tierLabel(BuildContext context, String tierKey) {
  final t = Translations.of(context).chat.stage;
  return switch (tierKey) {
    'just' => t.groupJustNow,
    'today' => t.groupEarlierToday,
    _ => t.groupEarlier,
  };
}

/// The todo board pinned as row zero — a progress-RING lead (blue = done), «Tasks» + done/total, a
/// rotating chevron, opening to the read-only checklist(s). Composed to the [AnRow] metrics (32 · 8-radius ·
/// surfaceActive when open) but with the ring where a kind glyph would sit. 置顶待办行(进度环 lead)。
class _TodoRow extends ConsumerWidget {
  const _TodoRow({required this.conversationId, required this.open});

  final String conversationId;
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final boards = ref.watch(rundownProvider(conversationId));
    final nonEmpty =
        [
          for (final e in boards.entries)
            if (e.value.todos.isNotEmpty) e.value,
        ]..sort(
          (a, b) => a.subagentId.compareTo(b.subagentId),
        ); // main ("") first 主清单在前
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    final total = nonEmpty.fold(0, (n, b) => n + b.todos.length);
    final done = nonEmpty.fold(0, (n, b) => n + b.completed);
    void toggle() => ref
        .read(stageExpansionProvider(conversationId).notifier)
        .toggle('todo');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The family row (批6 A-073 — the metric re-roll retires; its own note admitted «Composed to
        // the AnRow metrics»). The chevron follows the row idiom: hover swaps the ring for it — the
        // same face as the sibling stage rows, which is the convergence itself. 族行(度量重抄退役);
        // 箭头随行惯用式 hover 换 lead,与同列舞台行同脸=收敛本意。
        AnRow(
          leadWidget: AnTaskRing(completed: done, total: total),
          label: t.chat.stage.tasks,
          meta: '$done/$total',
          collapsible: true,
          open: open,
          selected: open,
          onSelect: toggle,
          onToggle: toggle,
        ),
        AnExpandReveal.builder(
          open: open,
          childBuilder: (context) => Padding(
            // Same breathing shape as the stage rows: symmetric 8 vertical, full box width. 与舞台行同形。
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final board in nonEmpty) ...[
                  if (board.subagentId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AnSpace.s4,
                        bottom: AnSpace.s2,
                      ),
                      child: Text(
                        t.chat.stage.boardOf(name: board.subagentId),
                        style: AnText.meta.copyWith(color: c.inkFaint),
                      ),
                    ),
                  AnRundownList(todos: board.todos),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One touchpoint row — a left-island [AnRow] header (kind glyph · name · verb·count · live dot · hover-swap
/// chevron; surfaceActive box when open) over a de-indented [AnExpandReveal] body: the LIVE stage
/// ([_GenericStage], streaming) when a live activity backs it, else the settled identity summary. The body
/// spans the FULL header-box width (no inset — hierarchy reads from position; a narrower body just looks
/// misaligned, WRK-064). touchpoint 行(体与行头框同宽,不缩一圈)。
class _StageRow extends ConsumerWidget {
  const _StageRow({
    required this.conversationId,
    required this.spec,
    required this.open,
    required this.transcript,
    required this.onEngaged,
  });

  final String conversationId;
  final _RowSpec spec;
  final bool open;
  final CoalescingNotifier<ConversationTranscript> transcript;

  /// The user tapped / dragged inside this row's stage body — a G2 row claim (never a camera lock).
  /// 用户在本行体内交互——G2 行级认领(绝非镜头锁)。
  final VoidCallback onEngaged;

  /// ONE title derivation for live and settled alike (G3/A2-23) — a row must never rename itself at
  /// the moment it settles. Subagent rows (live or settled) read the same task-label seam.
  /// 行头命名单源:live/落定同一条派生,行绝不在落定瞬间改名;分身行同走任务名缝。
  String _title(Translations t) {
    final entity = spec.entity;
    if (entity != null) return entity.displayName;
    final subNode = spec.subagentNode;
    if (subNode != null) {
      return subagentTaskLabel(subNode) ?? t.chat.stage.subagentUnnamed;
    }
    final view = spec.view;
    if (view == null) return spec.rowId;
    if (view.kind == 'subagent') {
      final node = transcript.value.liveBlock(view.blockId);
      final label = node == null ? null : subagentTaskLabel(node);
      return (label != null && label.isNotEmpty)
          ? label
          : t.chat.stage.subagentUnnamed;
    }
    return view.itemId ?? view.toolName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final director = ref.read(stageDirectorProvider(conversationId).notifier);
    final entity = spec.entity;
    final view = spec.view;
    final subNode = spec.subagentNode;
    final kind =
        entity?.kind ?? view?.kind ?? (subNode != null ? 'subagent' : 'tool');
    final name = _title(t);
    final tombstoned = entity?.tombstoned ?? false;

    // The honest state word (G3): failed / running (poll) / settling / live — never «Live» just
    // because the director still holds a view. 行头状态词如实四态。
    final String stateWord = switch (spec.state) {
      _RowState.failed => t.chat.stage.rowFailed,
      _RowState.polling => t.chat.stage.rowRunning,
      _RowState.settling => t.chat.stage.rowSettling,
      _ => t.chat.stage.live,
    };
    final String meta;
    if (entity != null) {
      final p = entity.primary;
      final settled = p.count > 1
          ? '${AnCastRow.verbWord(t, p.verb)} ×${p.count}'
          : AnCastRow.verbWord(t, p.verb);
      meta = spec.liveCount > 1
          ? '$settled · ${t.chat.stage.parallelRunning(n: spec.liveCount)}'
          : (spec.state == _RowState.settled
                ? settled
                : '$settled · $stateWord');
    } else if (subNode != null) {
      meta = t
          .chat
          .stage
          .delegated; // a settled delegated run — quiet, no live dot 落定委派,无蓝点
    } else {
      meta = spec.liveCount > 1
          ? t.chat.stage.parallelRunning(n: spec.liveCount)
          : stateWord;
    }

    void toggle() => ref
        .read(stageExpansionProvider(conversationId).notifier)
        .toggle(spec.rowId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnRow(
          icon: AnIcons.entityKindGlyph(kind),
          label: name,
          meta: meta,
          selected: open,
          collapsible: true,
          open: open,
          // The dot speaks the row state (G3): blue only while work truly runs (live / poll-held),
          // green for the settle breath, red for the failed hold, quiet when settled. 点随四态:
          // 真在跑才蓝,停拍绿,失败红,落定安静。
          trailingDot: switch (spec.state) {
            _RowState.live || _RowState.polling => AnStatus.run,
            _RowState.settling => AnStatus.done,
            _RowState.failed => AnStatus.err,
            _RowState.settled => null,
          },
          actions: [
            // The failed-hold EXIT (G3/A1-11): a failed activity used to squat as a blue «Live» row
            // forever with no way out. 失败驻留的出口:旧失败行永久滞留且无出路。
            if (spec.state == _RowState.failed && view != null)
              AnButton.iconOnly(
                AnIcons.close,
                size: AnButtonSize.sm,
                semanticLabel: t.chat.stage.clearRow,
                onPressed: () => director.clearActivity(view.blockId),
              ),
          ],
          onSelect: toggle,
          onToggle: toggle,
        ),
        // LAZY (C-040): a COLLAPSED accordion row must NOT build its stage body — StageBodyFromTruth watches
        // a provider + sceneFromSubagentNode constructs a scene + _GenericStage mounts a coalescer, all per
        // accordion rebuild otherwise. The builder runs only while the row is open / animating. 惰性:收起行
        // 绝不建 stage 体(sceneFromSubagentNode 构造/StageBodyFromTruth 观 provider/generic 挂 coalescer)。
        AnExpandReveal.builder(
          open: open,
          childBuilder: (context) => Padding(
            // Symmetric 8 above/below (the card must not glue to its header row), 0 left/right — the body
            // spans the FULL header-box width: hierarchy reads from position, a narrower card just looks
            // misaligned (user-tuned). 上下对称 8(卡不贴行头)、左右 0——体与行头框同宽;瘦一圈反显没对齐。
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
            child: view != null
                ? _GenericStage(
                    conversationId: conversationId,
                    subject: view,
                    // Per-row phase truth (G2): a row's stage face depends only on ITS activity —
                    // failed wears the red hold, everything else is following. 行相位只看本行活动。
                    phase: view.failed
                        ? StagePhase.failedHold
                        : StagePhase.following,
                    transcript: transcript,
                    onEngaged: onEngaged,
                  )
                // A settled subagent run — its folded nested trajectory rendered as a live:false stage (no
                // entity, no touchpoint; the transcript IS its truth, WRK-064 B6). 落定 subagent 嵌套轨迹。
                : subNode != null
                ? SubagentStageBody(
                    scene: sceneFromSubagentNode(subNode, conversationId),
                  )
                : entity != null
                ? (!tombstoned && entity.kind == 'attachment'
                      // Attachments enter via the composer, not a build tool — their settled face is the
                      // pedestal (thumbnail · size · fingerprint), not a stage. 附件=展品座静物卡,非舞台。
                      ? AttachmentPedestal(attachmentId: entity.key)
                      // Any other settled row opens to its FULL bespoke stage rendered from the entity's
                      // current truth (WRK-064) — code / graph / ladder, not a summary. 其余落定行渲完整真身舞台。
                      : !tombstoned && hasTruthStage(entity.kind)
                      ? StageBodyFromTruth(
                          conversationId: conversationId,
                          kind: entity.kind,
                          id: entity.key,
                          rowId: 'truth_${spec.rowId}',
                          fallback: entity,
                        )
                      : SettledBody(
                          conversationId: conversationId,
                          entity: entity,
                          tombstoned: tombstoned,
                        ))
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// The GENERIC STAGE — the fallback before a kind's bespoke stage lands, but a designed non-empty window:
/// the subject brow (kind glyph + resolved name + phase badge + jump), an honesty ribbon, closed top-level
/// args as a KV list, the in-flight tail in a machine window, the result bar on settle. Rides the transcript
/// coalescer (≤1 rebuild/frame). 通用舞台(兜底,但按设计做非空窗)。
class _GenericStage extends StatefulWidget {
  const _GenericStage({
    required this.conversationId,
    required this.subject,
    required this.phase,
    required this.transcript,
    required this.onEngaged,
  });

  final String conversationId;
  final StageActivityView subject;
  final StagePhase phase;
  final CoalescingNotifier<ConversationTranscript> transcript;

  /// Tap / drag inside the body — the G2 row claim (reading never gets auto-collapsed; the follow
  /// pipeline keeps flowing). 体内交互=G2 行级认领(阅读不被自动收;流水线照常流动)。
  final VoidCallback onEngaged;

  @override
  State<_GenericStage> createState() => _GenericStageState();
}

class _GenericStageState extends State<_GenericStage> {
  static const _frameworkKeys = {'summary', 'danger', 'execution_group'};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // C-025: gate this stage's rebuild on THIS block's subtree-max revision — a delta on ANOTHER block
    // (or a settled block) no longer rebuilds every expanded stage. `revision` bumps up the ancestor
    // chain (_bump), so nested subagent-tree updates still reach the parent block's revision (no stale
    // nested UI). The old ValueListenableBuilder rebuilt on EVERY transcript notification. 只在本块子树
    // 版本变时重建(别块 delta 不再重建本舞台);revision 上抛祖先→嵌套更新仍捕获。
    return ValueListenableSelector<ConversationTranscript, int?>(
      listenable: widget.transcript,
      selector: (t) => t.liveBlock(widget.subject.blockId)?.revision,
      builder: (context, transcript) {
        final node = transcript.liveBlock(widget.subject.blockId);
        if (node == null) {
          // Not in the live reducer (row expanded after a reload) — honest placeholder. 诚实占位。
          return Padding(
            padding: const EdgeInsets.all(AnSpace.s8),
            child: AnHonestyRibbon(
              widget.subject.live ? AnHonesty.gap : AnHonesty.live,
            ),
          );
        }
        final state = ToolCardState.of(node);
        final session = state.argsSession;
        // G7 — no id guessing here anymore (A3-7/A2-11): the old deep-search `liveStringNamed('id')`
        // false-hit workflow ops' node ids, and the display-NAME fallback minted row keys that never
        // matched the ledger's real entity ids — one activity, two rows forever. Identity now
        // resolves in ONE place, the director host (top-level arg keys at args close + the create
        // receipt's id at the execution terminal + a name whitelist for name-addressed kinds).
        // G7:此处不再猜 id——旧任意深度搜 `id` 被 workflow ops 节点 id 假命中、显示名兜底铸出与台账
        // 真身永不合并的行键;身份统一在宿主一处解析(参流关顶层键 + 执行回执 id + 名寻址白名单)。
        // G4: liveness = execution phase (toolLive), never node.isOpen — the args-stream close is
        // not the execution terminal. G4 判活走执行相位,参流关≠执行终态。
        final live = toolLive(state);
        final failed = widget.phase == StagePhase.failedHold;
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
          // Reading INSIDE a stage = claiming THIS row (G2): the curtain will never collapse a row
          // mid-read; only user gestures count (dragDetails ≠ null). The old capture pinned the whole
          // DIRECTOR — one tap froze auto-staging for the rest of the conversation with no exit.
          // 舞台内滚动=认领本行(G2):谢幕绝不收正在读的行,只认用户手势;旧捕获钉死整个导演器——
          // 点一下即全会话冻结自动登台且无出口。
          onNotification: (n) {
            if (n.dragDetails != null) widget.onEngaged();
            return false;
          },
          child: GestureDetector(
            onTapDown: (_) => widget.onEngaged(),
            behavior: HitTestBehavior.translucent,
            // No brow — the accordion ROW HEADER is the identity (kind glyph · name · live dot); the body
            // is just the stage content + the honesty ribbon (live/failed truth). 无眉:行头即身份。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failed || live) ...[
                  AnHonestyRibbon(failed ? AnHonesty.failed : AnHonesty.live),
                  const SizedBox(height: AnSpace.s6),
                ],
                if (stageRouteOf(widget.subject.toolName)?.lifecycle ==
                    LifecycleSource.poll)
                  _RunProgressSection(blockId: widget.subject.blockId),
                // Live streaming churn is semantics-noise — the four announcements carry meaning. 流式区静音。
                ExcludeSemantics(
                  excluding: live,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bespoke != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AnSpace.s8),
                          child: bespoke(context, scene),
                        )
                      else
                        ..._body(context, c, state, session, live, failed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    AnColors c,
    ToolCardState state,
    PartialJsonSession session,
    bool live,
    bool failed,
  ) {
    final kv = <AnKvRow>[];
    for (final e in session.events) {
      if (e.path.length != 1 || e.path.first is! String) continue;
      final key = e.path.first as String;
      if (_frameworkKeys.contains(key)) continue;
      final v = e.value;
      if (v is Map || v is List) continue;
      // Grapheme-safe truncation via the standard tier (no raw substring / bare number). 走标准档截断。
      kv.add(AnKvRow(key, truncate('$v', AnTrunc.line)));
    }
    final tail = session.inFlightString;
    return [
      if (kv.isNotEmpty) AnKv(rows: kv, dense: true),
      if (live && tail != null && tail.text.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        AnWindow(
          child: Text(
            tailLines(tail.text, 8),
            style: AnText.code.copyWith(color: c.inkMuted),
          ),
        ),
      ],
      if (!live && !failed) ...[
        const SizedBox(height: AnSpace.s6),
        runStatBarOf(context, state),
      ],
      if (failed && state.errorText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        // 假想框律:裸错误字归假想框,左缘对齐上方 AnKv 键(X=8);honesty 带是全宽着色丝带(自带 h:s8 内距,
        // 文字已落 X=8)、runStatBar 是当家条,皆真框贴 X=0、不动。The imaginary-frame law: the bare error
        // text joins the imaginary frame (X=8, the KV-key line above); the honesty ribbon (a full-width
        // tinted frame whose own h:s8 already lands its text at X=8) and the stat bar are real frames at X=0.
        stageFramed(
          Text(
            state.errorText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.danger),
          ),
        ),
      ],
      const SizedBox(height: AnSpace.s8),
    ];
  }
}

/// The live run scroll of a poll-type stage: the flowrun's node ticks, newest last — node id in mono, a
/// status word, the taken `port` as a quiet accent badge; the durable terminal closes with one honest
/// line. Bounded to the last 12 rows. poll 型舞台的活运行卷。
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rows.isEmpty && progress.terminal.isEmpty)
            AnShimmerText(
              t.chat.stage.run.queued,
              style: AnText.meta.copyWith(color: c.inkFaint),
              reveal: true,
            ),
          // Family rows (批6 A-074): the semantic dot replaces the icon trio (its iconSm-2 arithmetic
          // dies; fromRaw folds parked→wait amber, running→run accent — truer than «every non-terminal
          // amber»); the loop turn joins the chips ('#N', the hand-glued ' · ' dies, 文法 #3). 族行:
          // 语义点替三态图标(算术亡;fromRaw 语义更真);轮次进 chips(手拼点链亡)。
          for (final n in rows)
            AnLedgerRow(
              lead: AnStatusDot(AnStatus.fromRaw(n.status)),
              primary: n.nodeId,
              chips: [
                if (n.iteration > 0)
                  Text(
                    '#${n.iteration}',
                    style: AnText.metaTabular().copyWith(color: c.inkFaint),
                  ),
                if (n.status == 'parked')
                  Text(
                    t.chat.stage.run.parked,
                    style: AnText.meta.copyWith(color: c.warn),
                  ),
                if (n.port.isNotEmpty)
                  AnChip('→ ${n.port}', tone: AnTone.accent),
              ],
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
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
