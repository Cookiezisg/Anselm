import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_menu.dart';
import 'icons.dart';

/// The right-island IDENTITY HEAD (三段式文法 §1, 用户 0719) — one shape behind every right island: a leading
/// kind/pulse [icon] + a [title], then AT MOST TWO trailing buttons — a single ⋯ overflow [menuEntries] that
/// collects EVERY panel-scoped action (so a head never grows a loose row of buttons again — the retired
/// «四钮杂») and a first-class [onClose] ✕. An optional [sub] band (the quiet glance strip) rides one line
/// below at the head inset — pass null when there is no signal (零人话律, the caller decides). Draws NO
/// divider — content follows directly.
///
/// Geometry OBEYS the right-island inner-padding SINGLE SOURCE (same law as [AnInspectorHead]): the wrapping
/// [AnIsland]'s 12px IS the sole island inset on BOTH edges, so the head adds ZERO horizontal pad — its
/// icon/title land on the leading island pad edge (the accordion rows below then indent their own s8, so the
/// head super-heads them by one tier), and the trailing ✕/⋯ button box sits flush at the trailing island pad
/// edge — 1:1 the left island's chrome-bar collapse button, its glyph landing ~on the row-family iron line.
///
/// 右岛身份头(三段式文法 §1):前导 icon + 标题,尾端至多两钮——单个 ⋯ 溢出菜单收编一切面板级动作(头再不长一排
/// 散钮=退役的「四钮杂」)+ 一等公民 ✕;可选 [sub] 速览带在头下一行同缩进(无信号传 null,零人话律由调用方定)。
/// 不画分隔线。几何守右岛内距单源律(同 [AnInspectorHead]):岛壳 12 双缘唯一,头水平前后皆 0——icon/标题落前导
/// pad 缘、尾 ✕/⋯ 钮盒齐平尾 pad 缘(1:1 左岛 chrome bar 收起钮,字形落行族右缘铁线附近),下方行族各自缩 s8。
class AnPanelHead extends StatelessWidget {
  const AnPanelHead({
    required this.icon,
    required this.title,
    this.menuEntries = const <AnMenuEntry>[],
    this.menuSemanticLabel,
    this.sub,
    this.onClose,
    this.closeSemantics,
    super.key,
  });

  /// The panel's identity glyph (16, inkFaint) — the fix for a head that read as「小灰标题无 icon」. 身份字形。
  final IconData icon;

  /// The panel title (meta · emphasis weight · inkFaint · ellipsis). 面板标题。
  final String title;

  /// The ⋯ overflow menu — EVERY panel-scoped action collapses here. Empty → no ⋯ button (only ✕, or nothing).
  /// ⋯ 溢出菜单:面板级动作全收于此;空 → 无 ⋯ 钮。
  final List<AnMenuEntry> menuEntries;

  /// The ⋯ button's semantic label — the caller passes the localized string. ⋯ 钮语义标签(调用方传本地化)。
  final String? menuSemanticLabel;

  /// A quiet band one line below the head row (the glance strip). Null = no band (零人话律). 速览带,null=无带。
  final Widget? sub;

  /// Collapses the right island — a first-class ✕ (md) after the ⋯ when non-null. 收岛 ✕。
  final VoidCallback? onClose;

  /// The ✕ button's semantic label — the caller passes the localized string. ✕ 语义标签(调用方传本地化)。
  final String? closeSemantics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final close = onClose;
    final band = sub;
    return Padding(
      // Head adds ZERO horizontal pad — the island's 12px is the SOLE island inset (single-source law), on
      // BOTH edges. So the trailing ✕/⋯ button BOX sits flush at the island content edge, its md glyph 6px
      // inboard — 1:1 the LEFT island's chrome-bar collapse button (box at island edge, glyph 18 from the
      // outer edge), and the glyph lands ~on the row-family iron line (meta at island + 12 + 8). The retired
      // trailing s8 double-inset the button (island 12 + head 8 = box 20, glyph 26 from the outer edge — the
      // ✕ read 8px further inboard than the left island's, the「离右缘空太多」bug). 头水平前后都 0(岛 12 唯一,
      // 双缘同律):尾 ✕/⋯ 钮盒齐平岛内容缘、md 字形 6px 内缩——1:1 左岛 chrome bar 收起钮;退役的尾 s8 双缩
      // (岛 12+头 8=盒 20/字形 26,比左岛多缩 8px=「离右缘空太多」bug)。仅纵向 s8(不受水平单源律辖)。
      padding: const EdgeInsets.fromLTRB(0, AnSpace.s12, 0, AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: AnSize.icon, color: c.inkFaint),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint),
                  ),
                ),
              ),
              if (menuEntries.isNotEmpty)
                AnMenu(
                  entries: menuEntries,
                  anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
                    AnIcons.more,
                    semanticLabel: menuSemanticLabel ?? '',
                    onPressed: toggle,
                  ),
                ),
              if (close != null)
                AnButton.iconOnly(
                  AnIcons.close,
                  semanticLabel: closeSemantics ?? '',
                  onPressed: close,
                ),
            ],
          ),
          if (band != null) ...[
            const SizedBox(height: AnSpace.s6),
            band,
          ],
        ],
      ),
    );
  }
}
