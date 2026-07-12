import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/messages/block_content.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../data/attachment_image_provider.dart';
import '../data/chat_providers.dart';
import '../state/attachment_meta.dart';
import '../model/user_attachment.dart';
import '../state/conversation_stream_provider.dart';
import '../state/conversation_stream_state.dart';
import '../state/pending_interactions_provider.dart';
import '../state/transcript_jump_provider.dart';
import '../../../core/model/model_capabilities.dart';
import '../state/conversation_header.dart';
import 'chat_head.dart';
import 'chat_tool_card.dart';
import 'chat_turn.dart';
import 'chat_context_mark.dart';
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
    final phase =
        ref.watch(conversationStreamProvider(conversationId).select((s) => s.phase));
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
              onPressed: () =>
                  ref.read(conversationStreamProvider(conversationId).notifier).retryHydrate(),
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
  static const double _pinSlack = 48; // within this of the bottom = pinned 距底此内=钉住
  static const double _loadOlderSlack = 300; // near-top prefetch band 近顶预取带

  final ScrollController _scroll = ScrollController();
  final Map<String, Widget> _settledRowCache = {};
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
    _scroll.jumpTo((-(AnSize.islandHead + AnSpace.s12))
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble());
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
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
      ref.read(conversationStreamProvider(widget.conversationId).notifier).loadOlder();
    }
    if (pos.maxScrollExtent - pos.pixels <= _loadOlderSlack) {
      // Window mode's forward continuation — same guard style, downward. 窗口模式向前续翻,同守卫。
      ref.read(conversationStreamProvider(widget.conversationId).notifier).loadNewer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.watch(conversationStreamProvider(widget.conversationId).notifier);
    final loadingOlder = ref.watch(
        conversationStreamProvider(widget.conversationId).select((s) => s.loadingOlder));
    ref.listen(transcriptJumpProvider(widget.conversationId), (_, req) {
      if (req != null) unawaited(_executeJump(req));
    });
    // Leaving the jump window (the pill / an implicit send) re-docks to the present. A fast
    // re-hydrate can keep this SAME State alive (no initState re-dock), so the transition must
    // re-pin explicitly — rejoining without re-docking maroons the reader mid-history.
    // 离开跳转窗(pill/发送隐式)即重新贴底。快速重拉可能不换 State(无 initState 重靠),转变必须显式
    // 重钉——归队不贴底=把读者晾在史中。
    ref.listen(conversationStreamProvider(widget.conversationId).select((s) => s.windowMode),
        (prev, next) {
      if (prev == true && next == false) {
        _pinned = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      }
    });
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
        final older = t.settled.take(t.olderCount).toList(growable: false);
        final head = [
          ...t.settled.skip(t.olderCount),
          if (!windowMode) ...t.liveTurns,
        ];
        final pending = windowMode ? const <PendingSend>[] : t.pending;
        final list = CustomScrollView(
          controller: _scroll,
          center: _centerKey,
          slivers: [
            // ABOVE the anchor: older pages, reversed so index 0 sits adjacent to the center. 锚上:老页。
            SliverPadding(
              padding: const EdgeInsets.only(top: AnSize.islandHead + AnSpace.s12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: older.length + (loadingOlder ? 1 : 0),
                  (context, i) {
                    if (i == older.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AnSpace.s12),
                        child: Center(child: AnSpinner()),
                      );
                    }
                    return _rowFor(older[older.length - 1 - i]);
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
                    if (i < head.length) return _rowFor(head[i]);
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
        return Stack(children: [
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
                    .read(conversationStreamProvider(widget.conversationId).notifier)
                    .backToLive(),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // Terminal rows come from the identity cache (an identical instance short-circuits the element
  // rebuild — settled turns cost ZERO builds during streaming); the open turn builds fresh per tick.
  // 终态行走身份缓存(同实例短路重建——流式中 settled 行零 build);open 回合逐 tick 新建。
  Widget _rowFor(BlockNode turn) {
    Widget row;
    if (!turn.isOpen) {
      row = _settledRowCache[turn.id] ??= _TurnRow(
          turn: turn, streaming: false, conversationId: widget.conversationId, key: ValueKey(turn.id));
    } else {
      row = _TurnRow(
          turn: turn, streaming: true, conversationId: widget.conversationId, key: ValueKey(turn.id));
    }
    if (turn.id == _highlightId) {
      row = _JumpHighlight(key: ValueKey('hl-${turn.id}'), child: row);
    }
    return row;
  }
}

/// The jump target's landing wash: hold, then ease out (the Slack-permalink rhythm Stream Chat
/// converged on). Purely decorative — reduced motion collapses it to the end state instantly.
/// 跳转落点洗亮:先驻留后淡出(Slack permalink 节奏)。纯装饰——reduced motion 直接落终态。
class _JumpHighlight extends StatelessWidget {
  const _JumpHighlight({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 2200),
      // Hold for ~1s (the flat half), then ease out. 前半驻留,后半淡出。
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
      builder: (context, wash, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.accentSoft.withValues(alpha: c.accentSoft.a * wash),
          borderRadius: BorderRadius.circular(AnRadius.card),
        ),
        child: child,
      ),
      child: child,
    );
  }
}


/// One transcript turn, centered in the reading column with the inter-turn gap. 一条回合(阅读列+轮距)。
class _TurnRow extends ConsumerWidget {
  const _TurnRow(
      {required this.turn, required this.streaming, required this.conversationId, super.key});

  final BlockNode turn;
  final bool streaming;
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TranscriptProbe.hit(streaming ? 'leaf-stream' : 'row-settled');
    final role = ConversationTranscript.turnRole(turn);
    final child = role == 'user' ? _user(context, ref) : _assistant(context, ref);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnSize.content),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AnSpace.s24, AnSpace.s12, AnSpace.s24, AnSpace.s12),
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
      for (final id in ConversationTranscript.turnAttachmentIds(turn))
        switch (ref.watch(attachmentMetaProvider(id))) {
          AsyncData(value: final m) => UserAttachment(
              id: id, kind: m.kind, filename: m.filename,
              mimeType: m.mimeType.isEmpty ? null : m.mimeType, sizeBytes: m.sizeBytes,
              // Images render as real thumbnails — bytes stream from the sidecar, cached by id in
              // Flutter's ImageCache. 图片渲真缩略图(字节来自 sidecar,按 id 进全局图缓存)。
              thumb: m.kind == 'image'
                  ? AttachmentImageProvider(id,
                      fetch: () => ref.read(chatRepositoryProvider).getAttachmentBytes(id))
                  : null),
          AsyncError() => UserAttachment(
              id: id, kind: 'other', filename: id, state: AnAttachmentState.missing),
          _ => UserAttachment(
              id: id, kind: 'other', filename: id, state: AnAttachmentState.resolving),
        },
    ];
    return ChatTurn(
      role: ChatRole.user,
      child: UserTurnContent(
        text: ConversationTranscript.turnText(turn),
        mentions: ConversationTranscript.turnMentions(turn),
        attachments: attachments,
      ),
    );
  }

  Widget _assistant(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final blocks = <Widget>[
      for (final b in turn.children) ?_block(context, ref, b),
    ];
    final banner = _stopBanner(context, ref);
    if (blocks.isEmpty && banner == null && streaming) {
      // Turn opened, first block not yet — a quiet thinking shimmer placeholder. 回合已开首块未到:静占位。
      blocks.add(AnShimmerText(t.chat.thinking,
          style: AnText.label.copyWith(color: c.inkMuted), reveal: true));
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
        ],
      ),
    );
  }

  Widget? _block(BuildContext context, WidgetRef ref, BlockNode b) {
    final c = context.colors;
    final t = Translations.of(context);
    switch (b.kind) {
      case BlockKind.text:
        return AnMarkdown(b.displayText);
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
            pendingInteractionsProvider(conversationId).select((m) => m[b.id]));
        return ChatToolCard(
          node: b,
          interaction: record,
          onResolve: (action, {answer}) => ref
              .read(pendingInteractionsProvider(conversationId).notifier)
              .resolve(b.id, action, answer: answer),
          key: ValueKey('tool-${b.id}'),
        );
      case BlockKind.toolResult || BlockKind.progress:
        return null; // children of the tool card — never top-level noise 工具卡子块,不作顶层噪声
      case BlockKind.compaction:
        // The context-compaction whisper — a system timeline marker, localized from the block's marker.
        // 上下文压缩低语——系统时间轴标记,从块 marker 本地化。
        return ChatContextMark(marker: b.displayText);
      case BlockKind.message:
        // A nested subagent's message wrapper is flattened INTO its parent tool card (ToolCardState.of),
        // never rendered as a top-level transcript row. 嵌套 subagent 的 message 包装摊平进工具卡,不作顶层行。
        return null;
      case BlockKind.unknown:
        return Text(b.displayText,
            style: AnText.label.copyWith(color: c.inkFaint)); // never a silent hole 绝不无声
    }
  }

  /// The honest turn-end line for non-clean terminals (cancelled / error / limits). end_turn = nothing.
  /// LLM_RESOLVE_ERROR grows a「重选模型」CTA (拍板 #16): a deleted key's session override must stay
  /// sacred, so the fix is offered where the failure shows — the same model menu the head carries.
  /// 非干净终态的诚实一行;end_turn 无横幅。LLM_RESOLVE_ERROR 长出「重选模型」CTA(拍板 #16):删 key 后
  /// 会话覆写神圣不动,修复入口就长在失败处——与头部同一份模型菜单。
  Widget? _stopBanner(BuildContext context, WidgetRef ref) {
    if (streaming) return null;
    final t = Translations.of(context);
    final c = context.colors;
    final stop = (turn.content?['stopReason'] as String?) ?? '';
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
    final code = (turn.content?['errorCode'] as String?) ?? '';
    final msg = (turn.content?['errorMessage'] as String?) ?? '';
    final detail = [code, msg].where((s) => s.isNotEmpty).join(' · ');
    final line = Text(
      detail.isEmpty ? label : '$label · $detail',
      style: AnText.label.copyWith(color: color),
    );
    if (code != 'LLM_RESOLVE_ERROR') return line;
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];
    final override =
        ref.watch(conversationHeaderProvider(conversationId)).value?.modelOverride;
    return Row(children: [
      Flexible(child: line),
      const SizedBox(width: AnSpace.s8),
      chatModelMenu(
        t: t,
        caps: caps,
        current: override == null
            ? null
            : (apiKeyId: override.apiKeyId, modelId: override.modelId),
        onSelect: (v) =>
            ref.read(conversationHeaderProvider(conversationId).notifier).setModel(v),
        anchorBuilder: (context, toggle, isOpen) =>
            AnButton(label: t.chat.repickModel, size: AnButtonSize.sm, onPressed: toggle),
      ),
    ]);
  }
}

