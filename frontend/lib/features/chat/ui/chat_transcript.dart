import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/model_capability.dart';
import '../../../core/contract/messages/block_content.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/model/model_capabilities.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/perf/frame_safe.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/attachment_image_provider.dart';
import '../data/chat_providers.dart';
import '../model/conversation_transcript.dart';
import '../model/user_attachment.dart';
import '../state/attachment_audio_player.dart';
import '../state/attachment_meta.dart';
import '../state/conversation_header.dart';
import '../state/conversation_stream_provider.dart';
import '../state/conversation_stream_state.dart';
import '../state/fork_conversation.dart';
import '../state/pending_interactions_provider.dart';
import '../state/selected_conversation.dart';
import '../state/transcript_jump_provider.dart';
import 'chat_head.dart';
import 'chat_tool_card.dart';
import 'chat_turn.dart';
import 'turn_actions.dart';
import 'chat_context_mark.dart';
import 'chat_work_dir_button.dart';
import 'chat_thinking.dart';
import 'user_turn_content.dart';

/// Test-only build counters for the streaming-perf gate (the BuildSpy assertion: while a turn streams,
/// the PAGE never rebuilds, SETTLED rows never rebuild, only the live leaf ticks ≤1×/frame). Null in
/// production — zero cost. 测试探针(BuildSpy 门禁:流式中页 0 重建、settled 行 0 重建、live 叶 ≤1/帧)。
abstract final class TranscriptProbe {
  @visibleForTesting
  static void Function(String zone)? onBuild;
  static void hit(String zone) => onBuild?.call(zone);
}

/// The transcript of ONE conversation — hydration skeleton → error+retry → the streaming list.
/// The page level watches ONLY the low-frequency phase state; the high-frequency body hangs off the
/// controller's [CoalescingNotifier] below (so a token firehose never reaches this build).
///
/// 单会话 transcript:水化骨架 → 错误+重试 → 流式列表。页级只 watch 低频相位;高频本体挂在下方控制器的
/// CoalescingNotifier 上(token 火喉打不到本 build)。
class ChatTranscriptView extends ConsumerWidget {
  const ChatTranscriptView({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TranscriptProbe.hit('page');
    final phase = ref.watch(
      conversationStreamProvider(conversationId).select((s) => s.phase),
    );
    final t = Translations.of(context);
    return switch (phase) {
      TranscriptPhase.hydrating => const _HydratingSkeleton(),
      TranscriptPhase.error => Center(
        child: AnState(
          kind: AnStateKind.error,
          title: t.chat.transcriptErrorTitle,
          hint: t.chat.transcriptErrorHint,
          action: AnButton(
            label: t.chat.retry,
            onPressed: () => ref
                .read(conversationStreamProvider(conversationId).notifier)
                .retryHydrate(),
          ),
        ),
      ),
      TranscriptPhase.ready => _TranscriptList(conversationId: conversationId),
    };
  }
}

class _HydratingSkeleton extends StatelessWidget {
  const _HydratingSkeleton();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.content),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s24),
        child: AnDeferredLoading(child: const AnSkeleton.lines(4)),
      ),
    ),
  );
}

