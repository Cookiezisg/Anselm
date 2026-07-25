import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../perf/frame_safe.dart';
import 'an_button.dart';
import 'an_expand_reveal.dart';
import 'an_island.dart';
import 'an_selection_region.dart';
import 'an_window_controls.dart';
import 'icons.dart';

/// The top inset that drops a shell top control's CENTER onto the OS traffic-lights' horizontal line. The
/// lights are centered in a [bandHeight] band at the window top (queried at runtime — varies with the
/// toolbar config), so the control center must sit at `bandHeight/2` from the window top; the islands begin
/// [AnSize.shellPad] below the window top, so the control is offset `bandHeight/2 - shellPad - control/2`
/// from its band's top (clamped ≥ 0 for small/absent bands, e.g. non-macOS). 顶控落到红绿灯水平线的顶距。
double _controlInset(double bandHeight) =>
    (bandHeight / 2 - AnSize.shellPad - AnSize.control / 2).clamp(
      0.0,
      AnSize.islandHead,
    );

/// The notice crown is taller than a standard top control, but its CENTER belongs to the exact same
/// title-band axis. Keep this derivation separate so changing either family never silently misaligns the
/// other. 通知冠部虽高于标准顶控,中心仍落同一标题带轴;独立推导,两族改尺寸互不拖偏。
double _noticeInset(double bandHeight) =>
    (bandHeight / 2 - AnSize.shellPad - AnSize.noticeBar / 2).clamp(
      0.0,
      AnSize.islandHead,
    );

/// The three-island desktop shell skeleton: a left island ([sidebar]), the open ocean ([ocean]) — the
/// window's white surface, no card — and a right island ([inspector]). 8px padding around + 8px gaps
/// between. The LEFT island is drag-resizable (240–400) AND collapsible (its top chrome bar carries the
/// collapse button; when collapsed the whole island slides away and a reopen button appears in the ocean's
/// floating head). The RIGHT island is fixed (320) and reveals on [inspectorOpen]. The OCEAN carries a
/// FLOATING HEAD overlay (a transparent band over the top with a scrim gradient) holding — left → right —
/// the reopen button (only when the sidebar is collapsed), the feature [head] (a scroll-collapsed
/// breadcrumb), then the right-island toggle (only when an inspector is present). The head is click-through
/// except its corner controls, so content scrolls under it. The macOS traffic lights are OS-drawn in the
/// taller title bar; the chrome bar + floating head sit on the same band so all top controls align.
///
/// State (collapse / width / breadcrumb) is OWNED BY THE CALLER (app providers) and fed as props — the kit
/// stays Riverpod-free. The grip drags a LOCAL width for smoothness and commits via [onLeftWidthCommitted]
/// on release.
///
/// 三岛桌面 shell:左岛(可拖 240–400 + 可收起,收起钮在其顶栏、收起后整岛滑走、海洋浮层头现 reopen)· 敞开海洋
/// (含浮层头:reopen[仅收起时] + 面包屑 head + 右岛切换[仅有 inspector])· 右岛(固定 320,inspectorOpen 揭示)。
/// 浮层头点击穿透、仅角落可点,正文从其下滚过;红绿灯由 OS 在加高标题栏画,顶栏与浮层头同带、所有顶控对齐。
/// 状态(收起/宽度/面包屑)由调用方(app provider)持有、以 props 喂入,套件不沾 Riverpod。
class AnShell extends StatefulWidget {
  const AnShell({
    super.key,
    this.sidebar,
    this.ocean,
    this.inspector,
    this.inspectorOpen = true,
    this.rightWidth = AnSize.rightIsland,
    this.onRightWidthCommitted,
    this.leftCollapsed = false,
    this.leftWidth = AnSize.sidebar,
    this.onToggleLeft,
    this.onLeftWidthCommitted,
    this.head,
    this.headTrailing,
    this.bandNotice,
    this.onToggleRight,
    this.rightActivity = false,
    this.titlebarHeight = AnSize.titlebar,
  });

  final Widget? sidebar;
  final Widget? ocean;
  final Widget? inspector;

  /// The OS title-bar band height (where macOS centers the traffic lights), queried at runtime by the
  /// caller (0 on platforms without left-side OS lights). The top controls center on `titlebarHeight/2`.
  /// OS 标题栏带高(红绿灯居中处),调用方运行时查询;顶控对齐到 titlebarHeight/2。
  final double titlebarHeight;

  /// Reveal / hide the right island (a feature opens it for a selected entity). 右岛揭示/收起。
  final bool inspectorOpen;

  /// The right island's drag width (user-owned, mirrors [leftWidth]; persisted by the caller).
  /// 右岛拖宽(用户所有,镜像左岛;调用方持久化)。
  final double rightWidth;

  /// Commit a right-island drag width on release. 右岛拖宽提交(松手)。
  final ValueChanged<double>? onRightWidthCommitted;

  /// Left island collapsed → slides away; the ocean head shows a reopen button. 左岛收起。
  final bool leftCollapsed;
  final double leftWidth;
  final VoidCallback? onToggleLeft;

