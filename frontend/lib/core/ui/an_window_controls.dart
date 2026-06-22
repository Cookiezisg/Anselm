import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../platform/host_platform.dart';

/// The top-left window-controls zone of the left island's chrome bar.
///
/// On macOS the OS draws the real traffic lights, centered by the OS in the taller title bar
/// (macos_window_utils `addToolbar` — click-safe; see window_setup), so here we only RESERVE their
/// horizontal room (`windowControlsInset`) and never draw fake dots. On Windows/Linux there are
/// no left-side OS controls, so the same slot carries the product identity (mark + name).
///
/// 左岛顶栏左上的窗控区。macOS:OS 在加高标题栏里居中画真红绿灯(macos_window_utils addToolbar、点击不坏,
/// 见 window_setup),这里只**留横向位**、绝不画假点。Windows/Linux:无左侧 OS 控件 → 同一槽放产品标 + 名。
class AnWindowControls extends StatelessWidget {
  const AnWindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    if (HostPlatform.isMacOS) {
      return const SizedBox(width: AnSize.windowControlsInset);
    }
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s4, right: AnSpace.s8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Placeholder mark — real logo from brand/ to be bundled later. 占位标,真 logo 待打包。
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(AnRadius.tag),
            ),
          ),
          const SizedBox(width: AnSpace.s8),
          Text('Anselm', style: AnText.strong.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
