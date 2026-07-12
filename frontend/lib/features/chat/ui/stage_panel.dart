import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/model/partial_json.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../model/stage_director.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../state/conversation_stream_provider.dart';
import '../state/rundown_provider.dart';
import '../state/stage_director_provider.dart';
import '../state/stage_expansion.dart';
import '../state/touchpoint_ledger.dart';
import 'stages/attachment_pedestal.dart';
import 'stages/scene_from_truth.dart';
import 'stages/stage_registry.dart';
import 'stages/stage_scene.dart';
import 'stages/subagent_stage.dart';
import 'tool_card_skins.dart';
import '../state/flowrun_progress.dart';

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
      String subjectWord(StageActivityView? a) => a?.itemId ?? a?.kind ?? '';
      void announce(String msg) =>
          SemanticsService.sendAnnouncement(View.of(context), msg, Directionality.of(context));
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

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnInspectorHead(
        label: t.chat.stage.island,
        // The follow three-notch + expand-all / collapse-all (all 16px, left-island icon language).
        // 跟随三档 + 展开/收起全部(皆 16px,左岛 icon 语言)。
        actions: [
          _FollowMenu(),
          _ExpandAllButton(conversationId: conversationId),
          _CollapseAllButton(conversationId: conversationId),
        ],
        // ✕ collapses the right island (unified across every island, WRK-064). ✕ 收岛(统一)。
        onClose: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
        closeSemantics: t.shell.togglePanel,
      ),
      Expanded(child: _AccordionList(conversationId: conversationId)),
    ]);
  }
}

/// The head's «展开全部» — opens the todo row + every ledger row. 展开全部。
class _ExpandAllButton extends ConsumerWidget {
  const _ExpandAllButton({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    return AnButton.iconOnly(
      AnIcons.unfold,
      semanticLabel: t.chat.stage.expandAll,
      onPressed: () {
        final ledger = ref.read(touchpointLedgerProvider(conversationId));
        ref.read(stageExpansionProvider(conversationId).notifier).expandAll([
          'todo',
          for (final e in ledger.entities) '${e.kind}:${e.key}',
        ]);
      },
    );
  }
}

/// The head's «收起全部» — an explicit collapse that wins over the sticky-open rule. 收起全部。
class _CollapseAllButton extends ConsumerWidget {
  const _CollapseAllButton({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    return AnButton.iconOnly(
      AnIcons.fold,
      semanticLabel: t.chat.stage.collapseAll,
      onPressed: () => ref.read(stageExpansionProvider(conversationId).notifier).collapseAll(),
    );
  }
}

/// One accordion row's spec — a ledger [entity] and/or a [view] (the live activity overlaying it), OR a
/// settled [subagentNode] (a closed `Subagent` run rehydrated from the transcript — no touchpoint, no
/// ledger row, WRK-064 B6). A pure-live row (no ledger yet) has [entity] null; a settled entity row has
/// [view] null; a settled subagent row has both null and [subagentNode] set. 一行的规格。
class _RowSpec {
  const _RowSpec({required this.rowId, this.entity, this.view, this.subagentNode});

  final String rowId;
  final CastEntity? entity;
  final StageActivityView? view;

  /// A closed subagent tool_call (folded nested trajectory) — the settled subagent row's whole payload.
  /// 落定 subagent 的折好节点(整行载荷)。
  final BlockNode? subagentNode;

  bool get live => view != null;
}

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

  /// Live blocks already auto-opened once — each live activity claims the viewport at most once (§4-2).
  /// 已自动展开过的 live block(每 live 一生一次)。
  final Set<String> _autoHandled = {};

  /// The user grabbed the scroll → suspend all auto-scroll until they return to the bottom (§4-3).
  /// 用户接管滚动 → 挂起自动滚,回底才恢复。
  bool _takeover = false;

  /// Per-row keys for [Scrollable.ensureVisible]. 每行 key(用于滚入视口)。
  final Map<String, GlobalKey> _rowKeys = {};

  // The settled-subagent rows (WRK-064 B6) come from the transcript, which the director / ledger the list
  // watches do NOT track — a reload folds subagents in, a scroll pages more, neither firing a watched
  // provider. Subscribe to the transcript coalescer and rebuild ONLY when the set of subagent runs (or an
  // open→closed flip) changes — NOT on every streaming delta, keeping the ≤1-rebuild-per-meaningful-change
  // discipline the coalescer exists for. 订阅 transcript,仅 subagent 集/开合变化才重建(非逐帧)。
  CoalescingNotifier<ConversationTranscript>? _tx;
  String _subagentSig = '';

