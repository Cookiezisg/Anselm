import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_hover_region.dart';

/// A hover-revealed, NON-interactive detail card anchored above its [child] (WRK-070 §A#2 调度轨重造 B3).
/// It is [AnTooltip]'s richer sibling: the tooltip machinery is text-only (a plain [Tooltip] decoration),
/// so a card that lists rows (a status dot + a time + a source word + an elapsed measure) needs its own
/// overlay — but it keeps the tooltip's manners: reveal only after a dwell ([AnMotion.dwell], so casual
/// mouse travel never flashes cards), island surface + hairline + pop shadow, and — the load-bearing
/// part — it is PURELY a display. The whole card is [IgnorePointer] (the cursor never «enters» it, so it
/// cannot steal the hover from the cell it describes and self-flicker) and [ExcludeSemantics] (the
/// screen reader hears the cell's OWN sentence, never a second reading of the same facts — sight and
/// hearing each get one complete, non-duplicated channel).
///
/// **Scroll-freeze**: the reveal rides [AnHoverRegion], so a track sliding under a parked cursor during
/// an overscroll never pops a card (0718 滚动闪烁审定) — the same law every hover-swapping surface follows.
///
/// The content is built LAZILY ([cardBuilder]) and only while shown — a grid of cells wires one of these
/// per content cell, and a collapsed (un-hovered) card must cost nothing.
///
/// hover 揭示的**不可交互**明细卡,锚在 [child] 正上方(调度轨重造 B3)——[AnTooltip] 的富内容兄弟:tooltip 机制
/// 只吃文字,而要列出行(状态点+时刻+来源词+耗时)的卡需要自己的 overlay,但沿用 tooltip 的礼数:驻留满
/// [AnMotion.dwell] 才现(鼠标路过绝不闪卡)、岛面+发丝边+pop 影,且——**承重的那半**——它**纯是展示**:整卡
/// [IgnorePointer](光标永不「进入」它,故夺不走它所描述那格的 hover、不自激闪烁)+ [ExcludeSemantics](读屏听格
/// 自己的句子,绝不重念同一批事实——视觉与听觉各得一条完整、不重复的通道)。滚动中经 [AnHoverRegion] 冻结:
/// overscroll 拖轨过静止光标绝不弹卡。内容 [cardBuilder] **惰性**构建、仅显示时建(格网每个内容格接一个,收起零成本)。
class AnHoverCard extends StatefulWidget {
  const AnHoverCard({
    required this.child,
    required this.cardBuilder,
    this.enabled = true,
    this.maxWidth = AnSize.menuMaxWidth,
    super.key,
  });

  final Widget child;

  /// Builds the card's body — called only while the card is shown. 卡体构建器,仅显示时调用。
  final WidgetBuilder cardBuilder;

  /// A cell with nothing to show (an empty bin) passes false — no anchor, no timer, no overlay. 空格关。
  final bool enabled;

  final double maxWidth;

  @override
  State<AnHoverCard> createState() => _AnHoverCardState();
}

class _AnHoverCardState extends State<AnHoverCard> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  Timer? _dwell;

  @override
  void dispose() {
    _dwell?.cancel();
    super.dispose();
  }

  void _enter() {
    if (!widget.enabled) return;
    _dwell?.cancel();
    // Dwell before revealing — the ONE hover tier ([AnMotion.dwell]), so a cursor gliding across the
    // grid never leaves a trail of flashing cards. 驻留满一档才现,划过格条不留一串闪卡。
    _dwell = Timer(AnMotion.dwell, () {
      if (mounted) _portal.show();
    });
  }

  void _exit() {
    _dwell?.cancel();
    if (_portal.isShowing) _portal.hide();
  }

  @override
  void didUpdateWidget(AnHoverCard old) {
    super.didUpdateWidget(old);
    // A cell that lost its content mid-hover (a refetch emptied its bin) must not keep a stale card up.
    // 悬停中失去内容的格(重取清空了桶)不得留一张过期卡。
    if (old.enabled && !widget.enabled) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CompositedTransformTarget(
      link: _link,
      child: AnHoverRegion(
        onEnter: (_) => _enter(),
        onExit: (_) => _exit(),
        child: OverlayPortal(
          controller: _portal,
          // Align, NEVER a bare Positioned: the Overlay theatre FORCES a non-positioned child to the
          // full stage with TIGHT constraints, and tight beats the Container's maxWidth — the card
          // became a screen-sized white slab (用户 0718 真机撞上的大白片). Align lets the card size to
          // its content, then the follower paints it at the anchor. Locked by an_hover_card_test.
          // 用 Align、绝不裸 Positioned:Overlay 剧场把非定位子件**强制铺满全台**(tight 碾过 maxWidth)
          // ——卡曾变成挡半个 app 的大白片。Align 让卡按内容定尺寸,follower 再把它画到锚点。测试锁死。
          overlayChildBuilder: (context) => Align(
            alignment: AlignmentDirectional.topStart,
            // The card floats ABOVE the cell, centred on it, one gap clear (topCenter↔bottomCenter).
            // 卡浮在格正上方、居中、隔一档(topCenter↔bottomCenter)。
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -AnSpace.s8),
              // IgnorePointer: the cursor never enters the card, so it can never dispute the hover with
              // the cell it describes. ExcludeSemantics: the cell already speaks; a second reading is
              // noise. 光标不进卡→不与格争 hover;格已发声→二次朗读是噪声。
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: widget.maxWidth),
                    padding: AnInset.snug,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line, width: AnSize.hairline),
                      borderRadius: BorderRadius.circular(AnRadius.card),
                      boxShadow: c.shadowPop,
                    ),
                    child: widget.cardBuilder(context),
                  ),
                ),
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
