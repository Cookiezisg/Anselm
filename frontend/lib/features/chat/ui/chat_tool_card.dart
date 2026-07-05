import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_catalog.dart';
import 'tool_card_skins.dart';

/// The V3a tool-call CHASSIS (WRK-053) — one borderless 32px-register line per tool call
/// (decision #2: bare row, the expanded body owns the only container), carrying the whole
/// lifecycle: args-streaming / awaiting-confirm / running (shimmer verb + quiet elapsed
/// counter after 3s) / succeeded / failed (auto-expands once) / denied / cancelled. The verb
/// comes from the registry ([toolCardStrings], decision #1); the body is the GENERIC skin —
/// intent (LLM summary) · args JSON · progress tail · result (JSON tree when parseable) ·
/// error — with hard display caps + an honest truncation note. Family skins (V3b+) replace
/// the body per family; the line grammar and state plumbing stay here.
///
/// V3a 工具卡**底盘**(WRK-053)——每次调用一条无边框 32px 档的裸行(拍板 #2:行裸、容器只属于
/// 展开体),承载完整生命周期:args 流入 / 等待确认 / 执行中(动词流光 + 3s 后安静计时)/ 成功 /
/// 失败(自动展开一次)/ 已拒绝 / 已中断。动词出自注册表(拍板 #1);体=**通用皮肤**——意图
/// (LLM summary)· 参数 JSON · 进度尾巴 · 结果(可解析即 JSON 树)· 错误——硬显示上限 + 诚实
/// 截断注记。族皮肤(V3b+)按族替换体;行文法与状态管道恒在此。
class ChatToolCard extends StatefulWidget {
  const ChatToolCard({required this.node, this.awaitingConfirm = false, super.key});

  /// The tool_call [BlockNode] (children carry nested progress / tool_result). 工具调用节点。
  final BlockNode node;

  /// Interaction-signal overlay: pending danger/ask gate (wired at V6). 人在环覆盖(V6 接线)。
  final bool awaitingConfirm;

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
    final phase = ToolCardState.of(widget.node, awaitingConfirm: widget.awaitingConfirm).phase;
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
    _syncTicker();
  }

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
    final state = ToolCardState.of(widget.node, awaitingConfirm: widget.awaitingConfirm);
    final spec = toolCardSpecFor(state.toolName);
    final live = state.phase == ToolCardPhase.argsStreaming || state.phase == ToolCardPhase.running;
    if (!live && _ticker != null) _syncTicker();

    // Failure auto-expands ONCE (industry consensus) — including a DANGER-TONED family
    // receipt (Bash exit≠0 / timeout close with status=completed on the wire, but the user
    // wants to see why). The user's explicit toggle wins after.
    // 失败自动展开一次(业界共识)——含**危险色族回执**(Bash 非零 exit/超时在线缆上是 completed,
    // 但用户要看原因);之后用户手动开关优先。
    final hasBody = !spec.bodyless && state.hasBody;
    ToolReceipt? familyReceipt;
    if (state.phase == ToolCardPhase.succeeded || state.phase == ToolCardPhase.failed) {
      familyReceipt = spec.receipt?.call(t, state);
    }
    final failedLook = state.phase == ToolCardPhase.failed || familyReceipt?.tone == ToolReceiptTone.danger;
    if (failedLook && hasBody && !_autoExpandedOnce) {
      _autoExpandedOnce = true;
      _userExpanded ??= true;
    }
    final open = (_userExpanded ?? false) && hasBody;
    // The live machine window (F3 terminal tail / F4 builds content streaming in): visible
    // while in flight, dissolves into the expanded body on completion.
    // 活机器窗(F3 终端尾/F4 builds 内容流入):在飞可见,完成溶进展开体。
    final showLiveBody = spec.liveBody != null && live && !open;

    const bodyInset = EdgeInsets.only(top: AnSpace.s4, left: AnSize.icon + AnSpace.s6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(context, t, c, state, spec, live, open, hasBody, familyReceipt),
        AnExpandReveal(
          open: showLiveBody,
          child: Padding(
            padding: bodyInset,
            child: SizedBox(
                width: double.infinity,
                child: showLiveBody
                    ? spec.liveBody!(context, state)
                    : const SizedBox.shrink()),
          ),
        ),
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
                  spec.body?.call(context, state) ?? _GenericToolBody(state: state),
                  // Family bodies get the error section from the CHASSIS — every family shows
                  // failures without re-implementing them (the generic body has its own).
                  // 族体的错误段由**底盘**追加——各族免费显示失败(通用体自带)。
                  if (spec.body != null &&
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
    final verb = switch (state.phase) {
      ToolCardPhase.awaitingConfirm => t.chat.tool.awaitingConfirm,
      ToolCardPhase.denied => t.chat.tool.denied,
      ToolCardPhase.cancelled => t.chat.tool.cancelled,
      _ => spec.verb(t, live: live),
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
            if (receipt.isNotEmpty)
              Text.rich(TextSpan(children: receipt), maxLines: 1, overflow: TextOverflow.clip),
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
    return ToolWindow(
      header: omitted > 0
          ? Text(t.chat.tool.progressOmitted(n: omitted),
              style: AnText.meta.copyWith(color: c.inkFaint))
          : null,
      child: Text(tail.join('\n'), style: AnText.code.copyWith(color: c.inkMuted)),
    );
  }
}
