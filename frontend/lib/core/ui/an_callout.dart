import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
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
/// Two a11y mechanisms (they are NOT one — [Semantics.liveRegion] is ALWAYS polite): the bar is a
/// polite live region (right for info/ok), and warn/danger ADDITIONALLY fire an ASSERTIVE
/// [SemanticsService.sendAnnouncement] on mount + on in-place severity/message change. Severity is carried by
/// icon + the spoken severity WORD (via `semanticsLabel`) + text — never colour alone (WCAG 1.4.1).
/// Stateful only for that announce lifecycle (no animation — static is the on-brand presentation).
///
/// C1——通栏语气提示条:语气图标 + 文案(+可选标题)+ 0–2 动作 + 可选关闭。severity→AnTone 色(tone→色单源):
/// info→accent(AnTone 无 info;#0071e3 是通用信息蓝),ok/warn/danger 直映。搭 AnToneColors/AnButton/AnIcons,
/// 零新 token、无包。两套 a11y 机制(liveRegion 永远 polite):整条是 polite live region;warn/danger 另发
/// assertive announce(挂载 + 原地变时)。语气靠 图标 + 朗读的语气词(semanticsLabel)+ 文字,绝不只靠色。
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

  // warn/danger are urgent → assertive announce; info/ok ride the polite live region. 急→assertive。
  bool get _assertive => severity == AnCalloutSeverity.warn || severity == AnCalloutSeverity.danger;

  @override
  State<AnCallout> createState() => _AnCalloutState();
}

class _AnCalloutState extends State<AnCallout> {
  @override
  void initState() {
    super.initState();
    _announceIfAssertive();
  }

  @override
  void didUpdateWidget(AnCallout old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message || old.severity != widget.severity) _announceIfAssertive();
  }

  String _word(Translations t) => switch (widget.severity) {
        AnCalloutSeverity.info => t.feedback.info,
        AnCalloutSeverity.ok => t.feedback.success,
        AnCalloutSeverity.warn => t.feedback.warning,
        AnCalloutSeverity.danger => t.feedback.error,
      };

  // liveRegion is always polite; urgency for warn/danger needs an explicit assertive announce. Defer
  // to post-frame so Directionality/Translations are mounted. liveRegion 永远 polite,紧急须显式 assertive。
  void _announceIfAssertive() {
    if (!widget._assertive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!SemanticsBinding.instance.semanticsEnabled) return; // nothing listening → don't post 无辅助技术不发
      final msg = '${_word(context.t)}: ${widget.message}';
      SemanticsService.sendAnnouncement(View.of(context), msg, Directionality.of(context), assertiveness: Assertiveness.assertive);
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
            child: Wrap(spacing: AnGap.inline, runSpacing: AnGap.inline, children: widget.actions),
          ),
      ],
    );

    return Semantics(
      container: true,
      liveRegion: true,
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