  /// Called on drag-RELEASE with the new width (clamped by the caller/persist). 拖拽结束提交新宽度。
  final ValueChanged<double>? onLeftWidthCommitted;

  /// The feature's floating-head content (a scroll-collapsed breadcrumb), between reopen + panel-right.
  /// feature 的浮层头内容(随滚动折叠的面包屑)。
  final Widget? head;

  /// Head TRAILING content — sits between the (width-constrained) [head] and the panel-right toggle, so a
  /// per-ocean action (e.g. chat's scene/outline nav) lands RIGHT beside the right-island button rather than
  /// at the head content's far edge. 头尾内容:落在 head 与右岛钮之间,让每海洋动作(chat 场次导航)贴右岛钮左边。
  final Widget? headTrailing;

  /// The chrome-band notice slot (the event capsule) — centered over the head band, hit-test only on
  /// itself, z-above the breadcrumb (covering it for a few seconds is acceptable; it never covers WORK
  /// content). Fed by the app layer (DIP — the kit stays feature-free). 顶带通知槽(事件胶囊):带上居中、
  /// 仅自身可命中、z 在面包屑上(盖路径几秒可接受,绝不盖工作内容);app 层喂入(DIP,套件不沾 feature)。
  final Widget? bandNotice;

  /// Toggle the right island manually (the panel-right button; shown only when [inspector] exists).
  /// 手动切换右岛(panel-right 钮,仅有 inspector 时显)。
  final VoidCallback? onToggleRight;

  /// A LIVE activity is happening behind a COLLAPSED right island (WRK-061 R-15: the collapsed
  /// state keeps only this bit) — a soft accent dot rides the panel-right button so the user knows
  /// the sidestage has something to show without being interrupted.
  /// 收起的右岛后面有 live 活动(R-15:收起只留此位)——panel-right 钮伴一枚柔 accent 点,告知侧幕
  /// 有戏可看、又不打扰。
  final bool rightActivity;

  @override
  State<AnShell> createState() => _AnShellState();
}

class _AnShellState extends State<AnShell> {
  // Island reveal/hide animation bookkeeping (S11): while EITHER island is sliding AND the ocean is
  // in the reflow zone (narrower than the full reading column), the ocean is laid out ONCE at its
  // TARGET width behind a clip — the island then covers/reveals it, instead of the width animation
  // relayouting the whole ocean viewport (paragraph re-shape) on every frame. Wide windows keep the
  // continuous animation: their per-frame relayout is cheap (the 720-column constraint doesn't
  // change, paragraph layout caches hit) and the gliding column looks better. Drags never freeze —
  // tracking the hand IS the feature.
  // 岛屿开合动画记账(S11):任一岛滑动中且海洋处于 reflow 区(窄于完整阅读列)时,海洋按**终态宽**
  // 一次排版、藏在裁切后——岛盖上/揭开它,而非宽度动画逐帧 relayout 整个海洋视口(段落 re-shape)。
  // 宽窗保持连续动画(720 列约束不变、段落布局缓存命中,滑动列更好看)。拖拽绝不冻结——跟手即功能。
  bool _leftAnimating = false;
  bool _rightAnimating = false;

  // The ocean-width the CURRENT target state implies, remembered across a target flip so the freeze
  // gate can consider BOTH ends of the animation (either end inside the reflow zone freezes).
  // 目标态占宽记账(翻转前的旧值即动画起点)——冻结闸看动画两端,任一端入 reflow 区即冻。
  double _prevTaken = 0;

  double _takenOf({
    required bool leftCollapsed,
    required double leftWidth,
    required bool inspectorOpen,
    required double rightWidth,
  }) =>
      (leftCollapsed ? 0.0 : leftWidth + AnSize.shellGap) +
      (inspectorOpen ? rightWidth + AnSize.shellGap : 0.0);

  @override
  void initState() {
    super.initState();
    _prevTaken = _takenOf(
      leftCollapsed: widget.leftCollapsed,
      leftWidth: widget.leftWidth,
      inspectorOpen: widget.inspectorOpen,
      rightWidth: widget.rightWidth,
    );
  }