/// The streaming list — a [CustomScrollView] around a CENTER anchor: older pages fill the sliver ABOVE
/// the anchor (growing upward at negative offsets, so a prepend NEVER shifts pixels — no offset math),
/// the head + live turns fill the sliver below (growing downward at the max end, so a reader scrolled up
/// is never pushed while tokens stream). Stick-to-bottom is an explicit follow: while pinned (at bottom),
/// every transcript tick re-jumps to max after layout; scrolling away releases the pin; a send re-pins.
/// Terminal rows are cached BY WIDGET IDENTITY (an identical widget instance short-circuits the element
/// rebuild), so a streaming tick rebuilds only the live turn — the L3-equivalent this view ships with.
///
/// 流式列表——绕**中心锚**的 CustomScrollView:老页填锚上方 sliver(负偏移向上长,prepend **零位移**、无 offset
/// 数学);头+live 填下方(向 max 端长,上翻阅读者不被流式推走)。贴底=显式跟随:钉住时每 tick 布局后重跳 max;
/// 上滑解钉;发送重钉。终态行按 widget **身份缓存**(同实例短路 element 重建)——流式 tick 只重建 live 回合。
class _TranscriptList extends ConsumerStatefulWidget {
  const _TranscriptList({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends ConsumerState<_TranscriptList> {
  static const _centerKey = ValueKey('transcript-center');
  static const double _pinSlack =
      48; // within this of the bottom = pinned 距底此内=钉住
  static const double _loadOlderSlack = 300; // near-top prefetch band 近顶预取带

  final ScrollController _scroll = ScrollController();
  final Map<String, Widget> _settledRowCache = {};

  /// Which version each version group is showing, keyed by the group's ROOT message id. Absent = the current
  /// version (the pager's default). It lives here rather than in the row because a settled row is memoized
  /// by id — a selection stored inside one would vanish the next time the cache answered.
  /// 每个版本组正在显示第几版,按组的**根** message id 键住。缺席 = 现行版(翻页默认)。它住在这里而非住在行里,因为落定行
  /// 按 id 记忆化——存在行里的选择会在缓存下一次作答时消失。
  final Map<String, int> _versionChoice = {};
  CoalescingNotifier<ConversationTranscript>? _attached;
  bool _pinned = true;
  int _lastPendingCount = 0;
  String? _highlightId; // the jump target's temporary wash 跳转目标的临时高亮
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  // A conversation switch can REUSE this State (same widget position, no per-conversation key) — the
  // identity row cache is keyed by turn.id and would otherwise carry the previous conversation's rows
  // (stale memory; turn ids are globally unique so never a mis-render, but a leak). Drop it. C-036.
  // 切会话可复用本 State(同位置无 key)——身份缓存带旧会话行(泄漏),清之。
  @override
  void didUpdateWidget(_TranscriptList old) {
    super.didUpdateWidget(old);
    if (old.conversationId != widget.conversationId) {
      _settledRowCache.clear();
      _versionChoice
          .clear(); // page selections belong to the thread that was open 翻页选择属于刚才那条线程
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _attached?.removeListener(_onTick);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ── the jump (W6 re-anchor) 跳转 ──

  /// Execute one jump command: near = the anchor re-centers on the loaded row; deep = the
  /// `?around=` window replaces the transcript (re-anchor). Either way the target lands at scroll
  /// offset 0 — the center anchor's first row — so there is NO extent estimation; we then seat it
  /// just below the floating head and wash it briefly (hold + fade, the Slack-permalink rhythm).
  /// The pin is released first: a jump means READING HISTORY, and streaming frames must never
  /// yank the viewport back to the bottom (the 抢镜 covenant).
  ///
  /// 执行一次跳转:近跳=锚移到已加载行;深跳=`?around=` 窗整扇替换(重锚)。两径目标都落在 offset 0
  /// (center 锚首行)——零 extent 估算;随后把它安放在浮层头下、短暂洗亮(hold+fade,Slack permalink
  /// 节奏)。先解钉:跳转即读史,流式帧绝不许把视口拽回底(抢镜公约)。
  Future<void> _executeJump(TranscriptJumpRequest req) async {
    ref.read(transcriptJumpProvider(widget.conversationId).notifier).clear();
    final ok = await ref
        .read(conversationStreamProvider(widget.conversationId).notifier)
        .jumpTo(req.messageId);
    if (!ok || !mounted) return;
    _pinned = false;
    // Offset 0 (= the anchor) is always in range on a center-anchored list; refine after layout.
    // offset 0(=锚)在 center 锚列表上恒有效;布局后再精调。
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _highlightId = req.messageId);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    _scroll.jumpTo(
      (-(AnSize.islandHead + AnSpace.s12))
          .clamp(pos.minScrollExtent, pos.maxScrollExtent)
          .toDouble(),
    );
    _highlightTimer?.cancel();
    // Same tier as _JumpHighlight's fade — the wash dwell and its fade are one gesture.
    // 与 _JumpHighlight 同档同值:洗亮驻留与褪色一体。
    _highlightTimer = Timer(AnMotion.wash, () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  void _attach(CoalescingNotifier<ConversationTranscript> t) {
    if (identical(_attached, t)) return;
    _attached?.removeListener(_onTick);
    _attached = t..addListener(_onTick);
  }

  void _onTick() {
    final pendingCount = _attached?.value.pending.length ?? 0;
    if (pendingCount > _lastPendingCount) _pinned = true; // a send re-pins 发送重钉
    _lastPendingCount = pendingCount;
    if (_pinned) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  // The dock target. A center-anchored list starts AT the anchor (pixels 0 = the first head row), which
  // parks the first turn UNDER the floating head while the content is shorter than a screen — the
  // head-clearing padding lives above the anchor at negative offsets. So: content overflowing below the
  // anchor → dock to max (stick-to-bottom); shorter → dock to MIN, which reveals that padding and seats
  // the first row below the head. 锚定列表初始停在锚上(首行被浮层头盖):超屏贴 max;未满屏钉 min 露出锚上让头 padding。
  double _dockTarget(ScrollPosition pos) =>
      pos.maxScrollExtent > 0 ? pos.maxScrollExtent : pos.minScrollExtent;

  void _jumpToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    // Never yank the viewport out from under a selection in progress. A streaming reply ticks many times a
    // second, and each tick would dock to the bottom mid-drag — which moves the content under the pointer
    // and ends the drag. This is the single most valuable half of TS: without it, "select text" and
    // "watch a reply stream" are mutually exclusive, which is exactly when a reader most wants to copy
    // something.
    //
    // If the stream happens to finish DURING the drag we simply stay where the reader put us. That is the
    // right outcome, not a gap: a reader who is selecting text has said where they want to be.
    //
    // 绝不在选区进行中把视口从用户手底下抽走。流式回复每秒 tick 数次,每次 tick 都会在拖拽途中贴底——那会让
    // 指针下的内容移动、拖拽随之终止。这是 TS 里价值最大的一半:没有它,「划选文字」与「看回复流出来」互斥,
    // 而那恰恰是读者最想复制点东西的时刻。
    //
    // 若流恰好在拖拽期间结束,我们就停在读者放下的位置。这是**对的结果**、不是缺口:正在划选的读者已经表明了
    // 他想待在哪里。
    if (SelectableRegionSelectionStatusScope.maybeOf(context)?.value ==
        SelectableRegionSelectionStatus.changing) {
      return;
    }
    final pos = _scroll.position;
    final target = _dockTarget(pos);
    if (pos.pixels != target) _scroll.jumpTo(target);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _pinned = _dockTarget(pos) - pos.pixels <= _pinSlack;
    if (pos.pixels - pos.minScrollExtent <= _loadOlderSlack) {
      // Guarded inside the controller (cursor/loading/hasMore). 控制器内自守。
      // Deferred out of the layout phase — a viewport notifies this listener from performLayout, and
      // loadOlder dirties the provider (CR-1b). 移出布局相位:viewport 会在 performLayout 里通知本监听器,
      // 而 loadOlder 会弄脏 provider。
      runFrameSafe(() {
        if (!mounted) return;
        ref
            .read(conversationStreamProvider(widget.conversationId).notifier)
            .loadOlder();
      });
    }
    if (pos.maxScrollExtent - pos.pixels <= _loadOlderSlack) {
      // Window mode's forward continuation — same guard style, same deferral. 窗口模式向前续翻,同守卫、同延后。
      runFrameSafe(() {
        if (!mounted) return;
        ref
            .read(conversationStreamProvider(widget.conversationId).notifier)
            .loadNewer();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.watch(
      conversationStreamProvider(widget.conversationId).notifier,
    );
    final loadingOlder = ref.watch(
      conversationStreamProvider(
        widget.conversationId,
      ).select((s) => s.loadingOlder),
    );
    ref.listen(transcriptJumpProvider(widget.conversationId), (_, req) {
      if (req != null) unawaited(_executeJump(req));
    });
    // Leaving the jump window (the pill / an implicit send) re-docks to the present. A fast
    // re-hydrate can keep this SAME State alive (no initState re-dock), so the transition must
    // re-pin explicitly — rejoining without re-docking maroons the reader mid-history.
    // 离开跳转窗(pill/发送隐式)即重新贴底。快速重拉可能不换 State(无 initState 重靠),转变必须显式
    // 重钉——归队不贴底=把读者晾在史中。
    ref.listen(
      conversationStreamProvider(
        widget.conversationId,
      ).select((s) => s.windowMode),
      (prev, next) {
        if (prev == true && next == false) {
          _pinned = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
        }
      },
    );
    // Re-read the listenable each build — it is a NEW instance after a controller rebuild (the
    // documented coalescer discipline). 每 build 重取 listenable(controller 重建后是新实例)。
    final transcript = ctl.transcript;
    _attach(transcript);
    return ValueListenableBuilder<ConversationTranscript>(
      valueListenable: transcript,
      builder: (context, t, _) {
        TranscriptProbe.hit('list');
        // Window mode: settled IS the detached jump window — live turns and optimistic bubbles
        // belong to the present and hide until the「回到现场」pill (or a send) rejoins it.
        // 窗口模式:settled 即被跳离的窗——live 回合与乐观泡属于现场,藏到「回到现场」pill(或发送)归队。
        final windowMode = t.windowMode;
        // Version groups collapse BEFORE the anchor split, not per-sliver: a chain can straddle the anchor
        // (its root in an older page, its newest version in the head), and grouping each half on its own
        // would render that turn twice — once as an old version and once as a new one, which is exactly the
        // duplicate the pager exists to prevent.
        // 版本组在**锚切分之前**折叠、不逐 sliver 折:一条链可能横跨锚(根在老页、最新版在头页),各自分组会把那个回合
        // **渲两遍**——一遍作旧版、一遍作新版,而那正是翻页要防的重复。
        final groups = ConversationTranscript.groupVersions([
          ...t.settled,
          if (!windowMode) ...t.liveTurns,
        ]);
        // A group sits at its ROOT's position (a new version is the same turn said again, not a later turn),
        // so the anchor split counts the groups whose root fell in the prepended pages — those ids form a
        // prefix of the group list, hence the break.
        // 组坐落在其**根**的位置(新版本是同一个回合又说了一遍、不是后来的回合),故锚切分数的是「根落在已上翻页里」的
        // 组——那些 id 构成组列表的一个前缀,故可 break。
        final olderIds = {for (final n in t.settled.take(t.olderCount)) n.id};
        var olderGroups = 0;
        for (final g in groups) {
          if (!olderIds.contains(g.root.id)) break;
          olderGroups++;
        }
        final older = groups.take(olderGroups).toList(growable: false);
        final head = groups.skip(olderGroups).toList(growable: false);
        final pending = windowMode ? const <PendingSend>[] : t.pending;
        // Retry / edit-resend exist only on the TAIL, mirroring the backend's own rule (`:retry` replaces the
        // last round and 409s otherwise). They are withheld while a jump window is open (the tail is not even
        // loaded) and while an optimistic bubble sits below (the round the reader sees as last is not the one
        // the server would replace). Both the last group and the last USER group live in `head` by
        // construction — `older` only ever holds prepended pages.
        // 重试 / 编辑重发只存在于**尾巴**上,镜像后端自己的规则(`:retry` 替换末回合、否则 409)。跳转窗开着时不给
        // (尾巴根本没加载),下面还有乐观泡时也不给(读者看作末轮的那一轮不是服务端会替换的那一轮)。末组与末条 user 组
        // 按构造都在 `head` 里——`older` 只装已上翻的页。
        // `!hasInFlight` is load-bearing twice over. It is honest (mid-generation the last round is not a round
        // to replace — the backend 409s), and it is what keeps the last USER row CACHEABLE while a reply
        // streams: a row carrying a tail action cannot be cached (see _rowFor), so without this the settled
        // user turn would rebuild on every delta and break the streaming-perf invariant. The cache therefore
        // only ever holds the no-tail-action variant, which is exactly the variant it is asked for.
        // `!hasInFlight` 承重两次。它诚实(生成中,末回合不是可替换的回合——后端会 409),而它同时是让末条 **user** 行在
        // 回复流式期间**仍可缓存**的原因:带尾巴动作的行不能缓存(见 _rowFor),没有这一条,那条已落定的 user 回合会随每个
        // delta 重建、破掉流式性能不变量。于是缓存里只会存「无尾巴动作」那个变体——而那恰是它被问到的那个变体。
        final tailActionable = !windowMode && pending.isEmpty && !t.hasInFlight;
        var lastUserGroup = -1;
        for (var i = 0; i < head.length; i++) {
          if (ConversationTranscript.turnRole(head[i].current) == 'user') {
            lastUserGroup = i;
          }
        }
        final list = CustomScrollView(
          controller: _scroll,
          center: _centerKey,
          slivers: [
            // ABOVE the anchor: older pages, reversed so index 0 sits adjacent to the center. 锚上:老页。
            SliverPadding(
              padding: const EdgeInsets.only(
                top: AnSize.islandHead + AnSpace.s12,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: older.length + (loadingOlder ? 1 : 0),
                  (context, i) {
                    if (i == older.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AnSpace.s12,
                        ),
                        child: Center(
                          child: AnSpinner(
                            semanticLabel: context.t.a11y.loading,
                          ),
                        ),
                      );
                    }
                    // Rows above the anchor are history by construction — never the last turn, and never
                    // the tail the retry/edit actions belong to.
                    // 锚上的行按构造就是历史,绝不可能是末轮,也绝不是重试/编辑所属的那条尾巴。
                    return _rowFor(older[older.length - 1 - i], isLast: false);
                  },
                ),
              ),
            ),
            // AT + BELOW the anchor: the head page, live turns, optimistic bubbles. 锚下:头页+live+乐观泡。
            SliverPadding(
              key: _centerKey,
              padding: const EdgeInsets.only(bottom: AnSpace.s16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: head.length + pending.length,
                  (context, i) {
                    if (i < head.length) {
                      // An optimistic bubble below means the last SETTLED turn is no longer the
                      // bottom of the transcript. 下面还有乐观泡时,最后一条落定回合已不是 transcript 底部。
                      final isTail = i == head.length - 1;
                      return _rowFor(
                        head[i],
                        isLast: isTail && pending.isEmpty,
                        canRetry:
                            tailActionable &&
                            isTail &&
                            ConversationTranscript.turnRole(head[i].current) ==
                                'assistant',
                        canEdit: tailActionable && i == lastUserGroup,
                      );
                    }
                    return _PendingRow(
                      conversationId: widget.conversationId,
                      pending: pending[i - head.length],
                      key: ValueKey(pending[i - head.length].localId),
                    );
                  },
                ),
              ),
            ),
          ],
        );
        if (!windowMode) return list;
        // The detached-window chrome: the「回到现场」pill floats over the list (Discord's
        // jump-to-present shape); a send exits implicitly. 离场态:「回到现场」pill 浮于列表上。
        return Stack(
          children: [
            list,
            Positioned(
              left: 0,
              right: 0,
              bottom: AnSpace.s16,
              child: Center(
                child: AnFollowPill.jump(
                  label: Translations.of(context).chat.backToPresent,
                  elevated: true,
                  onTap: () => ref
                      .read(
                        conversationStreamProvider(
                          widget.conversationId,
                        ).notifier,
                      )
                      .backToLive(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Terminal rows come from the identity cache (an identical instance short-circuits the element
  // rebuild — settled turns cost ZERO builds during streaming); the open turn builds fresh per tick.
  // 终态行走身份缓存(同实例短路重建——流式中 settled 行零 build);open 回合逐 tick 新建。
  // The identity cache is bounded (C-037): a long conversation + repeated deep-jump windows would grow it
  // without end (it never evicts). Insertion order == render order, so the FIFO-oldest entries are rows
  // that scrolled far away — never the visible window (~20 rows) — so evicting them is invisible (they
  // rebuild once if scrolled back). 身份缓存有界:末插=近渲染,逐最旧=已滚远行,可见窗不受影响。
  static const _rowCacheCap = 400;

  Widget _rowFor(
    TurnVersions group, {
    required bool isLast,
    bool canRetry = false,
    bool canEdit = false,
  }) {
    // Which version of this turn is on screen. The default is the CURRENT one (what the thread continued
    // from) — a reader who has never touched the pager must be looking at the answer everything after it was
    // built on. The choice is keyed by the group's ROOT because that id is stable across further retries.
    // 屏上是本回合的第几版。默认**现行版**(线程后续所基于的那一版)——从没碰过翻页的读者,看的必须是「其后的一切据以
    // 构建」的那个回答。选择按组的**根** id 键住,因为该 id 跨此后的每次重试都稳定。
    // One override on the stored choice: a version that is being GENERATED RIGHT NOW is always the one you
    // see. Otherwise a reader who had paged back before hitting retry would watch a reply stream into a row
    // that is off screen — the pager would be showing an old answer while the new one arrived invisibly.
    // 存下的选择只有一个覆盖:**正在生成**的那一版恒是你看到的那一版。否则一个在按重试前往回翻过页的读者,会看着回复流进
    // 一个屏上不存在的行——翻页显示着旧回答,而新回答无形中抵达。
    final index = group.current.isOpen
        ? group.count - 1
        : (_versionChoice[group.root.id] ?? group.count - 1).clamp(
            0,
            group.count - 1,
          );
    final turn = group.at(index);
    Widget row;
    // The LAST turn is deliberately not cached. Its action row is always-visible while a historical
    // turn's is hover-only (§3.2), so "am I last" is part of what the row renders — and a cached
    // instance would freeze that answer at the moment it was built, leaving a stale always-on row
    // behind once the next turn arrives. Excluding one row costs nothing: during streaming the bottom
    // turn is the OPEN one, which was never cached either.
    // **末轮刻意不缓存。** 它的动作排恒显、而历史轮 hover 才现(§3.2),故「我是不是末轮」是这一行渲染内容的
    // 一部分——被缓存的实例会把这个答案**冻结在建它的那一刻**,于是下一轮到来后留下一排过期的常显图标。少缓一行
    // 零代价:流式中底部那轮是 **open** 的,它本来也不进缓存。
    //
    // The TAIL-ACTION rows are excluded for exactly the same reason, and the last USER turn is why this has to
    // be spelled out: it is settled and it is not last, so it WOULD be cached — and then「编辑重发」would freeze
    // on it and go on offering to replace a round that is no longer the last one. It becomes cacheable again
    // the moment a newer round arrives, which is precisely when the answer flips to false.
    // **带尾巴动作的行**因完全相同的理由排除,而末条 **user** 回合正是这条必须写明的原因:它已落定、又不是末轮,故它
    // **本会**被缓存——于是「编辑重发」会冻在它身上、继续提议替换一个已经不是末轮的回合。新一轮到来的那一刻它又可缓,
    // 而那恰是这个答案翻成 false 的时刻。
    if (!turn.isOpen && !isLast && !canRetry && !canEdit) {
      // The version coordinates go INTO the cache key, not just the turn id: `2/3` is part of what the row
      // renders, and a later page that brings a fourth version in would otherwise leave a cached row
      // claiming `2/3` forever — the same freeze the isLast exclusion above guards against.
      // 版本坐标**进缓存键**、不只是 turn id:`2/3` 是这一行渲染内容的一部分,而后续某页带进第 4 个版本时,被缓存的行
      // 会永远宣称 `2/3`——与上面 isLast 排除所防的是同一种冻结。
      final cacheKey = group.count == 1
          ? turn.id
          : '${turn.id}#${index + 1}/${group.count}';
      row = _settledRowCache[cacheKey] ??= () {
        if (_settledRowCache.length >= _rowCacheCap) {
          _settledRowCache.remove(_settledRowCache.keys.first);
        }
        return _TurnRow(
          turn: turn,
          streaming: false,
          isLast: false,
          conversationId: widget.conversationId,
          versionIndex: index,
          versionCount: group.count,
          onVersion: _versionPicker(group.root.id),
          key: ValueKey(turn.id),
        );
      }();
    } else {
      row = _TurnRow(
        turn: turn,
        streaming: turn.isOpen,
        isLast: isLast,
        conversationId: widget.conversationId,
        canRetry: canRetry,
        canEdit: canEdit,
        versionIndex: index,
        versionCount: group.count,
        onVersion: _versionPicker(group.root.id),
        key: ValueKey(turn.id),
      );
    }
    if (turn.id == _highlightId) {
      row = AnWashHighlight(key: ValueKey('hl-${turn.id}'), child: row);
    }
    return row;
  }

  /// The pager's commit, hoisted OUT of the row: a row is memoized by id, so the selection must live above
  /// it (a per-row choice would be destroyed the moment the cache handed the row back).
  /// 翻页的落点提到**行之外**:行按 id 记忆化,故选择必须住在它上面(逐行的选择会在缓存把行还回来的那一刻被销毁)。
  ValueChanged<int> _versionPicker(String rootId) =>
      (i) => setState(() => _versionChoice[rootId] = i);
}

/// One transcript turn, centered in the reading column with the inter-turn gap. 一条回合(阅读列+轮距)。
class _TurnRow extends ConsumerStatefulWidget {
  const _TurnRow({
    required this.turn,
    required this.streaming,
    required this.isLast,
    required this.conversationId,
    this.canRetry = false,
    this.canEdit = false,
    this.versionIndex = 0,
    this.versionCount = 1,
    this.onVersion,
    super.key,
  });

  final BlockNode turn;
  final bool streaming;

  /// The bottom of the transcript — its action row is always visible (§3.2). transcript 底部,动作排恒显。
  final bool isLast;
  final String conversationId;

  /// This is the tail assistant turn: it may be regenerated (`:retry`). 这是尾巴上的 assistant 回合,可重生成。
  final bool canRetry;

  /// This is the last user turn: it may be edited and resent in place (`:retry {content}`).
  /// 这是末条 user 回合,可原地编辑重发。
  final bool canEdit;

  /// Version coordinates + the pager's commit (owned by the list — a row is memoized by id).
  /// 版本坐标 + 翻页落点(归列表所有——行按 id 记忆化)。
  final int versionIndex;
  final int versionCount;
  final ValueChanged<int>? onVersion;

  @override
  ConsumerState<_TurnRow> createState() => _TurnRowState();
}

class _TurnRowState extends ConsumerState<_TurnRow> {
  // Settled text blocks are memoized by id (C-023): a closed text block's markdown is FINAL (durable,
  // append-only), yet an OPEN turn re-runs this build every tick — without the cache GptMarkdown re-parses
  // EVERY settled prose block per tick, not just the one still-open block. Returning the identical cached
  // widget short-circuits the element rebuild; a theme change still re-renders it (InheritedWidget
  // dependents rebuild regardless of widget identity, so no theme key is needed). Only pure-prop text
  // blocks are cached — a toolCall block watches a live provider (pendingInteractions) and MUST stay
  // reactive, so it is never cached. 已落定 text 块按 id 记忆化:闭块 markdown 终态,但开回合每 tick 重跑此
  // build——无缓存则每 tick 重解析全部落定散块(非仅唯一开块);返回同实例短路重建,换主题仍重渲(继承件依赖与
  // 实例无关,故无需主题键)。只缓纯 prop text 块(toolCall 块 watch 活 provider 须保反应性,绝不缓)。
  final _textCache = <String, Widget>{};

  /// The edit-resend field, alive only while the reader is editing this turn. A controller (not a bare
  /// string) so the caret survives every rebuild the streaming list performs around it.
  /// 编辑重发的输入控制器,仅在读者正编辑本回合期间存在。用 controller(而非裸字符串)使光标能活过流式列表在它周围做的
  /// 每一次重建。
  TextEditingController? _edit;

  @override
  void dispose() {
    _edit?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TranscriptProbe.hit(widget.streaming ? 'leaf-stream' : 'row-settled');
    final role = ConversationTranscript.turnRole(widget.turn);
    final child = role == 'user'
        ? _user(context, ref)
        : _assistant(context, ref);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnSize.content),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AnSpace.s24,
            AnSpace.s12,
            AnSpace.s24,
            AnSpace.s12,
          ),
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }

  Widget _user(BuildContext context, WidgetRef ref) {
    // The id-only `attrs.attachments` snapshot resolves to filename/kind/size via the kept-alive meta
    // provider: loading → a resolving skeleton card, a 404 → the honest missing tombstone.
    // 纯 id 快照经 keepAlive 元数据 provider 解析:加载=resolving 骨架卡;404=诚实 missing 墓碑。
    final attachments = [
      for (final id in ConversationTranscript.turnAttachmentIds(widget.turn))
        switch (ref.watch(attachmentMetaProvider(id))) {
          AsyncData(value: final m) => UserAttachment(
            id: id,
            kind: m.kind,
            filename: m.filename,
            mimeType: m.mimeType.isEmpty ? null : m.mimeType,
            sizeBytes: m.sizeBytes,
            timestampMs: _attachmentTimestampMs(widget.turn, id),
            preparation: m.preparation,
            // Images render as real thumbnails — bytes stream from the sidecar, cached by id in
            // Flutter's ImageCache, DECODED capped to the thumb's widest display (280 logical × dpr):
            // a full-res phone photo would park ~48MB in the cache for a 280px slot (R2).
            // 图片渲真缩略图(字节来自 sidecar,按 id 进全局图缓存,解码封顶缩略最宽档 280×dpr——
            // 全分辨率手机照会为一个 280px 位置吃掉 ~48MB 缓存,R2)。
            thumb: m.kind == 'image'
                ? AttachmentImageProvider(
                    id,
                    fetch: () =>
                        ref.read(chatRepositoryProvider).getAttachmentBytes(id),
                    targetWidth:
                        (AnSize.thumbMaxW *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                  )
                : null,
          ),
          AsyncError(:final error) => UserAttachment(
            id: id,
            kind: 'other',
            filename: id,
            state: _attachmentMetaErrorState(error),
            onTap: () => ref.invalidate(attachmentMetaProvider(id)),
          ),
          _ => UserAttachment(
            id: id,
            kind: 'other',
            filename: id,
            state: AnAttachmentState.resolving,
          ),
        },
    ];
    final editing = _edit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editing swaps the bubble's CHILD, never wraps it: `ChatTurn` stays mounted so the bubble keeps its
        // identity, its width and its place in the reading column while the sentence becomes editable
        // (CLAUDE.md 禁止条件包装 — the ban is on wrappers coming and going, not on content genuinely
        // becoming something else, which is exactly what an in-place edit is).
        // 编辑替换气泡的**子**、绝不包裹它:ChatTurn 保持挂载,故气泡在句子变可编辑期间保住身份、宽度与它在阅读列里的
        // 位置(CLAUDE.md 禁止条件包装——禁的是包装层来来去去、不是内容真的变成了别的东西,而原地编辑正是后者)。
        ChatTurn(
          role: ChatRole.user,
          child: editing == null
              ? UserTurnContent(
                  text: ConversationTranscript.turnText(widget.turn),
                  mentions: ConversationTranscript.turnMentions(widget.turn),
                  attachments: attachments,
                  audioAttachmentBuilder: (a) => _TranscriptAudioAttachment(a),
                )
              : _EditResendField(
                  controller: editing,
                  onCancel: _cancelEdit,
                  onSubmit: _submitEdit,
                ),
        ),
        // The action row stays MOUNTED while editing and merely goes offstage — the sanctioned parameter flip
        // (`Offstage(offstage:)`), not a subtree that comes and goes.
        // 编辑期间动作排保持**挂载**、只是下台——用获准的翻参数形态(`Offstage(offstage:)`),不是来来去去的子树。
        Offstage(
          offstage: editing != null,
          child: _actions(TurnActionsRole.user),
        ),
      ],
    );
  }

  int? _attachmentTimestampMs(BlockNode turn, String attachmentId) {
    final raw =
        turn.content?['audioTimestamps'] ??
        turn.content?['attachmentTimestamps'];
    return switch (raw) {
      Map() => _intMs(raw[attachmentId]),
      List() => _timestampFromList(raw, attachmentId),
      _ => null,
    };
  }

  int? _timestampFromList(List<dynamic> raw, String attachmentId) {
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['attachmentId'] ?? item['id'];
      if (id != attachmentId) continue;
      return _intMs(
        item['timestampMs'] ??
            item['ms'] ??
            item['offsetMs'] ??
            item['startMs'],
      );
    }
    return null;
  }

  int? _intMs(Object? raw) {
    final value = switch (raw) {
      int() => raw,
      num() => raw.round(),
      String() => int.tryParse(raw),
      _ => null,
    };
    if (value == null || value < 0) return null;
    return value;
  }

  AnAttachmentState _attachmentMetaErrorState(Object error) {
    if (error case ApiException(:final isNotFound) when isNotFound) {
      return AnAttachmentState.missing;
    }
    if (error case ApiException(:final isTransport) when isTransport) {
      return AnAttachmentState.offline;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('client_transport') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('no route to host')) {
      return AnAttachmentState.offline;
    }
    if (text.contains('attachment not found') ||
        text.contains('attachment_not_found')) {
      return AnAttachmentState.missing;
    }
    return AnAttachmentState.failed;
  }

  Widget _assistant(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final blocks = <Widget>[
      for (final b in widget.turn.children) ?_block(context, ref, b),
    ];
    final banner = _stopBanner(context, ref);
    if (blocks.isEmpty && banner == null && widget.streaming) {
      // Turn opened, first block not yet — a quiet thinking shimmer placeholder. 回合已开首块未到:静占位。
      blocks.add(
        AnShimmerText(
          t.chat.thinking,
          style: AnText.label.copyWith(color: c.inkMuted),
          reveal: true,
        ),
      );
    }
    return ChatTurn(
      role: ChatRole.assistant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: AnSpace.s12),
            blocks[i],
          ],
          if (banner != null) ...[
            if (blocks.isNotEmpty) const SizedBox(height: AnSpace.s12),
            banner,
          ],
          _actions(TurnActionsRole.assistant),
        ],
      ),
    );
  }

  /// The turn's action row (§3.2). A turn that is still GENERATING gets none: there is nothing to copy
  /// yet, and mid-stream the only meaningful action is Stop, which lives in the composer. Returned as a
  /// zero-height box rather than omitted, so the column's child list keeps its shape and a turn settling
  /// does not remount its siblings (CLAUDE.md 禁止条件包装).
  /// 回合的动作排(§3.2)。**正在生成**的回合没有:此刻无可复制,而流中唯一有意义的动作是「停止」,它住在
  /// composer。返回零高盒而非省略,好让列的 children 保持形状——一条回合落定时不会顶得兄弟节点重挂。
  Widget _actions(TurnActionsRole role) {
    if (widget.streaming) return const SizedBox.shrink();
    // The model list is read ONLY on the row that can actually retry — one extra watch on one row, not a
    // capability list per turn in the transcript. A conditional watch is legal in Riverpod (this is not a hook).
    //
    // The thread's current model is deliberately NOT read here. It would mean a second subscription — to
    // `conversationHeaderProvider`, the one provider CH-b already found has no `retry:` override, so a failed
    // read backs off and re-polls forever behind a row that has already degraded. All it would buy is a
    // check-mark next to one model name; the menu's own first row already says「重试」and means "keep whatever
    // this thread is set to", which is the honest statement either way.
    // 模型列表**只在真能重试的那一行**读——一行多一次订阅,而不是让 transcript 里每个回合都订阅一份能力列表。
    // Riverpod 允许条件 watch(它不是 hook)。
    //
    // 线程当前的模型**刻意不在此读**。那会多一次订阅——订 `conversationHeaderProvider`,而它正是 CH-b 已经查明
    // 「没有 `retry:` 覆盖」的那个 provider:一次失败的读会退避重试、在一个已经优雅降级的行后面永远轮询。它换来的
    // 只是某个模型名旁边的一个勾;而菜单第一行本就写着「重试」、意思是「用这条线程现有的设置」,两种情形下都诚实。
    final caps = widget.canRetry
        ? (ref.watch(modelCapabilitiesProvider).value ??
              const <ModelCapability>[])
        : const <ModelCapability>[];
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s4),
      child: TurnActions(
        copyText: ConversationTranscript.turnCopyText(widget.turn),
        role: role,
        alwaysVisible: widget.isLast,
        onFork: _fork,
        onRetry: widget.canRetry ? _retry : null,
        retryCaps: caps,
        onEdit: widget.canEdit ? _startEdit : null,
        versionIndex: widget.versionIndex,
        versionCount: widget.versionCount,
        onVersion: widget.onVersion,
      ),
    );
  }

  /// Regenerate this answer as a NEW VERSION (`:retry`), optionally with a different model.
  ///
  /// "Is the thread busy" is checked AT TAP TIME rather than carried as a prop, for the same reason the fork
  /// cut point is: a settled row is memoized by id, so a prop would freeze at the moment the row was built and
  /// a stale `false` would let a click through mid-generation. Reading the controller on tap always sees now.
  /// The backend refuses that click anyway (409 on a non-terminal tail) — this is so the reader is told WHY
  /// instead of watching an action fail.
  ///
  /// The pager is pointed at the version that is about to exist (index == the current count): once the new
  /// version lands the count grows by one and that index IS the newest, so the reply the reader just asked for
  /// is the one they watch stream. If the request fails, the same index clamps harmlessly back to the current
  /// version.
  ///
  /// 把这个回答作为**新版本**重生成(`:retry`),可选换模型。
  ///
  /// 「线程忙不忙」在**点击时**查、不作 prop 传,理由与分叉切点相同:落定行按 id 记忆化,prop 会冻结在建行那一刻,一个过期的
  /// `false` 会让一次点击在生成中放行。点击时读控制器永远看到「现在」。后端本就会拒那次点击(非终态尾巴 409)——这里是为了让
  /// 读者被**告知原因**,而不是看着一个动作失败。
  ///
  /// 翻页被指向**即将存在**的那一版(下标 == 当前版本数):新版本一落地,版本数加一,该下标**就是**最新那一版,故读者刚要的
  /// 那个回复正是他看着流出来的那个。请求失败时同一个下标无害地钳回现行版。
  Future<void> _retry(
    ({String apiKeyId, String modelId})? modelOverride,
  ) async {
    if (_refuseWhileBusy()) return;
    widget.onVersion?.call(widget.versionCount);
    try {
      await ref
          .read(chatRepositoryProvider)
          .retryTurn(widget.conversationId, modelOverride: modelOverride);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.chat.actionFailed, tone: AnTone.danger);
    }
  }

  /// Put the sentence back into an editable state, in place. The transcript's own text is the seed — the
  /// composer is not involved, because「原地换整轮」means the reader edits where the sentence already is.
  /// 把句子原地放回可编辑态。种子取 transcript 自己的文本——不牵扯 composer,因为「原地换整轮」的意思正是读者在句子
  /// **本来所在的地方**编辑它。
  void _startEdit() {
    if (_refuseWhileBusy()) return;
    setState(
      () => _edit = TextEditingController(
        text: ConversationTranscript.turnText(widget.turn),
      ),
    );
  }

  void _cancelEdit() {
    final ctl = _edit;
    setState(() => _edit = null);
    ctl?.dispose();
  }

  /// Resend the edited sentence as a new version of the whole round (`:retry {content}`) — the server replaces
  /// both halves, so nothing here has to guess at the answer. An empty edit is a cancel: replacing a message
  /// with nothing is not a message.
  /// 把编辑后的句子作为整个回合的新版本重发(`:retry {content}`)——服务端替换两半,故此处无需对回答做任何猜测。空的编辑
  /// 等同取消:把一条消息换成什么都没有,那不是一条消息。
  Future<void> _submitEdit() async {
    final text = _edit?.text.trim() ?? '';
    if (text.isEmpty) {
      _cancelEdit();
      return;
    }
    if (_refuseWhileBusy()) return;
    _cancelEdit();
    widget.onVersion?.call(widget.versionCount);
    try {
      await ref
          .read(chatRepositoryProvider)
          .retryTurn(widget.conversationId, content: text);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.chat.actionFailed, tone: AnTone.danger);
    }
  }

  /// True (and says so) when a turn is in flight: `:retry` replaces the LAST ROUND, and a round that has not
  /// finished is not a round to replace. 有回合在飞时返 true 并说明:`:retry` 替换**末回合**,而一个没结束的回合不是可
  /// 替换的回合。
  bool _refuseWhileBusy() {
    final busy = ref
        .read(conversationStreamProvider(widget.conversationId).notifier)
        .transcript
        .value
        .hasInFlight;
    if (busy) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.chat.actions.retryBusy);
    }
    return busy;
  }

  /// Branch this turn into a new conversation, then open it.
  ///
  /// The cut point is resolved AT TAP TIME off the live turn list rather than passed in as a prop: a
  /// settled row is memoized by id (`_settledRowCache`), so a "previous turn id" prop would freeze at
  /// the moment the row was first built and a deep-jump window that prepends history would leave it
  /// stale. Reading the controller on tap always sees the current list.
  ///
  /// Two shapes, because the two roles mean different things (§3.2): forking an ASSISTANT turn keeps
  /// everything through that reply (`atMessageId` = this turn); forking a USER turn means "stop before
  /// I said this", so the cut is the PREVIOUS turn and the sentence comes back as composer draft text.
  /// A user turn with nothing before it forks to the LANDING — a thread where nothing has been said IS
  /// the landing, so minting an empty twin would be a worse answer than going there.
  ///
  /// 把本回合分叉成新对话并打开它。
  ///
  /// 切点在**点击时**据活回合列表求得、而非作为 prop 传入:落定行按 id 记忆化(`_settledRowCache`),故
  /// 「上一回合 id」这个 prop 会**冻结在行首次构建那一刻**,而向前追加历史的深跳窗会让它过期。点击时读控制器
  /// 永远看到当前列表。
  ///
  /// 两种形态,因为两个角色含义不同(§3.2):分叉 **assistant** 回合保留直到那条回复的一切(atMessageId=本回合);
  /// 分叉 **user** 回合意为「停在我说出这句之前」,故切点是**上一条**回合、而这句话作为 composer 草稿回来。
  /// 前面什么都没有的 user 回合分叉到 **landing**——什么都没说过的线程**就是** landing,铸一个空的孪生线程
  /// 是比去那里更差的答案。
  Future<void> _fork() async {
    final role = ConversationTranscript.turnRole(widget.turn);
    var atMessageId = widget.turn.id;
    var prefill = '';
    if (role == 'user') {
      prefill = ConversationTranscript.turnText(widget.turn);
      final turns = ref
          .read(conversationStreamProvider(widget.conversationId).notifier)
          .transcript
          .value
          .turns;
      final i = turns.indexWhere((n) => n.id == widget.turn.id);
      atMessageId = i > 0 ? turns[i - 1].id : '';
    }
    try {
      final result = await ref.read(forkConversationProvider)(
        widget.conversationId,
        atMessageId: atMessageId,
        prefill: prefill,
      );
      if (!mounted) return;
      context.go(
        result.landing ? '/' : conversationLocation(result.conversationId),
      );
    } catch (_) {
      if (!mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.chat.actionFailed, tone: AnTone.danger);
    }
  }

  Widget? _block(BuildContext context, WidgetRef ref, BlockNode b) {
    final c = context.colors;
    final t = Translations.of(context);
    switch (b.kind) {
      case BlockKind.text:
        // An OPEN text block is still growing — it rides AnStreamingMarkdown (S9): prose already
        // streamed past a safe paragraph boundary is committed into identity-cached segments, so a
        // coalesced frame re-parses ONLY the active tail (a bare AnMarkdown re-parsed the whole
        // growing string every frame, O(full text) — the last steady-state hot path). A CLOSED
        // block's markdown is final → cache it by id, so an open turn's per-tick rebuild reuses the
        // SAME instance and GptMarkdown never re-parses settled prose.
        // 开块走 AnStreamingMarkdown(S9):流过安全段界的 prose 提交成身份缓存段,合并帧只重解析活动
        // 尾段(裸 AnMarkdown 每帧全文重解析,O(全文)——最后一个稳态热路径);闭块终态按 id 缓存。
        if (b.isOpen) {
          TranscriptProbe.hit('block-text-live');
          return _StreamingAnswerMarkdown(b.displayText);
        }
        return _textCache.putIfAbsent(b.id, () {
          TranscriptProbe.hit('block-text-parse');
          return _AnswerMarkdown(b.displayText);
        });
      case BlockKind.reasoning:
        return ChatThinking(
          text: b.displayText,
          streaming: b.isOpen,
          liveLabel: t.chat.thinking,
          settledLabel: t.chat.thought,
        );
      case BlockKind.toolCall:
        // The V3a chassis (WRK-053) + the V6 human gate: the pending-interaction record for THIS
        // tool_call (keyed by block id) drives the awaiting gate / decided provenance章; resolving POSTs
        // through the provider. Watching only this block's slice keeps unrelated gate changes from
        // rebuilding the whole card. V3a 底盘 + V6 人闸:本块的待决记录驱动门/出处章;select 单块切片。
        final record = ref.watch(
          pendingInteractionsProvider(
            widget.conversationId,
          ).select((m) => m[b.id]),
        );
        return ChatToolCard(
          node: b,
          interaction: record,
          onResolve: (action, {answer}) => ref
              .read(pendingInteractionsProvider(widget.conversationId).notifier)
              .resolve(b.id, action, answer: answer),
          key: ValueKey('tool-${b.id}'),
        );
      case BlockKind.toolResult || BlockKind.progress:
        return null; // children of the tool card — never top-level noise 工具卡子块,不作顶层噪声
      case BlockKind.compaction:
        // The context-compaction whisper — a system timeline marker, localized from the block's marker.
        // 上下文压缩低语——系统时间轴标记,从块 marker 本地化。
        return ChatContextMark(marker: b.displayText);
      case BlockKind.marker:
        // A durable in-line MARK about the conversation itself. Today there is exactly one kind — the
        // residency switched mid-thread — and the payload rides `attrs` (hydrated INTO content by
        // hydrateBlockContent), never the content column, which is empty by contract so the label can be
        // localized. An unknown future kind renders NOTHING rather than a raw attrs dump: this row is chrome
        // between turns, and a mark nobody can read is worse than a mark nobody sees.
        // 关于对话本身的持久**行内标记**。今天恰有一种 kind——驻地在线程中途被切换——载荷搭 `attrs`(由
        // hydrateBlockContent 水化**进** content)、绝不搭 content 列(它按契约为空,使标签可本地化)。未来的未知 kind
        // 渲**什么都不渲**、而不是把 attrs 倒出来:这一行是回合之间的 chrome,一条没人读得懂的标记比一条没人看见的更糟。
        if (b.content?['kind'] != 'workdir') return null;
        return ChatWorkDirMark(
          from: (b.content?['from'] as String?) ?? '',
          to: (b.content?['to'] as String?) ?? '',
        );
      case BlockKind.message:
        // A nested subagent's message wrapper is flattened INTO its parent tool card (ToolCardState.of),
        // never rendered as a top-level transcript row. 嵌套 subagent 的 message 包装摊平进工具卡,不作顶层行。
        return null;
      case BlockKind.unknown:
        return Text(
          b.displayText,
          style: AnText.label.copyWith(color: c.inkFaint),
        ); // never a silent hole 绝不无声
    }
  }

  /// The honest turn-end line for non-clean terminals (cancelled / error / limits). end_turn = nothing.
  /// LLM_RESOLVE_ERROR grows a「重选模型」CTA (拍板 #16): a deleted key's session override must stay
  /// sacred, so the fix is offered where the failure shows — the same model menu the head carries.
  /// 非干净终态的诚实一行;end_turn 无横幅。LLM_RESOLVE_ERROR 长出「重选模型」CTA(拍板 #16):删 key 后
  /// 会话覆写神圣不动,修复入口就长在失败处——与头部同一份模型菜单。
  Widget? _stopBanner(BuildContext context, WidgetRef ref) {
    if (widget.streaming) return null;
    final t = Translations.of(context);
    final c = context.colors;
    final stop = (widget.turn.content?['stopReason'] as String?) ?? '';
    if (stop.isEmpty || stop == 'end_turn') return null;
    final (label, color) = switch (stop) {
      'cancelled' => (t.chat.stoppedCancelled, c.inkFaint),
      'max_steps' => (t.chat.stoppedMaxSteps, c.warn),
      'context_budget' => (t.chat.stoppedBudget, c.warn),
      // max_tokens = the response was TRUNCATED at the output-length limit — a normal (status=completed)
      // turn, not an error. An amber limit note, NOT the red error banner. max_tokens 是正常截断非错误。
      'max_tokens' => (t.chat.stoppedMaxTokens, c.warn),
      _ => (t.chat.stoppedError, c.danger),
    };
    final code = (widget.turn.content?['errorCode'] as String?) ?? '';
    final msg = (widget.turn.content?['errorMessage'] as String?) ?? '';
    final detail = [code, msg].where((s) => s.isNotEmpty).join(' · ');
    final line = Text(
      detail.isEmpty ? label : '$label · $detail',
      style: AnText.label.copyWith(color: color),
    );
    if (code != 'LLM_RESOLVE_ERROR') return line;
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];
    final override = ref
        .watch(conversationHeaderProvider(widget.conversationId))
        .value
        ?.modelOverride;
    return Row(
      children: [
        Flexible(child: line),
        const SizedBox(width: AnSpace.s8),
        chatModelMenu(
          t: t,
          caps: caps,
          current: override == null
              ? null
              : (apiKeyId: override.apiKeyId, modelId: override.modelId),
          onSelect: (v) => ref
              .read(conversationHeaderProvider(widget.conversationId).notifier)
              .setModel(v),
          anchorBuilder: (context, toggle, isOpen) => AnButton(
            label: t.chat.repickModel,
            size: AnButtonSize.sm,
            onPressed: toggle,
          ),
        ),
      ],
    );
  }
}

