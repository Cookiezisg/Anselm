import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'an_tooltip.dart';
import 'icons.dart';
import 'tone.dart';

/// The CHIP family head (WRK-066「同轨」族三) — the ONE small-label unit. Two looks:
/// [AnChipLook.filled] (soft tone background, pill — status badges) and [AnChipLook.outlined]
/// (hairline border, pill — light list chips: tool belts, morph rosters, pre-authorized pills; ONE
/// radius family-wide, a 12-radius on a 22-high box collapses to pill anyway). Hot-pluggable:
/// leading [icon], [mono] label, tap-to-copy ([copyValue] — a PERMANENT copy affordance slot: idle
/// shows the copy glyph, the ✓/✗ flash swaps IN PLACE so the chip never changes width), [onTap]
/// navigation (hover inks up), [strikethrough]. Copy failure is honest (✗, never a fake ✓).
///
/// 芯片族当家件(「同轨」族三)——唯一小标签单元。两形:filled(软底 pill=状态徽)/outlined(细边 pill=
/// 轻列表芯片;全族单半径——22 高盒上 12 半径视觉即 pill)。热插拔:icon、mono、点击复制(copyValue=
/// **常驻**复制示能槽:静息即 copy 字形,✓/✗ 原槽替换、宽度绝不跳)、onTap 导航(hover 提墨)、划线。
/// 复制失败诚实渲 ✗,绝不谎报 ✓。
enum AnChipLook { filled, outlined }

/// Standard truncation tiers — kills the 15+ hand-rolled `length > N ? substring…` ternaries.
/// Grapheme-aware (an emoji / surrogate pair never shears into �). 标准截断三档(按字素,emoji 不裂)。
enum AnTrunc {
  id(12),
  word(24),
  line(48);

  const AnTrunc(this.chars);
  final int chars;
}

/// Truncate [text] to a standard tier with an ellipsis. 按档截断。
String truncate(String text, AnTrunc tier) {
  final chars = text.characters;
  return chars.length > tier.chars ? '${chars.take(tier.chars)}…' : text;
}

class AnChip extends StatefulWidget {
  const AnChip(
    this.label, {
    this.tone = AnTone.none,
    this.look = AnChipLook.filled,
    this.icon,
    this.dot,
    this.mono = false,
    this.copyValue,
    this.onTap,
    this.strikethrough = false,
    this.tooltip,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final AnTone tone;
  final AnChipLook look;

  /// Leading glyph. With [copyValue] the copy affordance OWNS the slot (idle copy glyph → ✓/✗
  /// flash); an explicit icon shows at idle instead. 前置字形;copyValue 时示能槽常驻(静息 copy 字形)。
  final IconData? icon;

  /// Mono label face (ids / paths / slugs). 等宽标签(id/路径/slug)。
  final bool mono;

  /// Tap copies this value; ✓/✗ flashes in the permanent glyph slot (width never jumps). Mutually
  /// exclusive with [onTap] (copy wins). 点击复制;✓/✗ 原槽闪、宽度不跳;与 onTap 互斥(copy 优先)。
  final String? copyValue;

  final VoidCallback? onTap;

  /// Deleted-entry face (morph rosters). 删除态(变更花名册)。
  final bool strikethrough;

  /// Leading status dot — a TYPED slot (never a generic widget: a chip must not host arbitrary
  /// subtrees). Absorbs AnChip's dot and the op-ticker two-face marker (批5). 前置状态点强类型槽
  /// (拒任意子树);吸收 AnChip.dot 与 op ticker 双脸记号。
  final AnStatusDot? dot;

  /// Idle tooltip override — a copy chip whose display truncates (path basename, capped value)
  /// shows the FULL text at rest; the ✓/✗ flash wording still wins mid-flash. 静息 tooltip 覆盖
  /// (路径/截断值 hover 显全文);✓/✗ 闪现期仍显复制结果。
  final String? tooltip;

  /// A11y label override (e.g. «function: sync_inventory» on the ref-pill preset). a11y 标签覆盖。
  final String? semanticLabel;

  @override
  State<AnChip> createState() => _AnChipState();
}

class _AnChipState extends State<AnChip> {
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _flash;

  @override
  void dispose() {
    _flash?.cancel();
    super.dispose();
  }

  void _copy() {
    // Honest outcome: success flashes ✓, an error flashes ✗ — never a fake ✓ (the family standard,
    // same shape as AnCodeEditor/AnVersionDiff). 诚实结局:成 ✓ 败 ✗,绝不谎报。
    Clipboard.setData(ClipboardData(text: widget.copyValue!)).then((_) {
      if (!mounted) return;
      setState(() {
        _copied = true;
        _copyFailed = false;
      });
      _resetFlash();
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _copyFailed = true;
        _copied = false;
      });
      _resetFlash();
    });
  }