  @override
  void didUpdateWidget(AnShell old) {
    super.didUpdateWidget(old);
    if (old.leftCollapsed != widget.leftCollapsed ||
        old.inspectorOpen != widget.inspectorOpen) {
      _prevTaken = _takenOf(
        leftCollapsed: old.leftCollapsed,
        leftWidth: old.leftWidth,
        inspectorOpen: old.inspectorOpen,
        rightWidth: old.rightWidth,
      );
    }
    // Arm the gate in the same frame the toggle lands, rather than relying on the child's slide-start
    // report (which, arriving mid-build, can only take effect a frame later).
    //
    // MEASURED, because the ticket claimed otherwise: the late arming does NOT leak a relayout. On the flip
    // frame the child's controller has not ticked yet, so the ocean's width is unchanged and nothing
    // relayouts; the gate is armed by the first frame where the width actually moves. Removing the
    // arming again leaves every S11 test green — so this is not a fix, it is the invariant stated in the
    // code instead of being an accident of when the controller happens to tick. The ticket's "the first
    // frame is unfrozen and the last is already thawed, both ends leak" is wrong on both ends: a late
    // DISARM is harmless too (one extra frame pinned at the TARGET width, which is the final width).
    //
    // 在**切换落地的同一帧**上膛,而不依赖子件报告滑动开始(那份报告在 build 中途抵达,最早只能下一帧生效)。
    //
    // **实测过,因为工单的判断与此相反**:晚一帧上膛**不会**漏出 relayout。翻转那一帧子件的控制器尚未走动,海洋
    // 宽度没变、无处 relayout;而在宽度真正开始移动的第一帧,闸已经上膛。把这两行删掉,S11 全部测试依然绿——
    // 所以这不是一个修复,而是把不变量**写进代码**,不再让它是「控制器恰好何时走动」的副产品。工单那句「首帧未冻、
    // 末帧已解,两端都露」两端都不成立:晚一帧**下膛**同样无害(多冻一帧在**终态宽**上,而那就是最终宽度)。
    if (old.leftCollapsed != widget.leftCollapsed) _leftAnimating = true;
    if (old.inspectorOpen != widget.inspectorOpen) _rightAnimating = true;
  }

  // The SETTLE only (see didUpdateWidget for the arming). It arrives synchronously from a child's
  // didUpdateWidget, i.e. mid-build, so it must not dirty the shell in place.
  // 只走**落定**(上膛见 didUpdateWidget)。它从子件的 didUpdateWidget 同步到达,即 build 中途,故不可就地弄脏壳。
  void _setAnimating({required bool left, required bool value}) {
    runFrameSafe(() {
      if (!mounted) return;
      if ((left ? _leftAnimating : _rightAnimating) == value) return;
      setState(() => left ? _leftAnimating = value : _rightAnimating = value);
    });
  }