  String get conversationId => widget.conversationId;

  void _syncTranscript(CoalescingNotifier<ConversationTranscript> tx) {
    if (identical(tx, _tx)) return;
    _tx?.removeListener(_onTranscript);
    _tx = tx;
    tx.addListener(_onTranscript);
    _subagentSig = _sigOf(tx.value);
  }

  void _onTranscript() {
    final tx = _tx;
    if (tx == null) return;
    final sig = _sigOf(tx.value);
    if (sig != _subagentSig && mounted) {
      setState(() => _subagentSig = sig);
    }
  }

  static String _sigOf(ConversationTranscript t) =>
      [for (final n in t.subagentBlocks) '${n.id}:${n.isOpen}'].join(',');

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
      _rowKeys.clear();
    }
  }

  @override
  void dispose() {
    _tx?.removeListener(_onTranscript);
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String rowId) => _rowKeys.putIfAbsent(rowId, () => GlobalKey());

  // §4-3 — a USER-initiated scroll (direction ≠ idle) suspends auto-scroll; returning near the bottom
  // resumes it. ScrollUpdateNotification is NEVER treated as takeover (else a programmatic ensureVisible
  // would self-lock). 用户手动滚即挂起,回底恢复;update 帧一律不当接管(否则 ensureVisible 自锁)。
  bool _onScroll(ScrollNotification n) {
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
      _takeover = true;
    } else if (n is ScrollEndNotification && _isNearTop) {
      _takeover = false;
    }
    return false;
  }

  // The list is TOP-anchored (todo + live rows ride offset≈0; the oldest ledger + load-more foot sit at the
  // bottom), so auto-follow re-arms when the user returns to the TOP — where live activity lands — NOT the
  // bottom (that would demand scrolling past every paged-in old entity to re-arm). 顶锚列表:回顶即重武装。
  bool get _isNearTop {
    if (!_scroll.hasClients) return false;
    final p = _scroll.position;
    if (!p.hasContentDimensions) return false;
    return p.pixels <= p.minScrollExtent + 80; // threshold, never atEdge/exact 阈值,不用 atEdge
  }

  // §4-1/§4-2 — the director staged a NEW subject (follow already gated it): open its row (sticky) and
  // scroll it into view ONCE. Also migrate the expansion key when a subject's itemId finally resolves
  // (block:<id> → kind:<itemId>) so the auto-opened row stays open across the key change.
  // 导演器登了新主角(follow 已放行):展开其行(粘性)+ 滚入视口一次;itemId 解出时迁移展开键。
  void _onDirector(StageState? prev, StageState next) {
    final subj = next.subject;
    if (subj == null) return;
    final block = subj.blockId;
    final id = subj.itemId;
    final resolvedRow = (id != null && id.isNotEmpty) ? '${subj.kind}:$id' : null;
    final blockRow = 'block:$block';
    final expNotifier = ref.read(stageExpansionProvider(conversationId).notifier);
    if (resolvedRow != null) {
      final exp = ref.read(stageExpansionProvider(conversationId));
      if (exp.contains(blockRow) && !exp.contains(resolvedRow)) {
        expNotifier.close(blockRow);
        expNotifier.open(resolvedRow);
        _autoHandled.add(block); // already handled — the migrate is the open 迁移即已处理
      }
    }
    if (!next.stageOpen || _autoHandled.contains(block)) return;
    _autoHandled.add(block);
    final rowId = resolvedRow ?? blockRow;
    expNotifier.open(rowId);
    _scrollToRow(rowId);
  }

  void _scrollToRow(String rowId) {
    if (_takeover) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _takeover || !_scroll.hasClients) return;
      final ctx = _rowKeys[rowId]?.currentContext;
      if (ctx == null) return; // not built = far off-screen → don't chase (§4-2) 未构建=远在视口外,不追
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
        alignment: 0.5, // centre-reveal, so it never brushes the bottom edge + re-arms follow 居中揭示
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: AnMotion.mid,
        curve: Curves.easeInOut,
      );
    });
  }

  List<_RowSpec> _computeRows(
      StageState stage, TouchpointLedgerState ledger, ConversationTranscript transcript) {
    // Live activities by rowId (resolved itemId → kind:itemId; else block:<blockId> so it still shows +
    // can be auto-expanded — resolving migrates the key). 活动按 rowId(未解出用 blockId 键)。
    final viewByRow = <String, StageActivityView>{};
    void addView(StageActivityView? a, {required bool gate}) {
      if (a == null || (gate && !stage.stageOpen)) return;
      final id = a.itemId;
      final rid = (id != null && id.isNotEmpty) ? '${a.kind}:$id' : 'block:${a.blockId}';
      viewByRow.putIfAbsent(rid, () => a); // subject added first wins its slot 主角先占
    }
    addView(stage.subject, gate: true);
    for (final ch in stage.channels) {
      addView(ch, gate: false);
    }

    final specs = <_RowSpec>[];
    final ledgerKeys = {for (final e in ledger.entities) '${e.kind}:${e.key}'};
    // Synthetic live rows (a live activity with no ledger row yet) ride on top, in insertion order
    // (subject first). 合成 live 行置顶(主角先)。
    for (final entry in viewByRow.entries) {
      if (!ledgerKeys.contains(entry.key)) {
        specs.add(_RowSpec(rowId: entry.key, view: entry.value));
      }
    }
    // Third source (WRK-064 B6): SETTLED subagent runs. A `Subagent` tool_call has no touchpoint (never a
    // ledger row); once CLOSED and its director channel dropped, list it here with its folded nested
    // trajectory. LIVE subagents ride the director path above (same `block:<id>` rowId → the row stays put
    // through its settle, zero jump); skip any rowId a live view / ledger already covers. Kept in the top
    // region beside the synthetic live rows so a live→settled transition never relocates the row.
    // 第三源:落定 subagent(无触点无 ledger)——谢幕后按 block:<id> 列此,同 live 合成行键→归队零跳。
    for (final node in transcript.subagentBlocks) {
      if (node.isOpen) continue; // a live subagent is the director's job 活的归 director
      final rid = 'block:${node.id}';
      if (viewByRow.containsKey(rid) || ledgerKeys.contains(rid)) continue;
      specs.add(_RowSpec(rowId: rid, subagentNode: node));
    }
    for (final e in ledger.entities) {
      specs.add(_RowSpec(rowId: '${e.kind}:${e.key}', entity: e, view: viewByRow['${e.kind}:${e.key}']));
    }
    return specs;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(stageDirectorProvider(conversationId), _onDirector);
    final t = Translations.of(context);
    final stage = ref.watch(stageDirectorProvider(conversationId));
    final ledger = ref.watch(touchpointLedgerProvider(conversationId));
    final expanded = ref.watch(stageExpansionProvider(conversationId));
    final boards = ref.watch(rundownProvider(conversationId));
    final transcript = ref.watch(conversationStreamProvider(conversationId).notifier).transcript;
    _syncTranscript(transcript);

    final hasTodo = boards.values.any((b) => b.todos.isNotEmpty);
    final rows = _computeRows(stage, ledger, transcript.value);

    // Empty / loading / failed — only when there's nothing to show at all (no rows, no todo, no live).
    // 空/加载/失败:仅当无行、无 todo、无 live。
    if (rows.isEmpty && !hasTodo) {
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
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        icon: AnIcons.entities,
        title: t.chat.stage.castEmpty,
        hint: t.chat.stage.castEmptyHint,
      );
    }

    final todoCount = hasTodo ? 1 : 0;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4, vertical: AnSpace.s4),
        itemCount: todoCount + rows.length + (ledger.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (hasTodo && i == 0) {
            return KeyedSubtree(
              key: _keyFor('todo'),
              child: _TodoRow(conversationId: conversationId, open: expanded.contains('todo')),
            );
          }
          final idx = i - todoCount;
          if (idx >= rows.length) {
            // load-more foot — fires on becoming visible, DEFERRED out of build: loadMore() synchronously
            // mutates the ledger provider this widget watches, and calling it inside itemBuilder (a build
            // phase) trips Riverpod's «modify a provider while building» guard. 载更多脚:post-frame 延迟出
            // build——loadMore 同步变异本 widget watch 的 provider,build 期直调会触发 Riverpod 守卫。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(touchpointLedgerProvider(conversationId).notifier).loadMore();
            });
            return const Padding(padding: EdgeInsets.all(AnSpace.s8), child: AnSkeleton.row());
          }
          final spec = rows[idx];
          return KeyedSubtree(
            key: _keyFor(spec.rowId),
            child: _StageRow(
              conversationId: conversationId,
              spec: spec,
              open: expanded.contains(spec.rowId),
              transcript: transcript,
              stagePhase: stage.phase,
              subjectBlockId: stage.subject?.blockId,
            ),
          );
        },
      ),
    );
  }
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
    final nonEmpty = [
      for (final e in boards.entries)
        if (e.value.todos.isNotEmpty) e.value,
    ]..sort((a, b) => a.subagentId.compareTo(b.subagentId)); // main ("") first 主清单在前
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    final total = nonEmpty.fold(0, (n, b) => n + b.todos.length);
    final done = nonEmpty.fold(0, (n, b) => n + b.completed);
    void toggle() => ref.read(stageExpansionProvider(conversationId).notifier).toggle('todo');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
      AnExpandReveal(
        open: open,
        child: Padding(
          // Same breathing shape as the stage rows: symmetric 8 vertical, full box width. 与舞台行同形。
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
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
        ),
      ),
    ]);
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
    required this.stagePhase,
    required this.subjectBlockId,
  });

  final String conversationId;
  final _RowSpec spec;
  final bool open;
  final CoalescingNotifier<ConversationTranscript> transcript;
  final StagePhase stagePhase;
  final String? subjectBlockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final director = ref.read(stageDirectorProvider(conversationId).notifier);
    final entity = spec.entity;
    final view = spec.view;
    final subNode = spec.subagentNode;
    final kind = entity?.kind ?? view?.kind ?? (subNode != null ? 'subagent' : 'tool');
    final name = entity?.displayName ??
        view?.itemId ??
        view?.toolName ??
        (subNode != null
            ? (argStringPartial(subNode.argumentsText, 'description') ?? t.chat.stage.subagentUnnamed)
            : spec.rowId);
    final tombstoned = entity?.tombstoned ?? false;

    final String meta;
    if (entity != null) {
      final p = entity.primary;
      meta = p.count > 1
          ? '${AnCastRow.verbWord(t, p.verb)} ×${p.count}'
          : AnCastRow.verbWord(t, p.verb);
    } else if (subNode != null) {
      meta = t.chat.stage.delegated; // a settled delegated run — quiet, no live dot 落定委派,无蓝点
    } else {
      meta = t.chat.stage.live;
    }

    void toggle() => ref.read(stageExpansionProvider(conversationId).notifier).toggle(spec.rowId);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnRow(
        icon: AnIcons.entityKindGlyph(kind),
        label: name,
        meta: meta,
        selected: open,
        collapsible: true,
        open: open,
        // A live activity earns the persistent blue dot; a clean tombstone/settled row stays quiet.
        // live 得常驻蓝点;落定/墓碑安静。
        trailingDot: spec.live ? AnStatus.run : null,
        onSelect: toggle,
        onToggle: toggle,
      ),
      AnExpandReveal(
        open: open,
        child: Padding(
          // Symmetric 8 above/below (the card must not glue to its header row), 0 left/right — the body
          // spans the FULL header-box width: hierarchy reads from position, a narrower card just looks
          // misaligned (user-tuned). 上下对称 8(卡不贴行头)、左右 0——体与行头框同宽;瘦一圈反显没对齐。
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
          child: spec.live && view != null
              ? _GenericStage(
                  conversationId: conversationId,
                  subject: view,
                  phase: view.blockId == subjectBlockId
                      ? stagePhase
                      : (view.failed ? StagePhase.failedHold : StagePhase.following),
                  transcript: transcript,
                  onPin: () => director.pin(blockId: view.blockId),
                  onItemResolved: (itemId) => director.itemResolved(view.blockId, itemId),
                )
              // A settled subagent run — its folded nested trajectory rendered as a live:false stage (no
              // entity, no touchpoint; the transcript IS its truth, WRK-064 B6). 落定 subagent 嵌套轨迹。
              : subNode != null
                  ? SubagentStageBody(scene: sceneFromSubagentNode(subNode, conversationId))
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
                              fallback: entity)
                          : SettledBody(conversationId: conversationId, entity: entity, tombstoned: tombstoned))
                  : const SizedBox.shrink(),
        ),
      ),
    ]);
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
    required this.onPin,
    required this.onItemResolved,
  });

  final String conversationId;
  final StageActivityView subject;
  final StagePhase phase;
  final CoalescingNotifier<ConversationTranscript> transcript;
  final VoidCallback onPin;
  final void Function(String itemId) onItemResolved;

  @override
  State<_GenericStage> createState() => _GenericStageState();
}

