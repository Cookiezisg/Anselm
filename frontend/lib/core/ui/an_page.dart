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
/// ## The reading column is absolute — wide content scrolls INSIDE itself (用户 0717)
///
/// There is **no width exemption and no full-bleed escape hatch**. Every ocean page — prose, ledger,
/// gantt, graph, matrix alike — lives in the 720 column. Content whose information is genuinely wider
/// than 720 **owns a horizontal scroller of its own** ([AnRunMatrix], [AnCodeEditor], [AnVersionDiff]
/// are the three; [AnGraphCanvas] pans/zooms instead) and never asks the page for more room. The page
/// body is a single-axis vertical [SingleChildScrollView] — it CANNOT scroll sideways, which is what
/// makes «the body never scrolls horizontally» structural rather than a promise.
///
/// This retires WRK-069 判决③'s `AnZonedPage`/`AnPageZone(fullBleed:)` (deleted): the user rejected the
/// full-bleed panes on sight — 「我不允许有这种超宽的东西。请都改回到标准的。如果甘特图真的信息不够展示,
/// 可以弄那种可以左右滑动的」.
///
/// D3——海洋记录页脚手架:唯一滚动区 + 居中 720 内容列 + **overlay 滚动条**(框架 RawScrollbar,非 demo 手搓 rAF thumb
/// + 700ms idle-hide;#8)。顶 pad 让出浮动头(islandHead + s12),大标题坐头栏之下不被切。overlay thumb 不占 gutter、
/// 内容列宽不抖。传 controller 驱动 scrollToBottom / 读 offset(海洋头折叠联动下游读它,推迟),否则 AnPage 自管。
///
/// **阅读列是绝对的——宽内容在自己肚子里横滚**(用户 0717 判决):**无宽度豁免、无全宽逃生口**。全部海洋页
/// ——散文/台账/甘特/图/矩阵一视同仁——都住 720 列。信息真比 720 宽的东西**自带横向滚动器**(全 App 恰三件:
/// AnRunMatrix / AnCodeEditor / AnVersionDiff;AnGraphCanvas 改为平移缩放),绝不向页面讨宽度。页体是**单轴**
/// 纵向 SingleChildScrollView——它**做不到**横滚,故「body 永不横滚」是**结构性**的而非一句承诺。
/// 此律作废 WRK-069 判决③ 的 `AnZonedPage`/`AnPageZone(fullBleed:)`(已物理删除):用户当面否决全宽格。
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