  // Below this ocean width the reading column loses its fixed 720 constraint and every visible
  // paragraph re-shapes per relayout — the freeze gate's threshold. 低于此宽阅读列失去 720 定约束、
  // 每次 relayout 段落逐个 re-shape——冻结闸阈值。
  static const double _reflowFloor = AnSize.content + AnInset.pageX * 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final controlInset = _controlInset(
      widget.titlebarHeight,
    ); // drop top controls onto the lights' line 顶控落到灯线
    final noticeInset = _noticeInset(
      widget.titlebarHeight,
    ); // 36px notice crown on that same axis 36 冠部同轴
    // WIDTH COMES FROM THE WINDOW, NOT FROM LAYOUT (CR-1a). This used to be a LayoutBuilder, and
    // that single choice put the ENTIRE app inside a layout callback: both islands and all four
    // oceans were built — first-mounted, provider graphs initialised, SSE subscriptions opened —
    // during the LAYOUT phase. Anything that then asked to rebuild (a scroll listener touching a
    // provider, Riverpod invalidating itself while its own dependency flushed) tripped
    // "setState/markNeedsBuild called during build", and one such trip corrupted the element tree
    // badly enough to crash the process. The shell only ever needed one number — its own width —
    // and it is ALWAYS the window's: AnShell is the MaterialApp `home` in the app and in every test.
    //
    // 宽度取自窗口,不取自布局(CR-1a)。这里原本是 LayoutBuilder,而仅此一个选择就把**整个 app** 装进了
    // 布局回调:两岛与四海洋的首次挂载、provider 图初始化、SSE 订阅,全部发生在**布局阶段**。此后任何
    // 请求重建的动作(滚动监听里碰一下 provider、Riverpod 在自身依赖冲刷时自失效)都会撞上
    // 「setState/markNeedsBuild called during build」,其中一次足以把 element 树弄坏到进程崩溃。
    // 壳需要的从来只是一个数——它自己的宽度——而那恒等于窗宽:AnShell 在 app 与每个测试里都是
    // MaterialApp 的 home。
    final shellWidth = MediaQuery.sizeOf(context).width - AnSize.shellPad * 2;
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(AnSize.shellPad),
        child: Builder(
          builder: (context) {
            // The right island may be dragged wide (rightIslandMax) but the OCEAN keeps its floor: the
            // live drag ceiling is whatever width remains after the left island + oceanMin + gaps.
            // 右岛可拖宽,但海洋保底优先:动态上限=扣除左岛/海洋下限/间距后的余宽。
            final leftTaken = widget.leftCollapsed
                ? 0.0
                : widget.leftWidth + AnSize.shellGap;
            final rightCeiling =
                (shellWidth - leftTaken - AnSize.oceanMin - AnSize.shellGap)
                    .clamp(AnSize.rightIslandMin, AnSize.rightIslandMax);

            // ── the reveal-freeze gate (S11, see the State doc) 开合冻结闸 ──
            final targetTaken = _takenOf(
              leftCollapsed: widget.leftCollapsed,
              leftWidth: widget.leftWidth,
              inspectorOpen: widget.inspectorOpen,
              rightWidth: widget.rightWidth,
            );
            final targetOceanW = (shellWidth - targetTaken).clamp(
              AnSize.oceanMin,
              shellWidth,
            );
            final prevOceanW = (shellWidth - _prevTaken).clamp(
              AnSize.oceanMin,
              shellWidth,
            );
            final freeze =
                (_leftAnimating || _rightAnimating) &&
                (targetOceanW < _reflowFloor || prevOceanW < _reflowFloor);

            Widget oceanHost = _OceanRegion(
              ocean: widget.ocean,
              head: widget.head,
              headTrailing: widget.headTrailing,
              bandNotice: widget.bandNotice,
              showReopen: widget.leftCollapsed,
              onReopen: widget.onToggleLeft,
              controlInset: controlInset,
              noticeInset: noticeInset,
              // panel-right shows only when there's a bound right island (caller passes the callback iff
              // an entity is selected) — mirrors the demo's has-right gate. 仅有绑定右岛时显(对齐 demo has-right)。
              showRightToggle: widget.onToggleRight != null,
              onToggleRight: widget.onToggleRight,
              rightActivity: widget.rightActivity,
            );
            // Lay the ocean out ONCE at its TARGET width while an island slides; the island covers or
            // reveals the clipped edge. A left-island slide pins the ocean to its END edge (the LEFT edge
            // is the moving one), a right-island slide pins to START.
            //
            // The clip and the overflow box are UNCONDITIONAL and the freeze is expressed in their
            // PARAMETERS — the same idiom the right island already uses for its shadow
            // (`clipper: cond ? const _UnclippedRect() : null`). Adding and removing these two wrappers
            // instead, which is how this was written, changed the ocean slot's runtimeType twice per
            // toggle and so REBUILT THE WHOLE OCEAN twice — the gate opening once and closing once. With
            // a chat transcript (variable-height items addressed by a pixel offset) a rebuild at a new
            // width re-shapes every paragraph, so the same offset then points at a completely different
            // message: the user's "the ocean jumps twice, very obviously", captured frame by frame on
            // their machine. The cruellest part is that this gate exists to make narrow-window toggles
            // SMOOTHER, and it was the sole cause of the jitter there.
            //
            // 岛滑动时海洋按**终态宽**一次排版,由岛盖住/揭开被裁的边。左岛滑动钉尾缘(左缘在动),右岛钉首缘。
            //
            // 裁切与溢出框**无条件**恒在,冻结只体现在它们的**参数**里——与右岛为阴影所用的同一范式
            // (`clipper: cond ? const _UnclippedRect() : null`)。原写法是把这两层包装加上去、再摘下来,
            // 于是每次切换让海洋 slot 的 runtimeType 变两次、**整棵海洋重建两次**(闸开一次、闸闭一次)。而
            // chat transcript 是变高条目 + 像素偏移寻址,按新宽重建会 re-shape 每个段落,同一偏移随后指向的
            // 已是完全不同的消息:这就是用户那句「海洋明显跳两下」,并已在他机器上逐帧截证。最刺的是,这道闸
            // 本就是为了让窄窗切换**更顺滑**而建,而它是窄窗抖动的唯一成因。
            oceanHost = ClipRect(
              clipper: freeze ? null : const _UnclippedRect(),
              child: OverflowBox(
                alignment: _leftAnimating && !_rightAnimating
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                // null → pass the incoming constraints straight through, i.e. no pinning at all.
                // null → 原样透传入约束,即完全不钉。
                minWidth: freeze ? targetOceanW : null,
                maxWidth: freeze ? targetOceanW : null,
                child: oceanHost,
              ),
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LeftReveal(
                  collapsed: widget.leftCollapsed,
                  width: widget.leftWidth,
                  onWidthCommitted: widget.onLeftWidthCommitted,
                  onAnimating: (v) => _setAnimating(left: true, value: v),
                  child: AnIsland(
                    // No TOP pad: the chrome bar reaches the island's top edge so its controls vertically
                    // center on the OS traffic lights (the bar IS the title-bar band). 顶不留白:chrome bar 抵岛顶,顶控与红绿灯居中对齐。
                    padding: const EdgeInsets.fromLTRB(
                      AnSpace.s12,
                      0,
                      AnSpace.s12,
                      AnSpace.s12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // No spacer below the chrome bar: the bar is [islandHead] (44) tall but its controls
                        // occupy only [controlInset]+[control] (≈32) from the top, so it ALREADY carries ~12px
                        // of intrinsic slack beneath the traffic-light/collapse row — that slack IS the gap to
                        // the ocean switcher. The old s8 spacer double-padded it (~20px, too large per B11);
                        // dropping it leaves a derived ~12px gap that reads consistent with the sidebar's own
                        // s8 rhythm. 不加间距:chrome 带 44 高、控件仅占顶部 ≈32,自带 ≈12px slack=到切换器的间距;
                        // 旧 s8 双重填充(≈20 过大);去掉留派生 ≈12px,与 sidebar 内 s8 节奏一致。
                        _ChromeBar(
                          onCollapse: widget.onToggleLeft,
                          controlInset: controlInset,
                        ),
                        Expanded(
                          child:
                              widget.sidebar ?? const _Placeholder('Sidebar'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Its own repaint layer (S12): an island slide / hover / shadow re-raster never
                // drags the ocean into its repaint, and ocean streaming never repaints the islands
                // (each island's shadow layer re-rasters on animation; without this boundary those
                // dirty regions could union across the shell). 海洋独立重绘层(S12):岛滑动/hover/
                // 阴影重栅不再连坐海洋,海洋流式重绘也不牵岛——无边界时脏区会在壳内并集。
                Expanded(child: RepaintBoundary(child: oceanHost)),
                _RightReveal(
                  open: widget.inspectorOpen,
                  width: widget.rightWidth,
                  maxWidth: rightCeiling,
                  onWidthCommitted: widget.onRightWidthCommitted,
                  onAnimating: (v) => _setAnimating(left: false, value: v),
                  child: widget.inspector ?? const _Placeholder('Inspector'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The left island's top control strip — reserves the macOS traffic-light zone at the leading edge (the OS
/// draws the real lights there), then a spacer, then the collapse button. The control row sits at
/// [controlInset] from the band top so it centers on the OS lights' horizontal line; the band stays
/// [AnSize.islandHead] tall (the sidebar starts below it). 左岛顶栏:行首留红绿灯位 + 间隔 + 收起钮;控件行落在灯线。
class _ChromeBar extends StatelessWidget {
  const _ChromeBar({this.onCollapse, required this.controlInset});
  final VoidCallback? onCollapse;
  final double controlInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AnSize.islandHead,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: controlInset),
          SizedBox(
            height: AnSize.control,
            child: Row(
              children: [
                // The brand lives ONLY on the left island (拍板). This is the one call site that opts in.
                // 品牌只在左岛(拍板)——仅此处打开。
                const AnWindowControls(showBrand: true),
                const Spacer(),
                AnButton.iconOnly(
                  AnIcons.panelLeft,
                  semanticLabel: context.t.shell.collapseSidebar,
                  onPressed: onCollapse,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ocean region = the scrolling content with a FLOATING HEAD overlay (scrim + corner controls) on top.
/// 海洋区 = 滚动正文 + 顶部浮层头(scrim + 角落控件)。
class _OceanRegion extends StatelessWidget {
  const _OceanRegion({
    this.ocean,
    this.head,
    this.headTrailing,
    this.bandNotice,
    required this.showReopen,
    this.onReopen,
    required this.showRightToggle,
    this.onToggleRight,
    this.rightActivity = false,
    required this.controlInset,
    required this.noticeInset,
  });

  final Widget? ocean;
  final Widget? head;
  final Widget? headTrailing;

  /// The chrome-band notice slot (the event capsule) — centered over the head band, hit-test only on
  /// itself, z-above the breadcrumb (covering it for a few seconds is acceptable; it never covers WORK
  /// content). Fed by the app layer (DIP — the kit stays feature-free). 顶带通知槽(事件胶囊):带上居中、
  /// 仅自身可命中、z 在面包屑上(盖路径几秒可接受,绝不盖工作内容);app 层喂入(DIP,套件不沾 feature)。
  final Widget? bandNotice;
  final bool showReopen;
  final VoidCallback? onReopen;
  final bool showRightToggle;
  final VoidCallback? onToggleRight;
  final bool rightActivity;
  final double controlInset;
  final double noticeInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        // Selection region #1 of 2 — the ocean's CONTENT only. Everything else in this Stack (the head
        // band, the scrim, the corner controls) stays outside, so Cmd+A never sweeps chrome into the
        // clipboard. See [AnSelectionRegion] for why the count is two.
        // 二域之一——**只**是海洋的内容。本 Stack 里其余一切(头带、scrim、角控)都在域外,故 Cmd+A 绝不会把
        // chrome 扫进剪贴板。为何恰好两个见 [AnSelectionRegion]。
        Positioned.fill(
          child: AnSelectionRegion(child: ocean ?? const _Placeholder('Ocean')),
        ),
        // Scrim: content fades out behind the head band (island → transparent). Click-through. scrim 渐隐、穿透。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AnSize.islandHead + AnSpace.s12,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.surface, c.surface.withValues(alpha: 0)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Head row: reopen (collapsed-only) + breadcrumb + spacer + panel-right (inspector-only). Banded at
        // [controlInset]/[AnSize.control] so its controls center on the OS lights' line; the empty middle
        // falls through to the scrolling content (no opaque fill). 头行控件落在灯线;空白中段穿透到正文。
        Positioned(
          top: controlInset,
          left: 0,
          right: 0,
          height: AnSize.control,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AnSpace.s12,
              right: AnSpace.s8,
            ),
            child: Row(
              children: [
                // When the sidebar is collapsed the OS traffic lights now float over the ocean's top-left, so
                // reserve their windowed gutter (AnWindowControls, showBrand OFF — the brand belongs to the
                // island only) BEFORE the reopen button: reopen sits AFTER the lights, never under them; in
                // fullscreen (no lights) the zone collapses so reopen rides the edge with no stray brand.
                // 收起后红绿灯压到海洋左上,故 reopen 前留红绿灯横位(AnWindowControls,showBrand 关——品牌只属左岛),
                // reopen 落灯之后、绝不压灯;全屏无灯时整块收零,reopen 贴边、不冒出品牌。
                AnimatedSize(
                  duration: AnMotionPref.reduced(context)
                      ? Duration.zero
                      : AnMotion.mid,
                  alignment: Alignment.centerLeft,
                  child: showReopen
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AnWindowControls(),
                            AnButton.iconOnly(
                              AnIcons.panelLeft,
                              semanticLabel: context.t.shell.expandSidebar,
                              onPressed: onReopen,
                            ),
                            const SizedBox(width: AnSpace.s4),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                // Breadcrumb fills the middle (left-aligned), pushing panel-right to the far edge — a single
                // Expanded, NOT a Flexible+Spacer (those split the slack and float panel-right mid-row).
                // 面包屑占满中间(左对齐),把 panel-right 顶到最右——用单个 Expanded,非 Flexible+Spacer(后者平分余量、把右钮浮到中间)。
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: head ?? const SizedBox.shrink(),
                  ),
                ),
                // Head-trailing action (chat's scene/outline nav) sits just LEFT of the panel-right toggle.
                // 头尾动作(chat 场次/大纲钮)紧靠右岛钮左边。
                ?headTrailing,
                // The panel-right toggle SLIDES IN from the trailing edge the moment it first appears
                // (a chat conversation's first activity landing), pushing [headTrailing] (the Scenes button)
                // LEFT — «挤» is a real位移. Mounting already-open is instant (a switch onto an existing
                // island doesn't re-animate); reduced-motion is instant. The leading gap rides INSIDE the
                // reveal so a collapsed toggle leaves NO stray gap. 位置语法:新成员(toggle)从尾端横向滑入、
                // 旧成员(Scenes)左移;登台即在则即时,reduced 即时;间隙随揭示,收起态不留缝。
                AnExpandReveal(
                  axis: Axis.horizontal,
                  open: showRightToggle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (headTrailing != null)
                        const SizedBox(width: AnSpace.s4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnButton.iconOnly(
                            AnIcons.panelRight,
                            semanticLabel: context.t.shell.togglePanel,
                            onPressed: onToggleRight,
                          ),
                          // R-15 activity bit: live work behind a collapsed island. 收起态活动位。
                          if (rightActivity)
                            Positioned(
                              top: AnSpace.s2,
                              right: AnSpace.s2,
                              child: IgnorePointer(
                                child: Container(
                                  width: AnSize.dot,
                                  height: AnSize.dot,
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Notice capsule layer (band middle, z-top): hit-test falls through everywhere except the
        // capsule itself. 通知胶囊层(带中、z 顶):除胶囊自身外命中穿透。
        if (bandNotice != null)
          Positioned(
            top: noticeInset,
            left: 0,
            right: 0,
            bottom: 0,
            // Top-aligned, UNBOUNDED downward: the shared 36px crown sits on the title-band axis while
            // the approval BLOCK grows only below it. Hit-testing still lands only on the island itself.
            // 顶对齐、向下不设限:共用 36 冠部坐标题带中轴,审批只向下生长;命中仍仅岛屿自身。
            child: Align(alignment: Alignment.topCenter, child: bandNotice),
          ),
      ],
    );
  }
}

/// Animated reveal / hide + drag-resize of the left island. The collapse animates the island width
/// (0↔[width]) + the trailing gap; an [OverflowBox] holds the content at full [width] so it slides rather
/// than reflows, and the slot is clipped only while sliding (open steady state = unclipped so the island
/// shadow shows). The grip (only at full open) drags a LOCAL width and commits on release. reduced-motion →
/// instant. 左岛揭示/收起 + 拖拽调宽;OverflowBox 保满宽(滑入不重排),仅滑动中裁;grip 拖本地宽、松手提交。
class _LeftReveal extends StatefulWidget {
  const _LeftReveal({
    required this.collapsed,
    required this.width,
    required this.child,
    this.onWidthCommitted,
    this.onAnimating,
  });

  final bool collapsed;
  final double width;
  final Widget child;
  final ValueChanged<double>? onWidthCommitted;

  /// Fires true when the reveal/hide slide starts and false when it settles — the shell's ocean
  /// freeze gate (S11). 开合滑动起止通知——壳的海洋冻结闸(S11)。
  final ValueChanged<bool>? onAnimating;

  @override
  State<_LeftReveal> createState() => _LeftRevealState();
}

class _LeftRevealState extends State<_LeftReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late double
  _w; // local width (drag-tracked); committed to the caller on release 本地宽,松手提交
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _w = widget.width;
    _ctl = AnimationController(
      vsync: this,
      duration: AnMotion.slow,
      value: widget.collapsed ? 0 : 1,
    );
    _ctl.addStatusListener(
      (s) => widget.onAnimating?.call(
        s == AnimationStatus.forward || s == AnimationStatus.reverse,
      ),
    );
  }

  @override
  void didUpdateWidget(_LeftReveal old) {
    super.didUpdateWidget(old);
    if (old.collapsed != widget.collapsed) {
      if (AnMotionPref.reduced(context)) {
        _ctl.value = widget.collapsed ? 0 : 1;
      } else {
        widget.collapsed ? _ctl.reverse() : _ctl.forward();
      }
    }
    if (widget.width != old.width && !_dragging) _w = widget.width;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _onDrag(double dx) {
    setState(() {
      _dragging = true;
      _w = (_w + dx).clamp(AnSize.sidebarMin, AnSize.sidebarMax);
    });
  }

  void _onDragEnd() {
    _dragging = false;
    widget.onWidthCommitted?.call(_w);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = _ctl.value;
        // Fully collapsed: take no space, but stay MOUNTED. Returning SizedBox.shrink() here — which is
        // what this did — destroys the island's whole subtree, so re-opening pays a from-scratch inflate
        // plus every provider inside re-subscribing and re-fetching. That is the flicker, and on the right
        // island, which opens and closes on every selection and every auto-reveal, it is the whole of the
        // felt cost. Offstage keeps the subtree and its state while skipping BOTH layout and paint, and it
        // drops out of semantics on its own — so nothing is paid for a closed island beyond the memory it
        // already occupies, and re-opening is a layout, not a rebirth.
        // 全收:不占位,但**保持挂载**。原写法在这里返回 SizedBox.shrink(),那会销毁整棵岛子树,于是重开要付
        // 一次从零 inflate,外加其中每个 provider 重新订阅与取数。这就是那个「闪」;而右岛每次选中、每次自动
        // 揭示都开合一遍,这份代价就是它全部的体感来源。Offstage 保住子树与其状态,同时跳过**布局与绘制**,
        // 且自行退出语义树——于是关着的岛除了本就占的内存不再付任何代价,重开是一次布局、而不是一次重生。
        final fullyOpen = t >= 1.0;
        final island = SizedBox(
          width: _w * t,
          child: ClipRect(
            clipper: fullyOpen ? const _UnclippedRect() : null,
            child: OverflowBox(
              minWidth: _w,
              maxWidth: _w,
              alignment: AlignmentDirectional
                  .centerStart, // content pinned left, reveals rightward 内容钉左
              child: SizedBox(width: _w, child: widget.child),
            ),
          ),
        );
        return Offstage(
          offstage: t == 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              island,
              // Grip + 8px gap: draggable only at full open; just an animating gap while sliding. grip+间距。
              SizedBox(
                width: AnSize.shellGap * t,
                child: fullyOpen
                    ? _Grip(
                        key: const ValueKey('anShellLeftGrip'),
                        onDrag: _onDrag,
                        onDragEnd: _onDragEnd,
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated reveal / hide of the USER-WIDTH right island (slides 0↔width; the width itself is dragged
/// via the gap grip, mirroring the left island — one grip grammar, both edges). The live drag clamps to
/// [maxWidth] (the shell's dynamic ceiling: the ocean's floor wins over a wide island).
/// 右岛揭示/收起(滑 0↔用户宽);宽度经间隙 grip 拖调,镜像左岛——同一套把手文法。拖拽实时钳到动态上限
/// (海洋保底优先)。
class _RightReveal extends StatefulWidget {
  const _RightReveal({
    required this.open,
    required this.width,
    required this.maxWidth,
    required this.child,
    this.onWidthCommitted,
    this.onAnimating,
  });

  /// Slide start/settle notification — the shell's ocean freeze gate (S11). 滑动起止——海洋冻结闸。
  final ValueChanged<bool>? onAnimating;

  final bool open;
  final double width;
  final double maxWidth;
  final Widget child;
  final ValueChanged<double>? onWidthCommitted;

  @override
  State<_RightReveal> createState() => _RightRevealState();
}

class _RightRevealState extends State<_RightReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late double _w; // local width (drag-tracked); committed on release 本地宽,松手提交
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _w = widget.width;
    _ctl = AnimationController(
      vsync: this,
      duration: AnMotion.mid,
      value: widget.open ? 1 : 0,
    );
    _ctl.addStatusListener(
      (s) => widget.onAnimating?.call(
        s == AnimationStatus.forward || s == AnimationStatus.reverse,
      ),
    );
  }

  @override
  void didUpdateWidget(_RightReveal old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      if (AnMotionPref.reduced(context)) {
        _ctl.value = widget.open ? 1 : 0;
      } else {
        widget.open ? _ctl.forward() : _ctl.reverse();
      }
    }
    if (widget.width != old.width && !_dragging) _w = widget.width;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // Trailing-edge grip: dragging LEFT (negative dx) widens. 右缘把手:向左拖=加宽。
  void _onDrag(double dx) {
    setState(() {
      _dragging = true;
      _w = (_w - dx).clamp(AnSize.rightIslandMin, widget.maxWidth);
    });
  }

  void _onDragEnd() {
    _dragging = false;
    widget.onWidthCommitted?.call(_w);
  }

  @override
  Widget build(BuildContext context) {
    // A ceiling that shrank below the resting width (window resize) squeezes honestly. 上限收窄如实挤。
    final w = _w.clamp(AnSize.rightIslandMin, widget.maxWidth);
    // All three layers stay MOUNTED and only their booleans flip. Written the obvious way —
    // `open ? child : ExcludeFocus(...)` — the slot's runtimeType changes on every toggle, so
    // `Widget.canUpdate` says no and the ENTIRE inspector unmounts and re-inflates: in BOTH directions.
    // That is what the user saw as "the right island flickers and stutters while the left one is silky":
    // a heavy subtree torn down and rebuilt on the animation's first frame, its providers re-subscribing
    // and re-fetching (the flicker) while a hundred elements inflate in one frame (the stutter). The left
    // island never wrapped its child conditionally, which is the whole of the asymmetry.
    // 三层恒挂,只翻布尔。按显然的写法(`open ? child : ExcludeFocus(...)`),slot 的 runtimeType 每次切换
    // 都变,`Widget.canUpdate` 判否,于是**整棵 inspector 卸载重挂——开、关两个方向都是**。这正是用户看到的
    // 「左岛丝滑、右岛闪+卡」:动画第一帧里一棵重子树被拆掉重建,其 provider 重新订阅取数(闪),同一帧
    // inflate 上百个 element(卡)。左岛从来没有对 child 做条件包装——这就是全部的不对称。
    final island = AnIsland(
      child: ExcludeFocus(
        excluding: !widget.open,
        child: ExcludeSemantics(
          excluding: !widget.open,
          child: IgnorePointer(
            ignoring: !widget.open,
            // Selection region #2 of 2 — the right island's content. INSIDE the inert layers, so a closed
            // island cannot be selected from either. 二域之二——右岛内容。放在惰化三层**之内**,故收起的岛
            // 两边都选不到。
            child: AnSelectionRegion(child: widget.child),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = _ctl.value;
        // Fully collapsed: take no space, but stay MOUNTED — see the left island's note. This side is where
        // it matters: the right island opens and closes on every selection and every auto-reveal, so a
        // subtree destroyed at t == 0 is a from-scratch inflate plus a provider re-subscribe/re-fetch,
        // several times a minute. 全收:不占位但**保持挂载**——理由见左岛处注释。这一侧才是要害:右岛每次
        // 选中、每次自动揭示都开合一遍,t == 0 时销毁子树就意味着每分钟数次的从零 inflate + provider 重订阅取数。
        final fullyOpen = t >= 1.0;
        final slot = SizedBox(
          width: w * t,
          child: OverflowBox(
            minWidth: w,
            maxWidth: w,
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(width: w, child: island),
          ),
        );
        return Offstage(
          offstage: t == 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The gap doubles as the width grip (mirrors the left island's grammar). 间隙即把手。
              SizedBox(
                width: AnSize.shellGap * t,
                child: fullyOpen && widget.onWidthCommitted != null
                    ? _Grip(
                        key: const ValueKey('anShellRightGrip'),
                        onDrag: _onDrag,
                        onDragEnd: _onDragEnd,
                      )
                    : null,
              ),
              ClipRect(
                clipper: fullyOpen ? const _UnclippedRect() : null,
                child: slot,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A no-op [CustomClipper] — returns an effectively-unbounded rect so a [ClipRect] in the tree clips
/// nothing (lets an island's float shadow paint past its bounds while keeping the widget stable).
/// 不裁切的 clipper:保留 ClipRect 但不裁,放行岛阴影。
class _UnclippedRect extends CustomClipper<Rect> {
  const _UnclippedRect();
  @override
  Rect getClip(Size size) => const Rect.fromLTRB(-1e5, -1e5, 1e5, 1e5);
  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}

/// Skeleton placeholder — a faint centered label so each empty region is identifiable. 骨架占位。
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Text(
        label,
        style: TextStyle(color: c.inkFaint, fontSize: AnSize.iconSm),
      ),
    );
  }
}

/// The drag handle between the left island and the ocean — also serves as the 8px gap. Shows a hairline on
/// hover. 左岛与海洋间的拖拽柄,兼作 8px 间距;悬停现细线。
class _Grip extends StatefulWidget {
  const _Grip({super.key, required this.onDrag, required this.onDragEnd});
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        child: SizedBox(
          width: AnSize.shellGap,
          child: Center(
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : AnMotion.fast,
              width: AnSize.gripLine,
              decoration: BoxDecoration(
                color: c.lineStrong.whenActive(_hover),
                borderRadius: BorderRadius.circular(AnRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
