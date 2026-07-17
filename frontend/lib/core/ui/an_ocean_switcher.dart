import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'text_measure.dart';

/// One ocean in an [AnOceanSwitcher] (icon + label). 海洋切换器的一项(图标+标签)。
class AnOceanItem {
  const AnOceanItem({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
}

/// The left-island ocean switcher — a horizontal icon-rail where the SELECTED ocean expands to show its
/// label. Switching is a matched-geometry slide (the documented best practice, à la SwiftUI's
/// matchedGeometryEffect / Notion's new top nav): a SINGLE neutral highlight pill slides + resizes from
/// the leaving slot to the arriving one, the leaving ocean folds its label shut and the arriving one
/// opens its, and the row reflows to absorb the width change. One forward [AnimationController] +
/// [AnMotion.spring] drives the whole morph (monotonic — no droplet neck). Controlled, like [AnTabs]:
/// [selectedIndex] is the truth, [onSelect] fires on a user pick; it animates whenever [selectedIndex]
/// changes.
///
/// 左岛海洋切换器:横向图标条,选中海洋展开标签。切换 = 匹配几何滑动(业界成熟做法,如 SwiftUI matchedGeometryEffect /
/// Notion 新版顶导航):单个中性高亮药丸从离场槽滑动+变宽到到场槽,离场海洋折回标签、到场海洋展开,整行回流吸收宽度变化。
/// 单前向控制器 + AnMotion.spring 驱动全程(单调,无水珠收颈)。受控(同 AnTabs):selectedIndex 为真相,onSelect 用户点选才派。
class AnOceanSwitcher extends StatefulWidget {
  const AnOceanSwitcher({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final List<AnOceanItem> items;

  /// The selected ocean's index, or **-1 for NONE** — when a footer ocean (settings) or the notifications
  /// tray is active, no top ocean is selected, so all items collapse to icons and the pill fades out.
  /// 选中海洋的索引,或 **-1 = 无选中**(底栏设置海洋 / 通知托盘激活时,顶部无选中 → 全收成图标、药丸淡出)。
  final int selectedIndex;

  /// Fires on a USER pick (not on a programmatic [selectedIndex] change) — matches the kit's other
  /// controlled-selection primitives (AnTabs / AnRow). 用户点选才派(非程序改 selectedIndex)。
  final ValueChanged<int> onSelect;

  @override
  State<AnOceanSwitcher> createState() => _AnOceanSwitcherState();
}

class _AnOceanSwitcherState extends State<AnOceanSwitcher> with SingleTickerProviderStateMixin {
  // EAGER-INIT in initState (kit convention — never a lazy `late final = AnimationController(...)`
  // whose first read can land in teardown with vsync stopped). 控制器急初始化(套件约定)。
  late final AnimationController _ctl;
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.selectedIndex;
    _ctl = AnimationController(vsync: this, duration: AnMotion.mid, value: 1);
  }

  @override
  void didUpdateWidget(AnOceanSwitcher old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _from = old.selectedIndex;
      // reduced-motion: snap to the settled target (forward-only, never .repeat → no stray ticker).
      // 降级:直接落终态、无补间。
      if (AnMotionPref.reduced(context)) {
        _ctl.value = 1;
      } else {
        _ctl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) => AnOceanSwitcherFrame(
          items: widget.items,
          fromIndex: _from,
          toIndex: widget.selectedIndex,
          t: _ctl.value,
          onTap: widget.onSelect,
        ),
      ),
    );
  }
}

/// Pure render of ONE frame of the switch at transition progress [t] (0 = resting on [fromIndex],
/// 1 = resting on [toIndex]). Stateless + tickerless so a capture harness can render any frame
/// deterministically and the gallery can show frozen states. 一帧的纯渲染(无状态无 ticker,可逐帧确定性渲)。
class AnOceanSwitcherFrame extends StatelessWidget {
  const AnOceanSwitcherFrame({
    required this.items,
    required this.fromIndex,
    required this.toIndex,
    required this.t,
    this.onTap,
    super.key,
  });

  final List<AnOceanItem> items;
  final int fromIndex;
  final int toIndex;
  final double t; // 0..1 transition progress 切换进度
  final ValueChanged<int>? onTap;

  // Geometry (all from tokens). 几何(全读令牌)。
  static const double _padX = AnSize.btnPadXSm; // 10 — slot horizontal pad 槽水平内距
  static const double _iconGap = AnGap.inline; // 6 — icon↔label INSIDE a compact control (was row-tier 8) 紧凑控件内 icon↔标签
  static const double _slotGap = AnSpace.s2; // 2 — gap between slots (demo --grid/2) 槽间距
  static const double _rowH = AnSize.row; // 32
  static const double _iconOnlyW = _padX * 2 + AnSize.icon; // 36 — collapsed (icon only) 收起态宽

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = AnText.body.weight(AnText.emphasisWeight);

    double labelWidth(String s) => measureText(
          TextSpan(text: s, style: labelStyle),
          textScaler: textScaler,
          maxLines: 1,
          read: (tp) => tp.width,
        );