class _TranscriptAudioAttachment extends ConsumerStatefulWidget {
  const _TranscriptAudioAttachment(this.attachment);

  final UserAttachment attachment;

  @override
  ConsumerState<_TranscriptAudioAttachment> createState() =>
      _TranscriptAudioAttachmentState();
}

class _TranscriptAudioAttachmentState
    extends ConsumerState<_TranscriptAudioAttachment> {
  AttachmentAudioPlaybackController? _playbackController;
  bool _wasActive = false;

  @override
  void dispose() {
    // The row owns the visible playback lifetime. If the active audio row leaves the tree because the
    // user switched conversations or navigated away, stop through the controller captured during build
    // instead of reading ref during dispose (Riverpod marks that unsafe).
    // 播放生命周期归音频行。active 行因切会话/离开页面卸载时，用 build 阶段捕获的 controller 停止；
    // dispose 内不再读 ref。
    final controller = _playbackController;
    if (_wasActive && controller != null) unawaited(controller.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final playback = ref.watch(attachmentAudioPlaybackProvider);
    _playbackController = ref.read(attachmentAudioPlaybackProvider.notifier);
    _wasActive = playback.isActive(widget.attachment.id);
    final duration = playback.durationFor(widget.attachment.id);
    final playbackError = playback.errorFor(widget.attachment.id);
    final missing = playbackError == AttachmentAudioError.attachmentMissing;
    final state = missing ? AnAttachmentState.missing : widget.attachment.state;
    final statusLine = playback.isLoading(widget.attachment.id)
        ? t.attach.loadingAudio
        : playbackError == AttachmentAudioError.playbackFailed
        ? t.attach.audioPlaybackFailed
        : playbackError == AttachmentAudioError.attachmentOffline
        ? t.attach.audioPlaybackOffline
        : missing
        ? null
        : attachmentPreparationLine(t, widget.attachment.preparation);
    return AnAudioAttachmentCard(
      filename: widget.attachment.filename,
      metaLine: attachmentMetaLine(
        filename: widget.attachment.filename,
        mimeType: widget.attachment.mimeType,
        sizeBytes: widget.attachment.sizeBytes,
      ),
      durationLabel: audioDurationLabel(
        duration?.inMilliseconds ?? widget.attachment.durationMs,
      ),
      timestampLabel: audioDurationLabel(widget.attachment.timestampMs),
      statusLine: statusLine,
      busy: playback.isLoading(widget.attachment.id),
      progress: playback.progressFor(widget.attachment.id),
      playing: playback.isPlaying(widget.attachment.id),
      state: state,
      onPlayTap: state == AnAttachmentState.ready
          ? () => ref
                .read(attachmentAudioPlaybackProvider.notifier)
                .toggleUrl(
                  widget.attachment.id,
                  loadUrl: () async => ref
                      .read(chatRepositoryProvider)
                      .createAttachmentPlaybackLease(widget.attachment.id)
                      .then((lease) => lease.url),
                  mimeType: widget.attachment.mimeType,
                )
          : null,
      onTimestampTap:
          state == AnAttachmentState.ready &&
              widget.attachment.timestampMs != null
          ? () {
              ref
                  .read(attachmentAudioPlaybackProvider.notifier)
                  .seek(
                    widget.attachment.id,
                    Duration(milliseconds: widget.attachment.timestampMs!),
                  );
            }
          : null,
      onTap: widget.attachment.onTap,
    );
  }
}

/// The in-place edit-resend field: the sentence, editable, with Cancel / Resend right under it (§3.2
/// 「原地换整轮」). Multiline, because a chat message is prose and an edit that could not reach the second
/// paragraph would only be an edit of short messages. Enter inserts a newline (the field is a textarea, not
/// the composer) — resending is an explicit act, since it replaces a round rather than adding one.
///
/// It is a local composition of kit primitives (`AnInput` + two `AnButton`s), not a new primitive: nothing
/// else in the app edits a transcript turn, so there is no second caller to share a widget with.
///
/// 原地编辑重发的输入面:句子本身可编辑,下面紧跟取消 / 重发(§3.2「原地换整轮」)。多行——聊天消息是散文,一个到不了第二段
/// 的编辑只能算短消息的编辑。Enter 换行(这是文本域、不是 composer)——重发是明确的动作,因为它**替换**一个回合而非新增一个。
///
/// 它是套件原语的**局部组合**(`AnInput` + 两个 `AnButton`)、不是新原语:app 里没有第二处会编辑 transcript 回合,故没有第二个
/// 调用方可与之共享一个 widget。
class _EditResendField extends StatelessWidget {
  const _EditResendField({
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnInput(
          controller: controller,
          multiline: true,
          block: true,
          autofocus: true,
          semanticLabel: t.chat.actions.editResend,
        ),
        const SizedBox(height: AnSpace.s8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnButton(
              label: t.action.cancel,
              size: AnButtonSize.sm,
              onPressed: onCancel,
            ),
            const SizedBox(width: AnSpace.s8),
            AnButton(
              label: t.chat.actions.editResendSubmit,
              size: AnButtonSize.sm,
              variant: AnButtonVariant.primary,
              onPressed: onSubmit,
            ),
          ],
        ),
      ],
    );
  }
}

