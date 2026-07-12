import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../state/pending_interactions_provider.dart';
import 'tool_card_catalog.dart';
import 'tool_card_reveal.dart';
import 'tool_interaction_gate.dart';

/// The V3a tool-call CHASSIS (WRK-053 · WRK-065) — one borderless 32px-register line per tool
/// call (decision #2: bare row, the expanded body owns the only container), carrying the whole
/// lifecycle: args-streaming / awaiting-confirm / running (shimmer verb + quiet elapsed counter
/// after 3s) / succeeded / failed (auto-expands once) / denied / cancelled. DEFAULT COLLAPSED,
/// always (WRK-065, user decree): nothing auto-opens while running — the family body owns TWO
/// faces behind the user's chevron (in flight = the live streaming stage; settled = the record).
/// The only auto-expansions: a failure (once) and the human gate (locked open). The verb comes
/// from the registry ([toolCardStrings], decision #1); the GENERIC body — intent · args JSON ·
/// progress tail · result · error — caps hard with honest truncation notes.
///
/// V3a 工具卡**底盘**(WRK-053 · WRK-065)——每次调用一条无边框 32px 档的裸行(拍板 #2:行裸、容器
/// 只属于展开体),承载完整生命周期。**默认永远收起**(WRK-065,用户定调):运行中绝不自动弹窗——族体
/// 在用户 chevron 后拥有**两张脸**(在飞=流式舞台;落定=档案)。仅有的自动展开:失败(一次)与人闸
/// (锁开)。动词出自注册表(拍板 #1);通用体硬上限 + 诚实截断注记。
class ChatToolCard extends StatefulWidget {
  const ChatToolCard({required this.node, this.interaction, this.onResolve, super.key});

  /// The tool_call [BlockNode] (children carry nested progress / tool_result). 工具调用节点。
  final BlockNode node;

  /// The human-loop record for THIS tool_call (from pendingInteractionsProvider, threaded by the
  /// transcript so the card stays a pure prop widget): awaiting → the gate renders LOCKED-OPEN; a
  /// positive decision → a provenance章 in the expanded body; null → no gate.
  /// 本 tool_call 的人在环记录(transcript 下喂,卡保持纯 prop):待决→锁定展开门;正向决议→展开体出处章;null→无门。
  final InteractionRecord? interaction;

  /// The danger/ask gate's decision sink (POST happens in the provider). 门决议回调(POST 在 provider)。
  final void Function(InteractionAction action, {String? answer})? onResolve;

  @override
  State<ChatToolCard> createState() => _ChatToolCardState();
}

/// Display caps for the generic skin — a transcript row must never own a 256KB scroller
/// (F173 lineage); the full payload stays a REST fact, the card shows an honest excerpt.
/// 通用皮肤显示上限——transcript 行绝不背 256KB 滚动区(F173 血统);全量是 REST 事实,卡给诚实节选。
const int _capChars = 4000;
const int _progressTailLines = 12;
const int _jsonInlineMaxLines = 14;

/// The elapsed counter stays hidden for quick calls; only a call outliving this reads a timer
/// (industry norm: quiet seconds after ~3s, never a progress bar).
/// 快调用不显计时;超过此时长才读秒(业界惯例:~3s 后安静读秒,绝不进度条)。
const Duration _elapsedRevealAfter = Duration(seconds: 3);

class _ChatToolCardState extends State<ChatToolCard> {
  bool? _userExpanded; // null until the user touches the chevron 用户未碰前为 null
  bool _autoExpandedOnce = false;
  Timer? _ticker;

  /// Did THIS widget instance witness the running→settled transition this session? A settle-only
  /// family's body (ToolHitList) plays its one-time reveal ONLY when this is true — so a fresh mount
  /// of an OLD card (history reload / scroll-back re-mount, phase already succeeded, no transition
  /// seen) stays instant, never replaying. Card-level (not widget-local-below) because the collapsed
  /// row outlives any body expansion. 本卡实例是否亲历 running→落定;settle-only 体据此播一次揭示,历史
  /// 重载/滚回重挂(相位已 succeeded、未见过渡)即显不重放。
  bool _transitionObserved = false;

  /// Seconds ticked since mount while live — tick-counted (not a wall-clock Stopwatch) so the
  /// fake test clock drives it and reduced motion simply never counts.
  /// live 期挂载以来的秒数——按 tick 计数(非墙钟 Stopwatch),测试假钟可驱动、reduced 下自然不计。
  int _liveSeconds = 0;

