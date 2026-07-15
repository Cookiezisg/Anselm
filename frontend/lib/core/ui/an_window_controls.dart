import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../platform/host_platform.dart';
import '../platform/window_fullscreen.dart';
import 'an_brand_icon.dart';

/// The top-left window-controls zone: it reserves the OS traffic-lights' horizontal room, and — only where
/// asked ([showBrand]) — carries the product identity (mark + name) once those lights are gone.
///
/// The brand belongs to the LEFT ISLAND alone (拍板: 品牌标只在左岛上). So [showBrand] is opt-in and set at
/// exactly one call site — the island's chrome bar; every other reservation (the collapsed-island reopen
/// zone, the workflow-editor top bar) leaves it OFF and draws NO brand. In all cases the windowed-macOS
/// behaviour is identical: reserve `windowControlsInset` and draw nothing (the OS paints the real lights,
/// centered in the taller title bar by macos_window_utils `addToolbar`; see window_setup). The split is only
/// where the OS HIDES the lights (macOS fullscreen, or always on Windows/Linux): there [showBrand] draws the
/// mark + name (#10, "like Windows"); otherwise the zone collapses to nothing.
///
/// 左上窗控区:留 OS 红绿灯横位;仅在 [showBrand] 处、灯消失后放产品标+名。品牌**只属左岛**(拍板)——故 [showBrand]
/// 是**选择加入**、只在左岛顶栏一处打开;其余预留(收起后 reopen 区、workflow 编辑器顶条)一律关、绝不画品牌。小窗
/// macOS 行为不分彼此:留 windowControlsInset、不画(OS 画真灯)。分岔只在**灯被藏处**(macOS 全屏 / Win-Linux 恒
/// 无灯):showBrand 处画标+名(#10「像 Windows」),否则整块收零。
class AnWindowControls extends StatelessWidget {
  const AnWindowControls({this.showBrand = false, super.key});

  /// Draw the product mark + name where the OS lights are gone (fullscreen macOS / Win-Linux). Opt-in —
  /// only the left island's chrome bar sets it; elsewhere the zone stays brand-free.
  /// 灯消失处画产品标+名(全屏 macOS / Win-Linux)。选择加入——仅左岛顶栏打开,余处无品牌。
  final bool showBrand;

  Widget _brand(BuildContext context) {
    final c = context.colors;
    // Left inset = [AnSize.btnPadXSm]: the SAME token the ocean-switcher insets its icon by, so the naked mark
    // lands on the nav ICON column below — NOT the slot/pill wrapper edge (拍板: 对齐图标本身, 不对齐那圈灰套). The
    // mark↔wordmark gap = [AnGap.inline], the same icon↔label gap the nav uses, so the wordmark rides the nav
    // LABEL column too. Grey naked mark + Newsreader wordmark; vertical rhythm unchanged for now (deferred).
    // 左内距 = btnPadXSm(switcher 给图标的同一 token),裸 mark 落到下方 nav 图标列、非套边;mark↔字 = AnGap.inline(nav 的 icon↔label 同 token),
    // 字也落 nav 标签列。灰裸 mark + Newsreader wordmark;竖向节奏暂不动(留最后)。
    return Padding(
      padding: const EdgeInsets.only(left: AnSize.btnPadXSm, right: AnSpace.s8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnBrandIcon.mark(),
          const SizedBox(width: AnGap.inline),
          // Fit the wordmark's CAP-A exactly into the mark's vertical band — A's apex on the mark's top edge,
          // A's baseline on the mark's bottom edge (拍板: 上下都齐平). The 18px wordmark's cap height already
          // equals the mark's block height (~12.5), so this is a pure position fix: crossAxisAlignment.center
          // centres the TEXT BOX, but Newsreader's empty descent (no descenders in "Anselm") floats the caps
          // high — nudge the PAINT down by a measured Newsreader constant (paint-only Transform, layout
          // unchanged, Row still sizes to the glyphs). 让大写 A 正好嵌进 mark 竖带(A 顶=mark 顶、A 基线=mark 底):18px cap 高已≈mark
          // 块高,故纯位置校正——盒居中因 Newsreader 空降部让无降部的「Anselm」偏高,按度量常量把绘制下移(仅绘制、不改布局)。
          Transform.translate(
            offset: const Offset(0, _wordmarkOpticalDrop),
            child: Text(context.t.appName, style: AnText.wordmark.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }

  // Paint-drop that seats the Newsreader wordmark's cap-A into the mark's block band (its caps otherwise float
  // high on the box's empty descent). Font/size-specific optical correction (same class as the editor's
  // caret/inline-code nudges), calibrated on-device. 把 Newsreader wordmark cap-A 坐进 mark 块带的度量下移校正,真机标定。
  static const double _wordmarkOpticalDrop = 2.5;

  @override
  Widget build(BuildContext context) {
    if (HostPlatform.isMacOS) {
      // Windowed: reserve the traffic-lights' horizontal room (identical whether or not this zone owns the
      // brand — the OS draws the real lights here regardless). Fullscreen: the OS hides the lights; the freed
      // spot carries the identity ONLY where opted in ([showBrand] — the left island), else collapses to
      // nothing so a brand-free zone (reopen area, editor) leaves the reopen/back control at the edge.
      // 小窗:留红绿灯横位(是否带品牌都一样,OS 在此画真灯);全屏:灯消失,仅 showBrand 处(左岛)放标+名,余处收零
      // 让无品牌区(reopen、编辑器)的 reopen/返回控件贴边。
      return ValueListenableBuilder<bool>(
        valueListenable: WindowFullScreen.active,
        builder: (context, fullScreen, _) => fullScreen
            ? (showBrand ? _brand(context) : const SizedBox.shrink())
            : const SizedBox(width: AnSize.windowControlsInset),
      );
    }
    // No OS lights ever (Windows/Linux): the brand rides here where opted in, else nothing.
    // Win/Linux 恒无 OS 灯:showBrand 处放品牌,余处无。
    return showBrand ? _brand(context) : const SizedBox.shrink();
  }
}