/// An optimistic user bubble: dimmed while in flight; failed grows retry / discard. 乐观泡:在途淡显;失败长钮。
class _PendingRow extends ConsumerWidget {
  const _PendingRow({
    required this.conversationId,
    required this.pending,
    super.key,
  });

  final String conversationId;
  final PendingSend pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnSize.content),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AnSpace.s24,
            AnSpace.s12,
            AnSpace.s24,
            AnSpace.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ChatTurn(
                role: ChatRole.user,
                sending: !pending.failed,
                // The optimistic bubble is the SAME message as the reconciled one (UserTurnContent) —
                // both prose on the 15 reading rung, or the bubble reflows the instant the echo lands.
                // 乐观泡与回声后的泡是同一条消息:同走 15 阅读档,否则回声一到就重排。
                child: Text(
                  pending.text,
                  style: AnText.reading.copyWith(color: c.ink),
                ),
              ),
              if (pending.failed)
                Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AnIcons.error, size: AnSize.icon, color: c.danger),
                      const SizedBox(width: AnSpace.s6),
                      Text(
                        t.chat.sendFailed,
                        style: AnText.label.copyWith(color: c.danger),
                      ),
                      const SizedBox(width: AnSpace.s8),
                      AnButton(
                        label: t.chat.retrySend,
                        size: AnButtonSize.sm,
                        onPressed: () => ref
                            .read(
                              conversationStreamProvider(
                                conversationId,
                              ).notifier,
                            )
                            .retrySend(pending.localId),
                      ),
                      AnButton(
                        label: t.chat.discard,
                        size: AnButtonSize.sm,
                        onPressed: () => ref
                            .read(
                              conversationStreamProvider(
                                conversationId,
                              ).notifier,
                            )
                            .discardFailed(pending.localId),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chat MESSAGE BUBBLE markdown (辖区 of the CONTENT ② font axis) — a thin Consumer over [AnMarkdown]
/// that reads `contentFaceProvider` so the assistant's prose switches to serif / system LIVE (no restart)
/// while everything framing it (tool cards, chrome) stays on the UI face. It's cached by block id in the
/// transcript (`_textCache`) exactly like the bare AnMarkdown was — being a ConsumerWidget, a cached
/// instance still rebuilds when the face flips (Riverpod re-runs its element), so the perf win (settled
/// prose isn't re-parsed every streaming tick) AND the live switch both hold. chat 消息泡 markdown(内容轴
/// 辖区):薄 Consumer 读内容脸,助手 prose 即时切衬线/系统而 chrome 不变;按块 id 缓存如旧,face 变时缓存实例
/// 仍重建(Riverpod),既保「已落定 prose 不逐 tick 重解析」又保即时切换。
class _AnswerMarkdown extends ConsumerWidget {
  const _AnswerMarkdown(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AnMarkdown(text, prose: ref.watch(contentFaceProvider));
}

/// The OPEN (still-streaming) answer face — [AnStreamingMarkdown] with the same content-face
/// injection as [_AnswerMarkdown] (S9). 流式开块答案脸——同款内容字体注入的 AnStreamingMarkdown。
class _StreamingAnswerMarkdown extends ConsumerWidget {
  const _StreamingAnswerMarkdown(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AnStreamingMarkdown(text, prose: ref.watch(contentFaceProvider));
}