class _GenericStageState extends State<_GenericStage> {
  String? _resolved;

  static const _frameworkKeys = {'summary', 'danger', 'execution_group'};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<ConversationTranscript>(
      valueListenable: widget.transcript,
      builder: (context, transcript, _) {
        final node = transcript.liveBlock(widget.subject.blockId);
        if (node == null) {
          // Not in the live reducer (row expanded after a reload) — honest placeholder. 诚实占位。
          return Padding(
            padding: const EdgeInsets.all(AnSpace.s8),
            child: AnHonestyRibbon(widget.subject.live ? AnHonesty.gap : AnHonesty.live),
          );
        }
        final state = ToolCardState.of(node);
        final session = state.argsSession;
        final name = _subjectName(state, session);
        // R-6: hand the resolved primary id to the director for the Cast pulse + row-key migration.
        // 主目标 id 喂导演器(Cast 脉冲 + 行键迁移)。
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
          // Reading INSIDE a stage = holding the camera: a user mid-read is never auto-switched away.
          // Only user gestures count. 舞台内滚动=持镜(只认用户手势)。
          onNotification: (n) {
            if (n.dragDetails != null) widget.onPin();
            return false;
          },
          child: GestureDetector(
            onTapDown: (_) => widget.onPin(),
            behavior: HitTestBehavior.translucent,
            // No brow — the accordion ROW HEADER is the identity (kind glyph · name · live dot); the body
            // is just the stage content + the honesty ribbon (live/failed truth). 无眉:行头即身份。
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (failed || live) ...[
                AnHonestyRibbon(failed ? AnHonesty.failed : AnHonesty.live),
                const SizedBox(height: AnSpace.s6),
              ],
              if (stageRouteOf(widget.subject.toolName)?.lifecycle == LifecycleSource.poll)
                _RunProgressSection(blockId: widget.subject.blockId),
              // Live streaming churn is semantics-noise — the four announcements carry meaning. 流式区静音。
              ExcludeSemantics(
                excluding: live,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bespoke != null)
                      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s8), child: bespoke(context, scene))
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
    final n = session.closedStringAt(['name']) ?? session.inFlightStringAt(['name']);
    if (n != null && n.isNotEmpty) return n;
    return '';
  }