/// An optimistic user bubble: dimmed while in flight; failed grows retry / discard. 乐观泡:在途淡显;失败长钮。
class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.conversationId, required this.pending, super.key});

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
          padding: const EdgeInsets.fromLTRB(AnSpace.s24, AnSpace.s12, AnSpace.s24, AnSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ChatTurn(
                role: ChatRole.user,
                sending: !pending.failed,
                // The optimistic bubble is the SAME message as the reconciled one (UserTurnContent) —
                // both prose on the 15 reading rung, or the bubble reflows the instant the echo lands.
                // 乐观泡与回声后的泡是同一条消息:同走 15 阅读档,否则回声一到就重排。
                child: Text(pending.text, style: AnText.reading.copyWith(color: c.ink)),
              ),
              if (pending.failed)
                Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AnIcons.error, size: AnSize.icon, color: c.danger),
                      const SizedBox(width: AnSpace.s6),
                      Text(t.chat.sendFailed, style: AnText.label.copyWith(color: c.danger)),
                      const SizedBox(width: AnSpace.s8),
                      AnButton(
                        label: t.chat.retrySend,
                        size: AnButtonSize.sm,
                        onPressed: () => ref
                            .read(conversationStreamProvider(conversationId).notifier)
                            .retrySend(pending.localId),
                      ),
                      AnButton(
                        label: t.chat.discard,
                        size: AnButtonSize.sm,
                        onPressed: () => ref
                            .read(conversationStreamProvider(conversationId).notifier)
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
