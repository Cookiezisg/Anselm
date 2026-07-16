import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_a11y.dart';
import 'an_action_group.dart';
import '../model/status_state.dart';
import 'an_button.dart';
import 'icons.dart';
import 'tone.dart';

/// C1 — a full-width tonal alert bar: a severity icon + message (+ optional title) + 0–2 actions +
/// optional dismiss. Severity maps to an [AnTone] colour (the kit's tone→colour single source):
/// info→accent (AnTone has no `info`; #0071e3 is the universal informational blue), ok/warn/danger
/// map直. Composes on AnToneColors / AnButton / AnIcons — ZERO new tokens, no package (MaterialBanner
/// is a ScaffoldMessenger overlay, wrong for an inline bar).
///
/// a11y: the bar announces itself through [AnA11y.announce] on mount + on in-place severity/message
/// change — ONE mechanism for all four severities, differing only in urgency (warn/danger interrupt,
/// info/ok wait for a gap). Severity is carried by icon + the spoken severity WORD (via `semanticsLabel`)
/// + text — never colour alone (WCAG 1.4.1). Stateful only for that announce lifecycle (no animation —
/// static is the on-brand presentation).
///
/// C1——通栏语气提示条:语气图标 + 文案(+可选标题)+ 0–2 动作 + 可选关闭。severity→AnTone 色(tone→色单源):
/// info→accent(AnTone 无 info;#0071e3 是通用信息蓝),ok/warn/danger 直映。搭 AnToneColors/AnButton/AnIcons,
/// 零新 token、无包。a11y:挂载 + 原地变时经 AnA11y.announce 播报——**四档一套机制**,只差紧急度(warn/danger
/// 打断,info/ok 等空档)。语气靠 图标 + 朗读的语气词(semanticsLabel)+ 文字,绝不只靠色。
enum AnCalloutSeverity { info, ok, warn, danger }

class AnCallout extends StatefulWidget {
  const AnCallout(
    this.message, {
    this.severity = AnCalloutSeverity.info,
    this.title,
    this.actions = const [],
    this.onDismiss,
    super.key,
  });

  /// Plain-text body. 正文(纯文本)。
  final String message;

  /// Optional emphasis line above the message. 可选标题行。
  final String? title;

  final AnCalloutSeverity severity;

  /// Inline action buttons (caller passes `AnButton(size: sm)`); rendered BELOW the message so a long
  /// message never has to truncate to fit them. Cap at 2 by convention. 动作钮(放文案下方,不挤正文)。
  final List<Widget> actions;

  /// null = persistent (the default for blocking errors). Non-null adds a trailing close. 非空才可关。
  final VoidCallback? onDismiss;

  AnTone get _tone => switch (severity) {
        AnCalloutSeverity.info => AnTone.accent,
        AnCalloutSeverity.ok => AnTone.ok,
        AnCalloutSeverity.warn => AnTone.warn,
        AnCalloutSeverity.danger => AnTone.danger,
      };

  IconData get _icon => switch (severity) {
        AnCalloutSeverity.info => AnIcons.info,
        AnCalloutSeverity.ok => AnIcons.success,
        AnCalloutSeverity.warn => AnIcons.warning,
        AnCalloutSeverity.danger => AnIcons.danger,
      };

  // warn/danger interrupt (ARIA `role="alert"`); info/ok wait for a gap (`role="status"`). 急→assertive。
  Assertiveness get _assertiveness =>
      severity == AnCalloutSeverity.warn || severity == AnCalloutSeverity.danger
          ? Assertiveness.assertive
          : Assertiveness.polite;

  @override
  State<AnCallout> createState() => _AnCalloutState();
}

class _AnCalloutState extends State<AnCallout> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(AnCallout old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message || old.severity != widget.severity) _announce();
  }

  String _word(Translations t) => switch (widget.severity) {
        AnCalloutSeverity.info => t.feedback.info,
        AnCalloutSeverity.ok => t.feedback.success,
        AnCalloutSeverity.warn => t.feedback.warning,
        AnCalloutSeverity.danger => t.feedback.error,
      };

  // A bar appears with news nobody asked for and takes no focus — nothing on any desktop reads it on
  // its own, so ALL FOUR severities must be pushed (this used to fire only for warn/danger and leave
  // info/ok to `liveRegion`, i.e. to silence: that flag is a verified desktop no-op — see [AnA11y]).
  // Deferred to post-frame so Directionality/Translations are mounted.
  // 提示条自己冒出来、且不夺焦 → 三桌面都不会主动念它,故**四档 severity 全推**(旧码只推 warn/danger,把 info/ok
  // 交给 liveRegion = 交给沉默:那面旗标在桌面实证 no-op,见 AnA11y)。推迟到 post-frame 等 Directionality 挂载。
  void _announce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AnA11y.announce(context, '${_word(context.t)}: ${widget.message}',
          assertiveness: widget._assertiveness);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    final tone = widget._tone;
    final fg = tone.fg(c);
    final word = _word(t);

    final hasTitle = widget.title != null;
    // The severity WORD is spoken (semanticsLabel) but not shown — sighted users get it from the icon.
    // 语气词朗读但不显示——视力用户看图标。
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTitle)
          Text(widget.title!,
              style: AnText.strong.copyWith(color: c.ink), semanticsLabel: '$word: ${widget.title!}'),
        Text(widget.message,
            style: AnText.body.copyWith(color: c.ink),
            semanticsLabel: hasTitle ? null : '$word: ${widget.message}'),
        if (widget.actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnGap.block), // content → actions (12, unified with cards) 内容→动作
            // AnActionGroup — D7's ONE action-row idiom (8px control gap, same as AnInfoCard); the
            // hand-rolled 6px Wrap was the lone divergence. 动作行统一走 AnActionGroup(8px,同卡)。
            child: AnActionGroup(widget.actions),
          ),
      ],
    );

    return Semantics(
      container: true,
      child: Container(
        padding: AnInset.snug, // callout interior (12/8) 提示框内距
        decoration: BoxDecoration(color: tone.softBg(c), borderRadius: BorderRadius.circular(AnRadius.chip)),
        // start-align so the icon hugs the FIRST line when the message wraps. start 对齐:多行时图标贴首行。
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(widget._icon, size: AnSize.icon, color: fg)),
            const SizedBox(width: AnSpace.s8),
            Expanded(child: text),
            if (widget.onDismiss != null) ...[
              const SizedBox(width: AnSpace.s8),
              AnButton.iconOnly(AnIcons.close, size: AnButtonSize.sm, semanticLabel: t.feedback.dismiss, onPressed: widget.onDismiss),
            ],
          ],
        ),
      ),
    );
  }
}
