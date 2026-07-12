import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_interactive.dart';

/// Swatch sizes. dot = identity marker beside a name; pick = a colour-picker cell. 两档。
enum AnSwatchSize { dot, pick }

/// A COLOUR SWATCH (WRK-066 批5c, A-028) — the «colour IS the content» primitive: an identity dot
/// beside a workspace name, or a picker cell with a selection ring. Distinct from [AnStatusDot]
/// (semantic STATUS colour) — a swatch carries user-chosen identity colour. Tappable cells wrap
/// [AnInteractive] and speak `selected` semantics; the ring, not a hover tint, is the selection
/// signal (an opaque colour disc can't show a tint).
///
/// 色板件(批5c)——「色即内容」原语:名旁身份点 / 带选中环的取色格。与 AnStatusDot(语义状态色)
/// 两类,不并件。可点格包 AnInteractive 并播 selected 语义;选中信号=环(不透明色盘透不出 hover 墨)。
class AnSwatch extends StatelessWidget {
  const AnSwatch(this.color, {this.size = AnSwatchSize.pick, this.selected = false, this.onTap, super.key});

  final Color color;
  final AnSwatchSize size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = size == AnSwatchSize.dot ? AnSize.swatch : AnSize.badge;
    final disc = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Selection ring at the emphasis-ring tier (the hand-rolled 2px snaps to ring 1.5 — 档位归一,记档). 选中环走强调环档。
        border: selected ? Border.all(color: c.ink, width: AnSize.ring) : null,
      ),
    );
    if (onTap == null) return disc;
    // ONE actionable node: MergeSemantics folds the selected flag with AnInteractive's button
    // (a bare wrapper forks a dead flag node beside the real button — AnChip 同修). 并单节点。
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: AnInteractive(onTap: onTap, builder: (ctx, states) => disc),
      ),
    );
  }
}

/// The preset avatar palette — free-text hex on the wire, a fixed tasteful set in the UI (moved
/// from the workspaces panel; feature layers don't mint colour tables, 文法 #6). 预设色盘(线上自由
/// hex,UI 给定集;色表归 core,feature 不私铸)。
const kAvatarPalette = [
  '#5B8DEF', '#4CAF7D', '#E2A93B', '#D96C6C', '#9B7EDE', '#5FB3C9',
];

/// Hex → Color with a fallback (bad/absent strings never crash a row). 坏值回退。
Color parseHexColor(String? hex, Color fallback) {
  final h = (hex ?? '').replaceFirst('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}