    final labelW = [for (final it in items) labelWidth(it.label)];
    double selectedW(int i) => _padX * 2 + AnSize.icon + _iconGap + labelW[i];

    // Matched-geometry slide: one eased progress drives the whole morph — the leaving slot folds shut
    // (1→0), the arriving slot opens (0→1), the row reflows, and a single pill slides + resizes between
    // their resting boxes. Monotonic (no droplet neck). 匹配几何滑动:一条缓动进度驱动全程,旧收起、新展开、整行回流、单药丸滑动变宽。
    final e = AnMotion.spring.transform(t.clamp(0.0, 1.0));

    double selOf(int i) {
      if (i == toIndex && i == fromIndex) return 1; // idle on this slot 静止于此
      if (i == toIndex) return e; // arriving — opens 到场展开
      if (i == fromIndex) return 1 - e; // leaving — folds shut 离场收起
      return 0;
    }

    // Left/width for every slot given a per-slot selectedness (the row reflows). 据每槽选中度布局(整行回流)。
    ({List<double> left, List<double> width, double total}) layoutFor(double Function(int) sel) {
      final widths = [
        for (var i = 0; i < items.length; i++) lerpDouble(_iconOnlyW, selectedW(i), sel(i))!,
      ];
      final lefts = <double>[];
      var x = 0.0;
      for (var i = 0; i < items.length; i++) {
        lefts.add(x);
        x += widths[i] + (i == items.length - 1 ? 0 : _slotGap);
      }
      return (left: lefts, width: widths, total: x);
    }

    final cur = layoutFor(selOf);

    // A pill exists only when EITHER end is a real selection (index -1 = NONE — e.g. while a footer ocean
    // like settings is active, all four collapse to icons with no pill). The pill box = a slot's box in ITS
    // own selected resting layout. -1 = 无选中(如底栏设置海洋激活时,四个全收、无药丸)。
    final fromSel = fromIndex >= 0;
    final toSel = toIndex >= 0;
    final hasPill = fromSel || toSel;
    ({double left, double width}) selBox(int idx) {
      final l = layoutFor((i) => i == idx ? 1.0 : 0.0);
      return (left: l.left[idx], width: selectedW(idx));
    }

    // One end "none" → both anchor on the valid slot, so the pill FADES in/out in place (no slide); two
    // valid ends → it slides. 一端无选中:锚同一有效槽 → 药丸原地淡入/淡出;两端有效 → 滑动。
    final startIdx = fromSel ? fromIndex : toIndex;
    final endIdx = toSel ? toIndex : fromIndex;
    double pillLeft = 0, pillW = 0, pillOpacity = 0;
    if (hasPill) {
      final sb = selBox(startIdx);
      final eb = selBox(endIdx);
      pillLeft = lerpDouble(sb.left, eb.left, e)!;
      pillW = lerpDouble(sb.width, eb.width, e)!;
      pillOpacity = lerpDouble(fromSel ? 1.0 : 0.0, toSel ? 1.0 : 0.0, e)!;
    }

    final restFrom = layoutFor((i) => i == fromIndex ? 1.0 : 0.0);
    final restTo = layoutFor((i) => i == toIndex ? 1.0 : 0.0);
    const pillTop = 0.0;
    const pillH = _rowH;
    const pillR = AnRadius.button;

    // Fixed box width = the wider resting layout, so the switcher box doesn't jump as it reflows.
    // 盒宽取较宽的静止布局,回流时盒子不跳。
    final totalW = math.max(restFrom.total, restTo.total);

    return SizedBox(
      width: totalW,
      height: _rowH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The single shared highlight pill (behind the slots; each slot draws no background). Absent
          // when there's no selection. 唯一共享高亮药丸(在槽后;槽自身不画底);无选中时不画。
          if (hasPill)
            Positioned(
              left: pillLeft,
              top: pillTop,
              width: pillW,
              height: pillH,
              child: Opacity(
                opacity: pillOpacity.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceActive,
                    borderRadius: BorderRadius.circular(pillR),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: cur.left[i],
              top: 0,
              width: cur.width[i],
              height: _rowH,
              child: _slot(context, c, i, selOf(i)),
            ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, AnColors c, int i, double s) {
    final it = items[i];
    final fg = Color.lerp(c.inkMuted, c.ink, s.clamp(0.0, 1.0))!;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(it.icon, size: AnSize.icon, color: fg),
        if (s > 0.001)
          // Reveal the (gap + label) from the left so the gap eases in too (no sudden 8px pop).
          // 从左揭示(间距+标签),间距也缓入(不突跳)。
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: s.clamp(0.0, 1.0),
              child: Opacity(
                opacity: s.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: _iconGap),
                  child: Text(
                    it.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: fg),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return AnInteractive(
      onTap: onTap == null ? null : () => onTap!(i),
      selected: i == toIndex,
      // The highlight is the shared pill behind; the slot itself stays transparent. 高亮由后方共享药丸提供,槽透明。
      builder: (context, states) => content,
    );
  }
}