  // ONE live predicate — the same phase set the display uses (argsStreaming/running). The old
  // isOpen/no-result heuristic diverged on awaitingConfirm: the ticker kept counting HUMAN wait
  // time (and rebuilding every second) while the card sat parked on the gate, then reported it
  // as tool elapsed. 单一 live 谓词=显示同款相位集;旧启发式在 awaitingConfirm 下把人等的时间计进
  // 工具耗时、且停在门上仍每秒重建。
  bool get _live {
    final awaiting = widget.interaction?.isAwaiting ?? false;
    final phase = ToolCardState.of(widget.node, awaitingConfirm: awaiting).phase;
    return phase == ToolCardPhase.argsStreaming || phase == ToolCardPhase.running;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ChatToolCard old) {
    super.didUpdateWidget(old);
    // Witness the running→settled transition (a fresh mount of an already-settled card never does).
    // 亲历 running→落定(已落定卡的新挂载不会触发)。
    final wasLive = _isLivePhase(ToolCardState.of(old.node).phase);
    final nowSettled = ToolCardState.of(widget.node).phase == ToolCardPhase.succeeded;
    if (wasLive && nowSettled) _transitionObserved = true;
    _syncTicker();
  }

  static bool _isLivePhase(ToolCardPhase p) =>
      p == ToolCardPhase.argsStreaming || p == ToolCardPhase.running;

  /// Run the 1s tick only while live AND motion is allowed — under reduced motion the counter
  /// must not keep the tree eternally busy (the gallery/test batteries pumpAndSettle there).
  /// 只在 live 且允许动效时走 1s tick——reduced 下计时不得让树永不安定(gallery/测试电池在彼处
  /// pumpAndSettle)。
  void _syncTicker() {
    final wantTicker = _live && !AnMotionPref.reduced(context);
    if (wantTicker && _ticker == null) {
      _ticker = Timer.periodic(
          const Duration(seconds: 1), (_) => setState(() => _liveSeconds++));
    } else if (!wantTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final awaiting = widget.interaction?.isAwaiting ?? false;
    final state = ToolCardState.of(widget.node, awaitingConfirm: awaiting);
    final spec = toolCardSpecFor(state.toolName);
    final live = state.phase == ToolCardPhase.argsStreaming || state.phase == ToolCardPhase.running;
    if (!live && _ticker != null) _syncTicker();

    const bodyInsetGate = EdgeInsets.only(top: AnSpace.s6, left: AnSize.icon + AnSpace.s6);
    // The HUMAN GATE (WRK-053 §V6): an awaiting danger/ask interaction renders the gate LOCKED-OPEN
    // under a bare amber verb line — a question the user MUST act on can never hide behind a chevron.
    // 人闸:待决交互在琥珀动词裸行下锁定展开门——必须动手的问题不能藏在 chevron 后。
    if (state.phase == ToolCardPhase.awaitingConfirm && widget.interaction != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(context, t, c, state, spec, false, false, false, null),
          Padding(padding: bodyInsetGate, child: _gate(context, widget.interaction!.interaction)),
        ],
      );
    }

    // Failure auto-expands ONCE (industry consensus) — including a DANGER-TONED family
    // receipt (Bash exit≠0 / timeout close with status=completed on the wire, but the user
    // wants to see why). The user's explicit toggle wins after.
    // 失败自动展开一次(业界共识)——含**危险色族回执**(Bash 非零 exit/超时在线缆上是 completed,
    // 但用户要看原因);之后用户手动开关优先。
    final hasBody = !spec.bodyless && (spec.hasBodyOf?.call(state) ?? state.hasBody);
    ToolReceipt? familyReceipt;
    if (state.phase == ToolCardPhase.succeeded || state.phase == ToolCardPhase.failed) {
      familyReceipt = spec.receipt?.call(t, state);
    }
    // «green but broken» (F05 §4): a tool_result that closed status=completed but whose PAYLOAD carries
    // a failure (restart_handler's `error` key, a document soft-fail template) — the family reclassifies
    // it so the card doesn't render a lying success. 结果内失败重分类:工具绿但物已坏。
    final resultFailed = state.phase == ToolCardPhase.succeeded && (spec.resultFailed?.call(state) ?? false);
    // A danger receipt auto-expands — UNLESS the family suppresses it (BashOutput poll honesty: exited/
    // errored are red but not re-opened each poll; session-gone still expands via resultFailed).
    // 危险回执自动展开,除非族抑制(BashOutput 轮询诚实)。
    final dangerReceiptExpands = familyReceipt?.tone == ToolReceiptTone.danger && !spec.suppressReceiptAutoExpand;
    final failedLook = state.phase == ToolCardPhase.failed || resultFailed || dangerReceiptExpands;
    if (failedLook && hasBody && !_autoExpandedOnce) {
      _autoExpandedOnce = true;
      _userExpanded ??= true;
    }
    final open = (_userExpanded ?? false) && hasBody;