  List<Widget> _body(BuildContext context, AnColors c, ToolCardState state, PartialJsonSession session,
      bool live, bool failed) {
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
        AnWindow(child: Text(tailLines(tail.text, 8), style: AnText.code.copyWith(color: c.inkMuted))),
      ],
      if (!live && !failed) ...[
        const SizedBox(height: AnSpace.s6),
        runStatBarOf(context, state),
      ],
      if (failed && state.errorText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        Text(state.errorText,
            maxLines: 3, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.danger)),
      ],
      const SizedBox(height: AnSpace.s8),
    ];
  }
}

/// The follow-mode three-notch menu on the sidestage head — the standing «AI 干活自动展开» consent, its
/// pulse (activity) icon at the 16px chrome tier. 跟随三档菜单(activity 脉冲 icon)。
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
          AnIcons.activity,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (rows.isEmpty && progress.terminal.isEmpty)
          AnShimmerText(t.chat.stage.run.queued, style: AnText.meta.copyWith(color: c.inkFaint), reveal: true),
        // Family rows (批6 A-074): the semantic dot replaces the icon trio (its iconSm-2 arithmetic
        // dies; fromRaw folds parked→wait amber, running→run accent — truer than «every non-terminal
        // amber»); the loop turn joins the chips ('#N', the hand-glued ' · ' dies, 文法 #3). 族行:
        // 语义点替三态图标(算术亡;fromRaw 语义更真);轮次进 chips(手拼点链亡)。
        for (final n in rows)
          AnLedgerRow(
            lead: AnStatusDot(AnStatus.fromRaw(n.status)),
            primary: n.nodeId,
            chips: [
              if (n.iteration > 0) Text('#${n.iteration}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
              if (n.status == 'parked') Text(t.chat.stage.run.parked, style: AnText.meta.copyWith(color: c.warn)),
              if (n.port.isNotEmpty) AnChip('→ ${n.port}', tone: AnTone.accent),
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
            }),
          ),
        ],
      ]),
    );
  }
}
