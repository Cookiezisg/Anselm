import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_scroll_behavior.dart';

/// D3 — an ocean record-page scaffold: ONE scroll region with a centered [AnSize.content] (720) column and
/// an OVERLAY scrollbar (framework [RawScrollbar] — not the demo's hand-rolled rAF thumb math + 700ms
/// idle-hide; #8). The top padding clears the floating ocean head ([AnSize.islandHead] + [AnSpace.s12]) so a
/// big header sits below the head band, not clipped. The overlay thumb takes no gutter, so the content
/// column width never jitters when it appears. Pass a [controller] to drive [scrollToBottom] / read the
/// offset (the deferred ocean-head collapse linkage reads it downstream); else AnPage owns one.
///
/// D3——海洋记录页脚手架:唯一滚动区 + 居中 720 内容列 + **overlay 滚动条**(框架 RawScrollbar,非 demo 手搓 rAF thumb
/// + 700ms idle-hide;#8)。顶 pad 让出浮动头(islandHead + s12),大标题坐头栏之下不被切。overlay thumb 不占 gutter、
/// 内容列宽不抖。传 controller 驱动 scrollToBottom / 读 offset(海洋头折叠联动下游读它,推迟),否则 AnPage 自管。
class AnPage extends StatefulWidget {
  const AnPage({required this.child, this.controller, super.key});

  /// Page content (header / tabs / sections all go here). 页内容。
  final Widget child;

  /// Optional external scroll controller (chat scroll-to-bottom; collapse-hook offset). 外部滚动控制器。
  final ScrollController? controller;

  @override
  State<AnPage> createState() => AnPageState();
}

class AnPageState extends State<AnPage> {
  ScrollController? _own;
  ScrollController get _ctl => widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// Jump / animate to the bottom (chat streaming bottom-stick, new-turn append). 滚到底。
  void scrollToBottom({bool smooth = false}) {
    if (!_ctl.hasClients) return;
    final to = _ctl.position.maxScrollExtent;
    smooth ? _ctl.animateTo(to, duration: AnMotion.mid, curve: AnMotion.easeOut) : _ctl.jumpTo(to);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RawScrollbar(
      controller: _ctl,
      thumbColor: c.lineStrong,
      radius: const Radius.circular(AnRadius.pill),
      thickness: AnSpace.s4,
      minThumbLength: AnSize.controlSm,
      // Suppress the inherited platform Scrollbar (MaterialScrollBehavior wraps EVERY desktop vertical
      // scrollable in one) so only THIS RawScrollbar paints — else desktop shows two thumbs. Applied
      // LOCALLY (the bar belongs to RawScrollbar, which sits outside this config). 抑制继承的平台滚动条,只留本 RawScrollbar(局部)。
      child: ScrollConfiguration(
        behavior: const AnScrollBehavior(),
        child: SingleChildScrollView(
          controller: _ctl,
          // Centered content column (max 720; centers when the ocean is wider), top pad clears the head band.
          // 居中 720 列,顶 pad 让出头栏。
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AnSize.content),
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AnSize.islandHead + AnSpace.s12,
                  left: AnInset.pageX,
                  right: AnInset.pageX,
                  bottom: AnInset.pageBottom,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One zone of an [AnZonedPage]. Prose zones sit in the same centered [AnSize.content] (720) column
/// as [AnPage]'s body; a [fullBleed] zone spans the whole ocean width (minus the page inset) — the
/// registered width exemption (WRK-069 判决③): time-axis / gantt / matrix density is horizontal, so
/// 720 truncation hurts readability, while every prose zone stays 720.
///
/// AnZonedPage 的一个区。散文区照 AnPage 居中 720 列;fullBleed 区占满海洋宽(留页 inset)——已登记的
/// 宽度豁免(判决③):时间轴/甘特/矩阵信息密度天然横向,720 截断伤可读性;散文区仍守 720。
class AnPageZone {
  const AnPageZone(this.child, {this.fullBleed = false});

  final Widget child;
  final bool fullBleed;
}

/// The zoned record-page scaffold — the SAME chrome as [AnPage] (one scroll region, overlay
/// scrollbar, head-clearing top pad), but the body is a zone list where an individual zone may break
/// out of the 720 reading column ([AnPageZone.fullBleed]). Vertical rhythm between zones belongs to
/// the zones' own content (same as AnPage's single child).
///
/// 分区记录页脚手架——chrome 与 AnPage 完全同款(唯一滚动区+overlay 滚动条+头净空 pad),但页体是区列表,
/// 单个区可破 720 阅读列(fullBleed)。区间纵向节奏归区内容自持(与 AnPage 单 child 同约)。
class AnZonedPage extends StatefulWidget {
  const AnZonedPage({required this.zones, this.controller, super.key});

  final List<AnPageZone> zones;

  /// Optional external scroll controller (the ocean-head collapse linkage reads its offset).
  /// 外部滚动控制器(浮层头折叠联动读 offset)。
  final ScrollController? controller;

  @override
  State<AnZonedPage> createState() => _AnZonedPageState();
}

class _AnZonedPageState extends State<AnZonedPage> {
  ScrollController? _own;
  ScrollController get _ctl => widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RawScrollbar(
      controller: _ctl,
      thumbColor: c.lineStrong,
      radius: const Radius.circular(AnRadius.pill),
      thickness: AnSpace.s4,
      minThumbLength: AnSize.controlSm,
      child: ScrollConfiguration(
        behavior: const AnScrollBehavior(),
        child: SingleChildScrollView(
          controller: _ctl,
          child: Padding(
            // Top/bottom page pads live on the whole zone stack; the horizontal inset is per-zone
            // (prose zones carry it INSIDE the 720 box, exactly AnPage's geometry). 页上下 pad 归整栈;
            // 横向 inset 逐区(散文区在 720 盒内带,与 AnPage 几何逐像素同款)。
            padding: const EdgeInsets.only(
              top: AnSize.islandHead + AnSpace.s12,
              bottom: AnInset.pageBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final z in widget.zones)
                  if (z.fullBleed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AnInset.pageX),
                      child: z.child,
                    )
                  else
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: AnSize.content),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AnInset.pageX),
                          child: z.child,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
