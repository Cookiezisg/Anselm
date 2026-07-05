import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';

/// The variant of a human gate. `danger` = a dangerous tool call awaiting approval; `ask` = ask_user
/// awaiting an answer. Shared shell (island + prompt + action row), different body + button vocabulary.
/// 人闸变体:danger 危险调用待批 / ask 提问待答。共用壳(白岛+prompt+钮排),体与钮词不同。
enum GateKind { danger, ask }

/// Arg keys whose value is a PAYLOAD (the thing being done) — always shown in a machine window, never a
/// flush-right KV value. 值为 payload 的 arg 键——恒进机器窗、绝不作贴右 KV 值。
const Set<String> _payloadKeys = {
  'command', 'code', 'content', 'body', 'prompt', 'new_string', 'old_string', 'file_text', 'query',
};

/// The HUMAN GATE (WRK-056 F16 §族律2) — the one shape in the whole product for "a machine is asking a
/// human to act". Unlike every other tool surface (which the user READS), this one is ACTED on: it wears
/// a white-island identity (NON-sunken — the machine-window rule holds, machine payloads still sit in a
/// sunken window, but the question + buttons never do) and it never borrows thinking's whisper grammar.
///
/// Two modes off [decided]: **awaiting** (amber wait dot, live buttons, fail-safe order) ↔ **resolved**
/// (frozen: buttons become the decision章, the chosen option pins + others fade — never re-interactive).
/// fail-safe is the visual order: the negative action is LEFT+ghost, the positive is RIGHT+primary; Esc
/// is not a decision (refusal must be explicit). Number keys 1–9 quick-select an option ONLY while THIS
/// gate holds focus (never a global binding — answering the wrong gate = answering for the user).
///
/// 人闸——全产品「机器请求人类动手」的唯一形状。白岛身份(非凹陷;机器 payload 仍住凹陷窗、但问题与钮绝不);
/// 双模式(awaiting 琥珀活态 ↔ resolved 冻结决议章)。fail-safe 视觉序:消极左 ghost / 积极右 primary;数字键
/// 快选仅持焦点门响应。纯 prop、零网络(gallery-first);reduced 下浮现即时。
class ToolInteractionGate extends StatefulWidget {
  const ToolInteractionGate({
    required this.kind,
    required this.prompt,
    this.toolName,
    this.evidence = const {},
    this.options = const [],
    this.allowFreeText = false,
    this.decided,
    this.decidedAnswer,
    this.onResolve,
    this.autofocus = true,
    super.key,
  });

  final GateKind kind;

  /// danger: the LLM's self-reported intent (the primary evidence); ask: the question. Reading 15.
  /// danger=LLM 自报意图(主证词);ask=问题正文。阅读档 15。
  final String prompt;

  /// The gated tool name — the always-allow hint names it. 被门工具名(总是允许提示点名它)。
  final String? toolName;

  /// danger: the cleaned business args (framework keys already stripped). Scalars render as an AnKv;
  /// a long value (command/code/content) drops into its own machine window. danger:干净 args。
  final Map<String, dynamic> evidence;

  /// ask: the offered choices (empty → free-text only). ask:选项(空→纯文本)。
  final List<String> options;

  /// ask: show the free-text answer field (Enter sends / Shift+Enter newlines). ask:显自由文本框。
  final bool allowFreeText;

  /// null = AWAITING (live); non-null = RESOLVED this session (frozen decision章). null=待决,非空=已决冻结。
  final InteractionAction? decided;

  /// resolved ask-accept: the submitted answer (a chosen option's label, or free text). 已答内容。
  final String? decidedAnswer;

  /// The decision sink (POST happens upstream). null in gallery specimens. 决议回调(POST 在上游)。
  final void Function(InteractionAction action, {String? answer})? onResolve;

  /// Grab focus when awaiting (so number keys work immediately) — off in matrix batteries. 待决即抓焦。
  final bool autofocus;

  bool get isAwaiting => decided == null;

  @override
  State<ToolInteractionGate> createState() => _ToolInteractionGateState();
}

