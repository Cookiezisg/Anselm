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
import '../model/user_attachment.dart';
import '../state/conversation_stream_provider.dart';
import '../state/conversation_stream_state.dart';
import 'chat_turn.dart';
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

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _attached?.removeListener(_onTick);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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

  void _jumpToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < pos.maxScrollExtent) _scroll.jumpTo(pos.maxScrollExtent);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _pinned = pos.maxScrollExtent - pos.pixels <= _pinSlack;
    if (pos.pixels - pos.minScrollExtent <= _loadOlderSlack) {
      // Guarded inside the controller (cursor/loading/hasMore). 控制器内自守。
      ref.read(conversationStreamProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.watch(conversationStreamProvider(widget.conversationId).notifier);
    final loadingOlder = ref.watch(
        conversationStreamProvider(widget.conversationId).select((s) => s.loadingOlder));
    // Re-read the listenable each build — it is a NEW instance after a controller rebuild (the
    // documented coalescer discipline). 每 build 重取 listenable(controller 重建后是新实例)。
    final transcript = ctl.transcript;
    _attach(transcript);
    return ValueListenableBuilder<ConversationTranscript>(
      valueListenable: transcript,
      builder: (context, t, _) {
        TranscriptProbe.hit('list');
        final older = t.settled.take(t.olderCount).toList(growable: false);
        final head = [...t.settled.skip(t.olderCount), ...t.liveTurns];
        final pending = t.pending;
        return CustomScrollView(
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
                        child: Center(
                            child: SizedBox(
                                width: AnSize.icon,
                                height: AnSize.icon,
                                child: CircularProgressIndicator.adaptive(strokeWidth: 2))),
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
      },
    );
  }

  // Terminal rows come from the identity cache (an identical instance short-circuits the element
  // rebuild — settled turns cost ZERO builds during streaming); the open turn builds fresh per tick.
  // 终态行走身份缓存(同实例短路重建——流式中 settled 行零 build);open 回合逐 tick 新建。
  Widget _rowFor(BlockNode turn) {
    if (!turn.isOpen) {
      return _settledRowCache[turn.id] ??=
          _TurnRow(turn: turn, streaming: false, key: ValueKey(turn.id));
    }
    return _TurnRow(turn: turn, streaming: true, key: ValueKey(turn.id));
  }
}

/// One transcript turn, centered in the reading column with the inter-turn gap. 一条回合(阅读列+轮距)。
class _TurnRow extends StatelessWidget {
  const _TurnRow({required this.turn, required this.streaming, super.key});

  final BlockNode turn;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    TranscriptProbe.hit(streaming ? 'leaf-stream' : 'row-settled');
    final role = ConversationTranscript.turnRole(turn);
    final child = role == 'user' ? _user(context) : _assistant(context);
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

  Widget _user(BuildContext context) {
    // Attachment metadata resolution lands with the composer-upload slice; ids render as minimal cards
    // meanwhile (honest, never hidden). 附件元数据解析随上传片落;此前 id 渲最简卡(诚实不藏)。
    final attachments = [
      for (final id in ConversationTranscript.turnAttachmentIds(turn))
        UserAttachment(id: id, kind: 'other', filename: id),
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

  Widget _assistant(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final blocks = <Widget>[
      for (final b in turn.children) ?_block(context, b),
    ];
    final banner = _stopBanner(context);
    if (blocks.isEmpty && banner == null && streaming) {
      // Turn opened, first block not yet — a quiet thinking shimmer placeholder. 回合已开首块未到:静占位。
      blocks.add(AnShimmerText(t.chat.thinking,
          style: AnText.meta.copyWith(color: c.inkMuted), reveal: true));
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

  Widget? _block(BuildContext context, BlockNode b) {
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
        // The minimal stand-in until the V3 chassis: glyph + humanized name, honest and quiet.
        // V3 前的最简占位:字形 + 名称,诚实安静。
        final name = b.name ?? '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AnIcons.toolIcon(name), size: AnSize.iconSm, color: c.inkFaint),
            const SizedBox(width: AnSpace.s6),
            Flexible(
              child: b.isOpen
                  ? AnShimmerText(name.isEmpty ? '…' : name,
                      style: AnText.meta.copyWith(color: c.inkMuted))
                  : Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AnText.meta.copyWith(color: c.inkMuted)),
            ),
          ],
        );
      case BlockKind.toolResult || BlockKind.progress:
        return null; // fold under the tool chassis at V4/V5 — not top-level noise 归 V4/V5,不作顶层噪声
      case BlockKind.compaction:
        return Center(
          child: Text('· ${b.displayText} ·',
              style: AnText.meta.copyWith(color: c.inkFaint)),
        );
      case BlockKind.message:
        return null; // nested subagent turns join the transcript at V5 嵌套 subagent 回合 V5 接入
      case BlockKind.unknown:
        return Text(b.displayText,
            style: AnText.meta.copyWith(color: c.inkFaint)); // never a silent hole 绝不无声
    }
  }

  /// The honest turn-end line for non-clean terminals (cancelled / error / limits). end_turn = nothing.
  /// 非干净终态的诚实一行(取消/错误/限额);end_turn 无横幅。
  Widget? _stopBanner(BuildContext context) {
    if (streaming) return null;
    final t = Translations.of(context);
    final c = context.colors;
    final stop = (turn.content?['stopReason'] as String?) ?? '';
    if (stop.isEmpty || stop == 'end_turn') return null;
    final (label, color) = switch (stop) {
      'cancelled' => (t.chat.stoppedCancelled, c.inkFaint),
      'max_steps' => (t.chat.stoppedMaxSteps, c.warn),
      'context_budget' => (t.chat.stoppedBudget, c.warn),
      _ => (t.chat.stoppedError, c.danger),
    };
    final code = (turn.content?['errorCode'] as String?) ?? '';
    final msg = (turn.content?['errorMessage'] as String?) ?? '';
    final detail = [code, msg].where((s) => s.isNotEmpty).join(' · ');
    return Text(
      detail.isEmpty ? label : '$label · $detail',
      style: AnText.meta.copyWith(color: color),
    );
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
                child: Text(pending.text, style: AnText.body.copyWith(color: c.ink)),
              ),
              if (pending.failed)
                Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AnIcons.error, size: AnSize.iconSm, color: c.danger),
                      const SizedBox(width: AnSpace.s6),
                      Text(t.chat.sendFailed, style: AnText.meta.copyWith(color: c.danger)),
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