    const bodyInset = EdgeInsets.only(top: AnSpace.s4, left: AnSize.icon + AnSpace.s6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(context, t, c, state, spec, live, open, hasBody, familyReceipt),
        AnExpandReveal(
          open: open,
          child: Padding(
            // Body left inset derives from the line's icon geometry (icon + its gap) so the
            // sections align under the verb — self-healing if the icon size retunes.
            // 体左内距从行的图标几何派生(icon+间距),段落齐动词——图标改尺寸自愈。
            padding: bodyInset,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provenance章: a positive decision (approve / approve_always) leaves a session-only
                  // proof at the top of the body — the tool then ran its normal lifecycle below.
                  // 出处章:正向决议(允许/总是允许)在体首留会话级凭据,其下是工具正常生命周期。
                  ?_provenanceChip(context, c),
                  // A settle-only family body (ToolHitList) reads [ToolCardReveal] to play its one-time
                  // reveal only when THIS instance witnessed the settle. 族体读揭示信号:仅亲历落定时播。
                  ToolCardReveal(
                    revealOnMount: _transitionObserved,
                    child: spec.body?.call(context, state) ?? _GenericToolBody(state: state),
                  ),
                  // Family bodies get the error section from the CHASSIS — every family shows
                  // failures without re-implementing them (the generic body has its own). A family that
                  // OWNS its error display (spec.ownsError) opts out. 族体错误段由底盘追加;自管族退出。
                  if (spec.body != null &&
                      !spec.ownsError &&
                      (state.phase == ToolCardPhase.failed && (state.errorText.isNotEmpty || state.resultText.isNotEmpty)))
                    Padding(
                      padding: const EdgeInsets.only(top: AnSpace.s8),
                      child: _errorSection(context, state),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the danger/ask gate from the awaiting interaction (locked-open under the row). 从待决交互建门。
  Widget _gate(BuildContext context, Interaction it) {
    final ask = it.kind == InteractionKind.ask;
    return ToolInteractionGate(
      kind: ask ? GateKind.ask : GateKind.danger,
      prompt: ask ? (it.message ?? '') : (it.summary ?? ''),
      toolName: it.tool,
      evidence: it.args ?? const {},
      options: it.options ?? const [],
      allowFreeText: ask,
      onResolve: (action, {answer}) => widget.onResolve?.call(action, answer: answer),
    );
  }

  /// The session-only provenance章 for a positively-decided gate (approve / approve_always). deny leaves
  /// a denied phase (prose), so no chip is needed there. 正向决议的会话级出处章(deny 走 denied 相位、无需)。
  Widget? _provenanceChip(BuildContext context, AnColors c) {
    final decided = widget.interaction?.decided;
    if (decided != InteractionAction.approve && decided != InteractionAction.approveAlways) return null;
    final t = Translations.of(context);
    final always = decided == InteractionAction.approveAlways;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnChip(always ? t.chat.gate.decidedApprovedAlways : t.chat.gate.decidedApproved,
            tone: always ? AnTone.accent : AnTone.ok),
      ),
    );
  }

  Widget _line(BuildContext context, Translations t, AnColors c, ToolCardState state,
      ToolCardSpec spec, bool live, bool open, bool hasBody, ToolReceipt? familyReceipt) {
    final reduced = AnMotionPref.reduced(context);
    // The primary line sits INSIDE the 15 content column — one-rung lift to the content label tier
    // (verb 13 / icon 16 / target mono 13); the dimmed receipt tail STAYS meta 12 (true metadata).
    // 主行在 15 内容列内——抬到内容标签档(动词 13/图标 16/target mono 13);灰回执尾守 meta 12(真元数据)。
    final verbStyle = AnText.label.copyWith(color: c.inkMuted);
    final verbFaint = AnText.label.copyWith(color: c.inkFaint);
    final faint = AnText.meta.copyWith(color: c.inkFaint);

    // Terminal overrides stay with the chassis; live/settled verbs come from the family spec.
    // 终态动词归底盘;进行/过去时动词出自族规格。
    // Awaiting + terminal verbs default to the chassis, but a family may override them (ask_user:
    // 等待你回答 + 已回答/已跳过/空答案 by result). 等待/终态动词默认归底盘,族可覆盖(ask_user)。
    final verb = switch (state.phase) {
      ToolCardPhase.awaitingConfirm => spec.awaitingVerb?.call(t) ?? t.chat.tool.awaitingConfirm,
      ToolCardPhase.denied => spec.terminalVerb?.call(t, state) ?? t.chat.tool.denied,
      ToolCardPhase.cancelled => spec.terminalVerb?.call(t, state) ?? t.chat.tool.cancelled,
      _ => spec.terminalVerb?.call(t, state) ?? spec.verbOf?.call(t, state, live: live) ?? spec.verb(t, live: live),
    };
    final target = spec.target?.call(state) ?? '';

    // The dimmed receipt tail: elapsed seconds while live-and-slow; the family receipt (the
    // past tense's proof — line/match counts, exit codes) when settled; the generic failure
    // marker only when the family gave no danger-toned receipt of its own.
    // 灰回执尾:live 且慢时读秒;终态给族回执(过去时的凭据);族未给危险色回执时才补通用失败标记。
    final receipt = <InlineSpan>[];
    if (live && _liveSeconds >= _elapsedRevealAfter.inSeconds) {
      receipt.add(
          TextSpan(text: ' · ${t.chat.tool.elapsed(s: _liveSeconds)}', style: faint));
    }
    if (familyReceipt != null) {
      // Tone → colour: none inkFaint / warn amber / danger red (the three receipt voices).
      // 声调→色:none 灰 / warn 琥珀 / danger 红。
      final toneColor = switch (familyReceipt.tone) {
        ToolReceiptTone.danger => c.danger,
        ToolReceiptTone.warn => c.warn,
        ToolReceiptTone.none => c.inkFaint,
      };
      receipt.add(TextSpan(text: ' · ${familyReceipt.text}', style: AnText.meta.copyWith(color: toneColor)));
    }
    if (state.phase == ToolCardPhase.failed && familyReceipt?.tone != ToolReceiptTone.danger) {
      receipt.add(TextSpan(
          text: ' · ${t.chat.tool.failed}', style: AnText.meta.copyWith(color: c.danger)));
    }

    final dimVerb = state.phase == ToolCardPhase.denied || state.phase == ToolCardPhase.cancelled;
    return AnInteractive(
      onTap: hasBody ? () => setState(() => _userExpanded = !(_userExpanded ?? false)) : null,
      expanded: hasBody ? open : null,
      builder: (context, _) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AnSize.row),
        child: Row(
          children: [
            Icon(AnIcons.toolIcon(state.toolName), size: AnSize.icon,
                color: state.phase == ToolCardPhase.awaitingConfirm ? c.warn : c.inkFaint),
            const SizedBox(width: AnSpace.s6),
            live
                ? AnShimmerText('$verb…', style: verbStyle)
                : Text(verb,
                    style: dimVerb ? verbFaint : verbStyle),
            if (target.isNotEmpty) ...[
              const SizedBox(width: AnSpace.s6),
              Flexible(
                child: Text(target,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.mono.copyWith(color: dimVerb ? c.inkFaint : c.inkMuted)),
              ),
            ],
            // The dimmed receipt tail yields (clips) before overflowing a narrow row — metadata must
            // never push the row past its cell (a long verb + long receipt would otherwise overflow).
            // 灰回执尾在窄行里先让(裁切)、绝不把行撑破:长动词+长回执本会溢出。
            if (receipt.isNotEmpty)
              Flexible(child: Text.rich(TextSpan(children: receipt), maxLines: 1, overflow: TextOverflow.clip)),
            if (hasBody) ...[
              const SizedBox(width: AnSpace.s6),
              AnimatedRotation(
                duration: reduced ? Duration.zero : AnMotion.fast,
                turns: open ? 0.25 : 0,
                child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chassis-level error section appended under FAMILY bodies on failure.
/// 底盘级错误段,失败时追加在族体之下。
Widget _errorSection(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t.chat.tool.errorLabel, style: AnText.meta.copyWith(color: c.danger)),
      const SizedBox(height: AnSpace.s4),
      Text(state.errorText.isEmpty ? state.resultText : state.errorText,
          style: AnText.code.copyWith(color: c.danger)),
    ],
  );
}

/// The generic expanded body — labeled flat sections (the demo's one honest idea, rebuilt to
/// our register): intent · args · progress tail · result · error. Every section is optional;
/// oversized content is excerpted with an explicit truncation note.
///
/// 通用展开体——带标签的扁平段:意图 · 参数 · 进度尾巴 · 结果 · 错误。段段可缺;超限内容节选
/// 并给显式截断注记。
class _GenericToolBody extends StatelessWidget {
  const _GenericToolBody({required this.state});

  final ToolCardState state;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final sections = <Widget>[
      if (state.summary.isNotEmpty)
        _section(context, t.chat.tool.intent,
            Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
      if (state.argsText.isNotEmpty)
        _section(context, t.chat.tool.argsLabel, _jsonOrMono(context, state.argsText)),
      if (state.progressText.isNotEmpty)
        _section(context, t.chat.tool.progressLabel, _progress(context), live: state.progressLive),
      if (state.errorText.isNotEmpty || state.phase == ToolCardPhase.failed)
        _section(
            context,
            t.chat.tool.errorLabel,
            Text(state.errorText.isEmpty ? state.resultText : state.errorText,
                style: AnText.code.copyWith(color: c.danger)),
            danger: true)
      else if (state.resultText.isNotEmpty)
        _section(context, t.chat.tool.resultLabel, _jsonOrMono(context, state.resultText)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AnSpace.s8),
          sections[i],
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String label, Widget body,
      {bool live = false, bool danger = false}) {
    final t = Translations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: AnText.meta.copyWith(color: danger ? c.danger : c.inkFaint)),
          if (live) ...[
            const SizedBox(width: AnSpace.s6),
            const AnStatusDot(AnStatus.run),
            const SizedBox(width: AnSpace.s4),
            Text(t.chat.tool.liveLabel, style: AnText.meta.copyWith(color: c.inkFaint)),
          ],
        ]),
        const SizedBox(height: AnSpace.s4),
        body,
      ],
    );
  }

  /// Parseable JSON: SMALL → pretty mono text (airy, no chrome); BIG → the virtualized
  /// [AnJsonTree] inside its REQUIRED bounded viewport (TreeSliver cannot shrink-wrap — and a
  /// transcript row must never own an unbounded wall anyway). Anything else → capped mono.
  /// 可解析 JSON:**小**→美化等宽文本(轻盈无壳);**大**→虚拟化 AnJsonTree 于其**必需**的有界
  /// 视口(TreeSliver 不能 shrink-wrap——transcript 行本也不该背无界墙)。其余→封顶等宽。
  Widget _jsonOrMono(BuildContext context, String raw) {
    final t = Translations.of(context);
    final c = context.colors;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {}
    if (decoded is Map || decoded is List) {
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      final lines = '\n'.allMatches(pretty).length + 1;
      if (lines <= _jsonInlineMaxLines) {
        return Text(pretty, style: AnText.code.copyWith(color: c.inkMuted));
      }
      return SizedBox(
          height: AnSize.jsonViewport, child: AnJsonTree(data: decoded, showRoot: false));
    }
    final truncated = raw.length > _capChars;
    final shown = truncated ? raw.substring(0, _capChars) : raw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shown, style: AnText.code.copyWith(color: c.inkMuted)),
        if (truncated)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(t.chat.tool.truncatedNote(chars: raw.length),
                style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
    );
  }

  /// The progress tail: last N lines on a sunken panel (the full flow-window lands with the
  /// shell family, V3b). 进度尾巴:凹面板上尾 N 行(完整流窗随 shell 族 V3b)。
  Widget _progress(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final lines = state.progressText.trimRight().split('\n');
    final omitted = lines.length - _progressTailLines;
    final tail = omitted > 0 ? lines.sublist(omitted) : lines;
    return AnWindow(
      header: omitted > 0
          ? Text(t.chat.tool.progressOmitted(n: omitted),
              style: AnText.meta.copyWith(color: c.inkFaint))
          : null,
      child: Text(tail.join('\n'), style: AnText.code.copyWith(color: c.inkMuted)),
    );
  }
}