class _ToolInteractionGateState extends State<ToolInteractionGate> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'gate-field');
  final FocusNode _keyFocus = FocusNode(debugLabel: 'gate-keys');

  @override
  void dispose() {
    _text.dispose();
    _fieldFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _resolve(InteractionAction action, {String? answer}) =>
      widget.onResolve?.call(action, answer: answer);

  void _selectOption(int i) {
    if (i < 0 || i >= widget.options.length) return;
    _resolve(InteractionAction.accept, answer: widget.options[i]);
  }

  void _submitText() =>
      _resolve(InteractionAction.accept, answer: _text.text.trim());

  // Digit 1–9 selects an option — fires ONLY on the gate shell's focus node, so typing a digit INTO the
  // free-text field (a descendant focus that consumes the key) never triggers a selection (focus
  // arbitration). 数字键选项:仅门壳焦点触发;字段聚焦时数字被字段吞、不误选。
  KeyEventResult _onShellKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.options.isEmpty) return KeyEventResult.ignored;
    final label = event.logicalKey.keyLabel;
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 0x31 && code <= 0x39) {
        // '1'..'9'
        final i = code - 0x31;
        if (i < widget.options.length) {
          _selectOption(i);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final awaiting = widget.isAwaiting;
    final danger = widget.kind == GateKind.danger;

    // Island: white surface, subtle border; awaiting tints the border amber (the wait signal), and a
    // danger gate deepens it toward danger. 白岛:待决琥珀边、危险门偏红边。
    final borderColor = !awaiting
        ? c.line
        : danger
            ? c.danger
            : c.warn;

    return Focus(
      focusNode: _keyFocus,
      // Grab shell focus only when there is NO free-text field to type into — otherwise the field owns
      // focus. 无自由文本框时才抓门壳焦点(有则字段拥焦)。
      autofocus: widget.autofocus && awaiting && !(widget.allowFreeText),
      onKeyEvent: _onShellKey,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AnRadius.card),
          border: Border.all(color: borderColor),
        ),
        padding: AnInset.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, t, c, awaiting, danger),
            const SizedBox(height: AnGap.stack),
            Text(widget.prompt, style: AnText.reading.copyWith(color: c.ink)),
            if (danger && widget.evidence.isNotEmpty) ...[
              const SizedBox(height: AnGap.block),
              _evidence(context, t, c),
            ],
            if (!danger) ...[
              const SizedBox(height: AnGap.block),
              _askBody(context, t, c, awaiting),
            ],
            // Footer: awaiting → the fail-safe button row; frozen danger → the decision章; frozen ask →
            // nothing (the outcome already renders in the ask body). 尾:待决=钮排,冻结 danger=决议章,
            // 冻结 ask=无(结果已在体内)。
            if (awaiting) ...[
              const SizedBox(height: AnGap.block),
              _actions(context, t, c, danger),
            ] else if (danger) ...[
              const SizedBox(height: AnGap.block),
              _decisionChip(context, t, c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Translations t, AnColors c, bool awaiting, bool danger) {
    return Row(
      children: [
        if (danger) ...[
          AnBadge(t.chat.gate.dangerBadge, tone: AnTone.danger),
          const SizedBox(width: AnGap.inline),
        ],
        if (awaiting) ...[
          const AnStatusDot(AnStatus.wait),
          const SizedBox(width: AnGap.inlineHair),
          Text(danger ? t.chat.gate.awaitingDanger : t.chat.gate.awaitingAsk,
              style: AnText.label.copyWith(color: c.warn)),
        ],
      ],
    );
  }

  // ── danger: the args evidence (scalars → AnKv; long values → machine windows) ──
  Widget _evidence(BuildContext context, Translations t, AnColors c) {
    final scalars = <AnKvRow>[];
    final windows = <Widget>[];
    widget.evidence.forEach((k, v) {
      final s = v is String ? v : v.toString();
      // Payload keys (the thing being done — command/code/content…) ALWAYS get a machine window: they
      // read left-to-right and a flush-right KV value would mangle them; so does any long / multi-line
      // value. 短标量走 KV;payload 键(被执行之物)与长/多行值恒进机器窗(左读,贴右会毁)。
      if (_payloadKeys.contains(k) || s.contains('\n') || s.length > 60) {
        windows.add(Padding(
          padding: const EdgeInsets.only(top: AnGap.stackTight),
          child: AnSunkenPanel(
            header: Text(k, style: AnText.label.copyWith(color: c.inkFaint)),
            child: Text(s, style: AnText.code.copyWith(color: c.inkMuted)),
          ),
        ));
      } else {
        scalars.add(AnKvRow(k, s, meta: true));
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scalars.isNotEmpty) AnKv(rows: scalars, dense: true),
        ...windows,
      ],
    );
  }

  // ── ask: options + free text, or the frozen answer ──
  Widget _askBody(BuildContext context, Translations t, AnColors c, bool awaiting) {
    if (!awaiting) return _frozenAnswer(context, t, c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.stackTight),
            child: AnButton(
              label: '${i + 1}. ${widget.options[i]}',
              onPressed: () => _selectOption(i),
              block: true,
            ),
          ),
        if (widget.allowFreeText)
          Padding(
            padding: EdgeInsets.only(top: widget.options.isEmpty ? 0 : AnGap.stackTight),
            child: Focus(
              // Enter (no shift) sends; Shift+Enter falls through to the field as a newline.
              // Enter 发送;Shift+Enter 落到字段换行。
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent &&
                    e.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _submitText();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AnInput(
                controller: _text,
                focusNode: _fieldFocus,
                autofocus: widget.autofocus,
                multiline: true,
                block: true,
                placeholder: t.chat.gate.answerPlaceholder,
                style: AnText.reading,
              ),
            ),
          ),
      ],
    );
  }

  Widget _frozenAnswer(BuildContext context, Translations t, AnColors c) {
    if (widget.decided == InteractionAction.decline) {
      return AnBadge(t.chat.gate.decidedDeclined, tone: AnTone.none);
    }
    final answer = widget.decidedAnswer ?? '';
    final chosen = widget.options.indexOf(answer);
    if (chosen >= 0) {
      // A selected option pins as a章; the others fade (frozen record, never re-interactive). 选中章+余淡出。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AnGap.stackTight),
              child: Opacity(
                opacity: i == chosen ? 1 : AnOpacity.disabled,
                child: Row(
                  children: [
                    Icon(i == chosen ? AnIcons.check : AnIcons.chevronRight,
                        size: AnSize.iconSm, color: i == chosen ? c.ok : c.inkFaint),
                    const SizedBox(width: AnGap.inline),
                    Flexible(
                        child: Text('${i + 1}. ${widget.options[i]}',
                            style: AnText.reading
                                .copyWith(color: i == chosen ? c.ink : c.inkFaint))),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    // Free-text answer → a quotation (blockquote semantics, distinct from thinking's rail). 自由答复=引用。
    return Container(
      padding: const EdgeInsets.only(left: AnSpace.s12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.line, width: AnSize.ring)),
      ),
      child: Text(answer, style: AnText.reading.copyWith(color: c.inkMuted)),
    );
  }

  // ── awaiting: the fail-safe button row (negative LEFT + ghost, positive RIGHT + primary) ──
  Widget _actions(BuildContext context, Translations t, AnColors c, bool danger) {
    if (danger) {
      return Row(
        children: [
          AnButton(
              label: t.chat.gate.deny,
              variant: AnButtonVariant.danger,
              onPressed: () => _resolve(InteractionAction.deny)),
          const SizedBox(width: AnGap.inline),
          Tooltip(
            message: t.chat.gate.approveAlwaysHint(tool: widget.toolName ?? ''),
            child: AnButton(
                label: t.chat.gate.approveAlways,
                onPressed: () => _resolve(InteractionAction.approveAlways)),
          ),
          const Spacer(),
          AnButton(
              label: t.chat.gate.approve,
              variant: AnButtonVariant.primary,
              onPressed: () => _resolve(InteractionAction.approve)),
        ],
      );
    }
    // ask: decline (left ghost) + send (right primary, only with a free-text field — options self-send)
    return Row(
      children: [
        AnButton(label: t.chat.gate.decline, onPressed: () => _resolve(InteractionAction.decline)),
        const Spacer(),
        if (widget.allowFreeText)
          AnButton(
              label: t.chat.gate.submit,
              variant: AnButtonVariant.primary,
              onPressed: _submitText),
      ],
    );
  }

  // The frozen danger decision章 (ask outcomes render in the body, so this is danger-only in practice).
  // 冻结 danger 决议章(ask 结果在体内,此处实际只 danger)。
  Widget _decisionChip(BuildContext context, Translations t, AnColors c) {
    final (label, tone) = switch (widget.decided!) {
      InteractionAction.approve => (t.chat.gate.decidedApproved, AnTone.ok),
      InteractionAction.approveAlways => (t.chat.gate.decidedApprovedAlways, AnTone.accent),
      InteractionAction.deny => (t.chat.gate.decidedDenied, AnTone.danger),
      InteractionAction.accept => (t.chat.gate.decidedApproved, AnTone.ok),
      InteractionAction.decline => (t.chat.gate.decidedDeclined, AnTone.none),
    };
    return Align(alignment: Alignment.centerLeft, child: AnBadge(label, tone: tone));
  }
}
