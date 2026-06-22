import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'an_window_controls.dart';

/// The window's top chrome strip: a fixed-height ([AnSize.row]) row whose vertical center is
/// engineered to line up with the macOS traffic lights (the lights are positioned natively to
/// match — see [WindowChrome] + [AnSize.trafficLightCenterY]). When [leading] is set it
/// reserves the window-controls zone ([AnWindowControls]) at the start; [children] follow.
///
/// Both the left island's top bar (lights at left, collapse/search pushed right) and the
/// ocean's collapsed header (lights at left, reopen button right beside them) compose from this
/// single primitive, so the lights align identically across the open and collapsed layouts —
/// the geometry has exactly one home.
///
/// Callers place the bar 12px below the container top (the island's padding gives this for
/// free; the ocean header adds it explicitly) so its center lands at [AnSize.trafficLightCenterY]
/// from the window top.
///
/// 窗体顶栏条:定高(行高)的一行,纵向中心**刻意**对齐 macOS 红绿灯(灯由原生按 trafficLightCenterY
/// 对齐过来)。[leading] 置位时在行首留窗控区([AnWindowControls]),其后接 [children]。左岛顶栏
/// (灯在左、收起/搜索推到右)与海洋收起头(灯在左、reopen 钮紧贴其右)都用这一个原语 → 两布局灯位
/// 天然一致,几何只有一处家。调用方把本条放在容器顶下 12px(岛的内距自带、海洋头显式加),
/// 使其中心落在窗顶下 trafficLightCenterY。
class AnChromeBar extends StatelessWidget {
  const AnChromeBar({super.key, this.leading = true, required this.children});

  /// Reserve the leading window-controls zone (the macOS traffic-light slot / product mark).
  /// 是否在行首留窗控区(macOS 红绿灯槽 / 产品标)。
  final bool leading;

  /// The controls laid into the row after the leading zone. Use `Spacer`/`Expanded` to push
  /// trailing controls to the right. 前导区之后排入的控件;用 Spacer/Expanded 把尾部控件推到右。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AnSize.row,
      child: Row(
        children: [
          if (leading) const AnWindowControls(),
          ...children,
        ],
      ),
    );
  }
}
