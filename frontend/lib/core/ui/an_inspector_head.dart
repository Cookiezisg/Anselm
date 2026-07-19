import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'icons.dart';

/// The right-island content HEAD band (unified across every right island) — a small quiet [label] saying
/// what the panel IS (the left-island group-head vocabulary: meta size · emphasis weight · inkFaint),
/// an optional leading kind glyph, an [actions] slot for panel-scoped quick controls, and a first-class
/// [onClose] ✕ (md, 16px glyph) that collapses the island. An optional meta sub-row (leading label +
/// end-aligned trailing value). Draws NO divider — content follows directly. This is the Claude-style
/// header: label · actions · ✕, then the body — one shape behind every island so they read identically.
///
/// 右岛统一头带——小字安静 [label](左岛组头语汇:meta 字号 · emphasis 字重 · inkFaint)说明「这面板是干啥的」;
/// 可选前导 kind 图标、[actions] 面板级快捷动作槽、一等公民 [onClose] ✕(md/16px)收岛;可选 meta 次行。
/// **不画分隔线**,内容直接跟随。Claude 式头:label · 动作 · ✕,后接 body——每个岛同一形,读来一致。
class AnInspectorHead extends StatelessWidget {
  const AnInspectorHead({
    required this.label,
    this.icon,
    this.subLeading,
    this.subTrailing,
    this.subTrailingWidget,
    this.actions = const <Widget>[],
    this.onClose,
    this.closeSemantics,
    super.key,
  });

  /// The quiet panel label — what this island IS (meta · emphasis weight · inkFaint · ellipsis). 面板小字标签。
  final String label;

  /// Optional leading kind/scope glyph (16, inkFaint). 可选前导 kind 图标。
  final IconData? icon;

  /// Optional meta sub-row leading label (inkMuted) — e.g. the kind word. 次行前置标签(灰)。
  final String? subLeading;

  /// Optional meta sub-row trailing value (inkFaint, end-aligned, ellipsis) — e.g. the resolved ref.
  /// 次行右对齐值(浅灰省略),如已解析 ref。
  final String? subTrailing;

  /// Optional widget after the sub-row trailing value (e.g. a phase status chip) — the run terminal's
  /// live-status badge (A-010). 次行值之后的可选件(如相位状态徽),run 终端活状态徽。
  final Widget? subTrailingWidget;

  /// Panel-scoped quick actions on the head row, spread before the ✕ (e.g. a follow toggle / expand-all).
  /// 头行快捷动作,置于 ✕ 之前(如自动展示 / 展开全部)。
  final List<Widget> actions;

  /// Collapses the right island — renders a first-class ✕ (md) after [actions] when non-null. 收岛 ✕。
  final VoidCallback? onClose;

  /// The ✕ button's semantic label — the caller passes the localized string. ✕ 语义标签(调用方传本地化串)。
  final String? closeSemantics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ic = icon;
    final close = onClose;
    final sl = subLeading;
    final stt = subTrailing;
    final leading = (sl != null && sl.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(right: AnSpace.s8),
            child: Text(sl, style: AnText.meta.copyWith(color: c.inkMuted)),
          )
        : null;
    final hasSub = leading != null || (stt != null && stt.isNotEmpty) || subTrailingWidget != null;
    return Padding(
      // Right-island inner-padding SINGLE SOURCE: the wrapping [AnIsland]'s 12px IS the island inset on BOTH
      // edges, so the head adds ZERO horizontal pad — its label/glyph land on the leading island pad edge
      // (flush with the body content box below; row-family text then indents its own s8), and the trailing
      // ✕/actions button box sits flush at the trailing pad edge — 1:1 the left island's chrome-bar button,
      // its glyph landing ~on the row-family iron line. The retired trailing s8 double-inset the ✕ (island 12
      // + head 8 = box 20, glyph 26 from the outer edge — 8px further inboard than the left island's).
      // 右岛内距单源:岛壳 12 双缘唯一,头水平前后皆 0——标签/字形落前导 pad 缘、尾 ✕/动作钮盒齐平尾 pad 缘
      // (1:1 左岛 chrome bar,字形落行族右缘铁线附近);退役的尾 s8 双缩 ✕(岛 12+头 8=盒 20/字形 26,比左岛多缩 8px)。
      padding: const EdgeInsets.fromLTRB(0, AnSpace.s12, 0, AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (ic != null) ...[
                Icon(ic, size: AnSize.icon, color: c.inkFaint),
                const SizedBox(width: AnSpace.s8),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint),
                  ),
                ),
              ),
              ...actions,
              if (close != null)
                AnButton.iconOnly(
                  AnIcons.close,
                  semanticLabel: closeSemantics ?? '',
                  onPressed: close,
                ),
            ],
          ),
          if (hasSub) ...[
            const SizedBox(height: AnSpace.s6),
            Row(
              children: [
                ?leading,
                Expanded(
                  child: Text(
                    stt ?? '',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                ),
                if (subTrailingWidget != null) ...[
                  const SizedBox(width: AnSpace.s8),
                  subTrailingWidget!,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
