import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../platform/host_platform.dart';

/// The top-left window-controls zone of the chrome bar.
///
/// On macOS the OS draws the real traffic lights on the frameless window — positioned by
/// [WindowChrome] to line up with the chrome bar — so here we only RESERVE their width
/// (`windowControlsInset`) and never draw fake dots. On Windows/Linux there are no left-side
/// OS controls, so the same slot carries the product identity (mark + name) instead. One
/// definition, used by both the sidebar's top bar and the ocean's collapsed header, so the
/// two layouts stay byte-identical at the leading edge.
///
/// 顶栏条左上的窗控区。macOS:OS 在无边框窗画真红绿灯(由 WindowChrome 对齐到顶栏条),这里只
/// **留位**、绝不画假点。Windows/Linux:无左侧 OS 控件 → 同一槽放产品标+名。单处定义,侧栏顶栏与
/// 海洋收起头共用,保证两布局前导边逐像素一致。
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