  void _resetFlash() {
    _flash?.cancel(); // rapid re-taps must not let an old timer clear the new flash 连点不早清
    _flash = Timer(AnMotion.dwell, () {
      if (mounted) {
        setState(() {
          _copied = false;
          _copyFailed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final copyable = widget.copyValue != null;
    final interactive = copyable || widget.onTap != null;

    Widget chipOf(bool hovered) {
      // Hover feedback for nav/copy chips: neutral ink lifts to full ink (outlined border follows).
      // 导航/复制芯片 hover:中性墨提到全墨(细边随之)。
      final baseInk = widget.tone.fg(c);
      final ink = hovered && widget.tone == AnTone.none ? c.ink : baseInk;

      // The permanent glyph slot: copy affordance (idle glyph → ✓/✗ in place) or the explicit icon.
      // 常驻字形槽:复制示能(静息字形→✓/✗ 原槽换)或显式 icon。
      final IconData? glyph;
      final Color glyphInk;
      if (copyable && _copied) {
        glyph = AnIcons.check;
        glyphInk = c.ok;
      } else if (copyable && _copyFailed) {
        glyph = AnIcons.close;
        glyphInk = c.danger;
      } else if (widget.icon != null) {
        glyph = widget.icon;
        glyphInk = ink;
      } else if (copyable) {
        glyph = AnIcons.copy;
        glyphInk = ink;
      } else {
        glyph = null;
        glyphInk = ink;
      }

      // Filled keeps AnChip's emphasis weight (the status-badge voice it absorbs); outlined stays
      // body-weight (light list chips). filled 承 AnChip 的强调重;outlined 守正文重(轻列表)。
      var style = (widget.mono ? AnText.codeInline : AnText.meta).copyWith(
        color: ink,
        decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      );
      if (widget.look == AnChipLook.filled && !widget.mono) {
        style = style.weight(AnText.emphasisWeight);
      }

      // Hover tint animates (functional micro-feedback, the ref-pill behaviour the family absorbs);
      // reduced motion snaps. hover 渐变(功能性微反馈,承 ref pill);reduced 即时。
      return AnimatedContainer(
        duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.fast,
        height: AnSize.badge,
        padding: const EdgeInsets.symmetric(horizontal: AnSize.badgePadX),
        // ONE radius family-wide: pill (a 12-radius on a 22-high box collapses to ~pill anyway —
        // two radii would be an invisible distinction, 复审 #20). 全族单半径 pill。
        decoration: widget.look == AnChipLook.filled
            ? BoxDecoration(color: widget.tone.softBg(c), borderRadius: BorderRadius.circular(AnRadius.pill))
            // Outlined sits on an OPAQUE surface (hover lifts it) — the island face AnRefPill
            // carried: a transparent chip on the grey user bubble read as a hole. outlined 形不透明
            // 白岛底(hover 提亮)——灰泡上透明芯片读作破洞(承 AnRefPill 岛面)。
            : BoxDecoration(
                color: hovered && interactive ? c.surfaceHover : c.surface,
                border: Border.all(color: widget.tone == AnTone.none ? (hovered ? c.ink : c.line) : ink, width: AnSize.hairline),
                borderRadius: BorderRadius.circular(AnRadius.pill),
              ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.dot != null) ...[
            widget.dot!,
            if (glyph != null || widget.label.isNotEmpty) const SizedBox(width: AnGap.inline),
          ],
          if (glyph != null) ...[
            Icon(glyph, size: AnSize.iconSm, color: glyphInk),
            // No orphan gap on the icon-only face (empty label). 空标签(纯示能形)不留孤儿间隙。
            if (widget.label.isNotEmpty) const SizedBox(width: AnGap.inline),
          ],
          if (widget.label.isNotEmpty)
            Flexible(
              child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
            ),
        ]),
      );
    }

    if (!interactive) {
      Widget still = ConstrainedBox(constraints: const BoxConstraints(maxWidth: AnSize.block), child: chipOf(false));
      if (widget.semanticLabel != null) {
        // A still chip with an a11y override is one labelled node (icon decorative). 静态芯片 a11y 单节点。
        still = Semantics(label: widget.semanticLabel, child: ExcludeSemantics(child: still));
      }
      return widget.tooltip == null ? still : AnTooltip(message: widget.tooltip!, child: still);
    }
    // i18n is only consumed on the interactive path — a STILL chip renders in any host (gallery
    // fixtures, bare tests) without a TranslationProvider. slang 仅交互径消费:静态芯片不问宿主要 provider。
    final t = context.t;
    final tip = copyable
        ? (_copied
            ? t.feedback.copied
            : (_copyFailed ? t.feedback.copyFailed : (widget.tooltip ?? t.action.copy)))
        : widget.tooltip;
    // MergeSemantics folds the outer label with AnInteractive's own button node — ONE actionable
    // node carrying the full label (a bare Semantics wrapper forks a dead labelled node beside the
    // real button, 批5 复审 a11y). MergeSemantics 并单节点:裸 Semantics 会分叉出死标签节点。
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.block),
      child: MergeSemantics(
        child: Semantics(
          label: widget.semanticLabel ?? (copyable ? '${t.action.copy} ${widget.label}' : null),
          child: AnInteractive(
            onTap: copyable ? _copy : widget.onTap,
            builder: (ctx, states) => ExcludeSemantics(child: chipOf(states.isActive)),
          ),
        ),
      ),
    );
    return tip == null ? chip : AnTooltip(message: tip, child: chip);
  }
}
