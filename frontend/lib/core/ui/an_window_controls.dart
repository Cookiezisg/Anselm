import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../platform/host_platform.dart';
import '../platform/window_fullscreen.dart';
import 'an_brand_icon.dart';

/// The top-left window-controls zone of the left island's chrome bar.
///
/// The product identity (mark + name) shows wherever there are NO OS traffic lights: always on
/// Windows/Linux, and on macOS ONLY in native fullscreen (the OS hides the lights there, freeing this spot
/// — #10, "like Windows"). Windowed macOS instead RESERVES the lights' horizontal room
/// (`windowControlsInset`) and never draws fake dots (the OS draws the real lights, centered in the taller
/// title bar by macos_window_utils `addToolbar`; see window_setup).
///
/// 左岛顶栏左上窗控区。产品标+名在**无 OS 红绿灯**处显示:Windows/Linux 恒显;macOS **仅全屏**显(OS 藏灯、
/// 位空出——#10「像 Windows」)。macOS 小窗则只**留红绿灯横位**、绝不画假点(OS 画真灯)。
class AnWindowControls extends StatelessWidget {
  const AnWindowControls({super.key});

  Widget _brand(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s4, right: AnSpace.s8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnBrandIcon.anselm(size: AnBrandSize.sm),
          const SizedBox(width: AnSpace.s8),
          Text(context.t.appName, style: AnText.strong.copyWith(color: c.ink)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (HostPlatform.isMacOS) {
      // Windowed: reserve the traffic-lights' horizontal room. Fullscreen: the OS hides the lights, so the
      // freed spot carries the product identity — same mark + name as Windows/Linux (#10).
      // 小窗:留红绿灯横位;全屏:灯消失、空位放产品标+名(与 Win/Linux 同款,#10)。
      return ValueListenableBuilder<bool>(
        valueListenable: WindowFullScreen.active,
        builder: (context, fullScreen, _) =>
            fullScreen ? _brand(context) : const SizedBox(width: AnSize.windowControlsInset),
      );
    }
    return _brand(context);
  }
}
