import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_spinner.dart';
import 'icons.dart';

/// C2 — the full-block placeholder for empty / loading / error: a big muted glyph + title + optional
/// hint + optional action, centered in a capped column. HAND-ROLL (Icon + Text + AnButton compose
/// cleanly; the empty-state packages hardcode non-token geometry + raster art that clashes with the
/// thin-Lucide monochrome). Stays Stateless — the only motion is the [AnStateKind.loading] spinner,
/// which owns its own ticker ([CircularProgressIndicator.adaptive]) and freezes to a static glyph
/// under reduced-motion.
///
/// IMPORTANT: `loading` is for SHORT indeterminate waits (save / auth). For CONTENT loading, prefer
/// [AnSkeleton] (a shaped placeholder reads ~30% faster than a spinner). `error` is MONOCHROME
/// (inkFaint glyph; the severity is carried by the a11y label word, red is reserved for AnCallout).
///
/// One [Semantics] container reads "title. hint" as a single message; the glyph + texts are excluded
/// (the container label covers them), the action keeps its own button semantics. liveRegion announces
/// loading/error (NOT empty — initial content, not a change).
///
/// C2——空/载/错 整块占位:大字形 + 标题 + 可选提示 + 可选动作,居中、限宽列。HAND-ROLL(Icon+Text+AnButton
/// 干净组合)。Stateless,唯一动效是 loading 的自带 ticker spinner、降级下冻成静态字形。loading 只给短等待;
/// 内容加载用 AnSkeleton。error 单色(语气进 a11y label,红留给 AnCallout)。一个 Semantics 读「标题. 提示」,
/// 字形/文字排除、动作留自有语义;liveRegion 播报 loading/error(empty 不播)。
enum AnStateKind { empty, loading, error }

enum AnStateSize { page, inset }

class AnState extends StatelessWidget {
  const AnState({
    required this.kind,
    required this.title,
    this.hint,
    this.detail,
    this.action,
    this.icon,
    this.fatal = false,
    this.size = AnStateSize.page,
    super.key,
  });

  final AnStateKind kind;
  final String title;
  final String? hint;

  /// An optional THIRD line below [hint] — a faint, smaller, 3-line-clamped secondary (e.g. a raw error
  /// message / stack tail on an app-fatal screen). Kept out of the merged a11y label (debug detail, not
  /// the announcement). 可选第三行(hint 下):灰小、3 行截断的次级,如启动失败的原始错误明细;不进 a11y 主播报。
  final String? detail;

  /// Usually an [AnButton] (empty → primary CTA; error → ghost 'Try again'). 动作钮。
  final Widget? action;

  /// Override the default per-kind glyph (empty→inbox, error→triangle; loading uses a spinner). 覆盖默认字形。
  final IconData? icon;

  /// App-level FATAL error (the startup / workspace gates) — tints the glyph [AnColors.danger] for a
  /// louder "the app can't start" read. Default false keeps in-content errors MONOCHROME (decision ①,
  /// red reserved for AnCallout). Only meaningful for [AnStateKind.error]. 应用级致命错(启动门控):字形转 danger;
  /// 默认 false,内容内错误仍单色(红留 Callout)。
  final bool fatal;

  final AnStateSize size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = size == AnStateSize.inset;
    final glyphSize = inset ? AnSize.iconLg : AnSize.stateIcon;

    final Widget leading;
    if (kind == AnStateKind.loading) {
      // The family spinner (批7 B-071) — its a11y gate is orAssistive (a decorative loop, B-054),
      // which also fixes this branch's earlier reduced-only gating. 族转圈;门=orAssistive(装饰循环),
      // 顺带修正此前只门 reduced 的档位。
      leading = AnSpinner(size: glyphSize);
    } else {
      leading = Icon(
        icon ?? (kind == AnStateKind.empty ? AnIcons.empty : AnIcons.error),
        size: glyphSize,
        // monochrome by default (decision ①, red reserved for AnCallout); a [fatal] error tints danger.
        // 默认单色;fatal error 转 danger(app 致命屏)。
        color: (kind == AnStateKind.error && fatal) ? c.danger : c.inkFaint,
      );
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(child: leading),
        const SizedBox(height: AnSpace.s12),
        ExcludeSemantics(
          child: Text(title,
              textAlign: TextAlign.center, style: (inset ? AnText.strong : AnText.h3).copyWith(color: c.ink)),
        ),
        if (hint != null) ...[
          const SizedBox(height: AnSpace.s6),
          ExcludeSemantics(
            child: Text(hint!, textAlign: TextAlign.center, style: AnText.meta.copyWith(color: c.inkMuted)),
          ),
        ],
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s8),
          ExcludeSemantics(
            child: Text(detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: AnSpace.s16),
          action!, // keeps its own button semantics 保留按钮语义
        ],
      ],
    );

    // liveRegion announces a settled loading/error, never the initial empty content. 播报 loading/error。
    return Semantics(
      container: true,
      liveRegion: kind != AnStateKind.empty,
      label: hint == null ? title : '$title. $hint',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AnSize.stateMaxWidth),
          child: Padding(
            padding: EdgeInsets.all(inset ? AnSpace.s16 : AnSpace.s24),
            child: column,
          ),
        ),
      ),
    );
  }
}
