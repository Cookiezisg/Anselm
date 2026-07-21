import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A [MouseRegion] that FREEZES its hover transitions while the nearest ancestor [Scrollable] is in
/// motion, then applies the final resting hover once the scroller settles (0718 滚动闪烁审定).
///
/// **Why this exists (a real bug the probe caught, not a theoretical nicety)**: during an overscroll
/// rubber-band the content moves UNDER a stationary cursor, so a plain [MouseRegion] fires enter/exit
/// as rows slide past. When the hovered row answers that by SWAPPING a child widget (a status dot →
/// a spinner, or the disclosure chevron appearing) — a relayout, not just a repaint — the relayout
/// feeds the in-flight trackpad drag a REVERSE delta (`applyUserOffset` runs against the moving
/// content), the overscroll clamps back to 0, the content springs back, the cursor is over a new row,
/// hover flips again — a self-sustaining flicker. Freezing hover while scrolling removes the trigger
/// (the cursor is not moving; only the content is, and the user did not "hover" anything new) — the
/// same law editor gutters and browser lists follow — and as a bonus skips every hover rebuild during
/// a scroll. press / tap / focus are NOT frozen, only hover.
///
/// 滚动进行中冻结 hover 迁移的 MouseRegion 替身,滚停后一次性落定光标下的最终 hover 态(0718 审定)。
/// 病根(探针实证、非空谈):overscroll 橡皮筋里内容在静止光标下移动 → 普通 MouseRegion 随行掠过发
/// enter/exit;悬停行以**换件**(状态点→转圈 / 披露箭头现身,relayout 而非 repaint)回应,relayout 把
/// 进行中的 trackpad drag 喂回**反向**增量(applyUserOffset 撞上移动的内容)→ overscroll 掐回 0 → 内容
/// 弹回 → 光标落到新行 → hover 又翻 → 自激闪烁。滚动中冻 hover 拔掉触发条件(光标没动、用户没「悬停」
/// 任何新东西)——编辑器行号沟、浏览器列表同律——顺带省掉滚动中每次 hover 重建。press/tap/focus 不冻,只冻 hover。
class AnHoverRegion extends StatefulWidget {
  const AnHoverRegion({
    required this.child,
    this.onEnter,
    this.onExit,
    this.cursor = MouseCursor.defer,
    super.key,
  });

  /// Enter callback — signature-identical to [MouseRegion.onEnter]. Deferred while scrolling. 进入回调。
  final void Function(PointerEnterEvent)? onEnter;

  /// Exit callback — signature-identical to [MouseRegion.onExit]. Deferred while scrolling. 退出回调。
  final void Function(PointerExitEvent)? onExit;

  /// Cursor passthrough (defaults to [MouseCursor.defer], i.e. no override). 光标透传。
  final MouseCursor cursor;

  final Widget child;

  @override
  State<AnHoverRegion> createState() => _AnHoverRegionState();
}

class _AnHoverRegionState extends State<AnHoverRegion>
    with ScrollSilencedHoverMixin<AnHoverRegion> {
  // The LAST deferred transition while scrolling — enter (with its event) OR exit (with its event),
  // never both; whichever fired last wins, so the flush lands on the cursor's true resting state.
  // 滚动中最后一次被缓存的迁移:enter 或 exit 二选一(后来者覆盖),故 flush 落在光标真正的停歇态。
  PointerEnterEvent? _pendingEnter;
  PointerExitEvent? _pendingExit;

  void _handleEnter(PointerEnterEvent e) {
    if (hoverScrollActive) {
      _pendingEnter = e;
      _pendingExit = null;
      return;
    }
    widget.onEnter?.call(e);
  }

  void _handleExit(PointerExitEvent e) {
    if (hoverScrollActive) {
      _pendingExit = e;
      _pendingEnter = null;
      return;
    }
    widget.onExit?.call(e);
  }

  @override
  void onHoverScrollSettled() {
    final enter = _pendingEnter;
    final exit = _pendingExit;
    _pendingEnter = null;
    _pendingExit = null;
    if (enter != null) {
      widget.onEnter?.call(enter);
    } else if (exit != null) {
      widget.onExit?.call(exit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      // Wire a handler ONLY when the caller wants that edge — a null onEnter keeps a plain
      // MouseRegion's non-annotated semantics. 仅在调用方要该边沿时接线,保普通 MouseRegion 语义。
      onEnter: widget.onEnter == null ? null : _handleEnter,
      onExit: widget.onExit == null ? null : _handleExit,
      child: widget.child,
    );
  }
}

/// Kit-internal plumbing shared by [AnHoverRegion] and [AnInteractive] (never spread further) — tracks
/// the nearest ancestor [Scrollable]'s scroll activity and calls [onHoverScrollSettled] when it stops,
/// so a host can DEFER hover transitions while scrolling and flush the final one on settle. See
/// [AnHoverRegion] for the full why. Two hosts, one mechanism — never copy-paste the listen/rebind/
/// unbind dance.
///
/// [AnHoverRegion] 与 [AnInteractive] 共用的套件内部管线(不外扩):跟踪最近祖先 Scrollable 的滚动态、
/// 滚停时调 [onHoverScrollSettled],让宿主滚动中缓存 hover、滚停 flush。两宿主一机制,绝不复制粘贴两份。
mixin ScrollSilencedHoverMixin<T extends StatefulWidget> on State<T> {
  ScrollPosition? _hoverScrollPos;

  /// True while the nearest ancestor scroller (drag OR ballistic settle) is in motion. 最近祖先在滚。
  bool get hoverScrollActive =>
      _hoverScrollPos?.isScrollingNotifier.value ?? false;

  /// Called on the settling edge (isScrolling true → false) — flush the deferred hover HERE (a
  /// listener callback, never a build), so a host [setState] is safe. 滚停边沿回调,可安全 setState。
  void onHoverScrollSettled();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The nearest scroller's ScrollPosition can be REPLACED (a swapped controller, a re-parented
    // Scrollable) — [Scrollable.maybeOf] registers the dependency, so this re-runs and re-binds.
    // 最近滚动器的 position 可能换实例(换控制器/重挂 Scrollable)——maybeOf 建依赖,故此处重跑重挂。
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _hoverScrollPos)) return;
    _hoverScrollPos?.isScrollingNotifier.removeListener(_onHoverScrollActivity);
    _hoverScrollPos = next;
    _hoverScrollPos?.isScrollingNotifier.addListener(_onHoverScrollActivity);
  }

  void _onHoverScrollActivity() {
    // Only the settling edge matters; the start edge is handled by [hoverScrollActive] at read time.
    // 只关心滚停边沿;起滚边沿由读取时的 hoverScrollActive 兜住。
    if (!(_hoverScrollPos?.isScrollingNotifier.value ?? false)) {
      onHoverScrollSettled();
    }
  }

  @override
  void dispose() {
    _hoverScrollPos?.isScrollingNotifier.removeListener(_onHoverScrollActivity);
    super.dispose();
  }
}
