import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// The kit's single collapse / expand reveal: a controller-driven [ClipRect] + [Align] size-factor tween
/// (the ExpansionTile idiom) that grows downward — or, with [axis] horizontal, out of the start edge —
/// and is gated to instant under reduced motion.
/// [AnRowDetail]'s detail panel and [AnSidebarList]'s group / type / branch children both route through it
/// so the disclosure motion is byte-identical kit-wide (not re-rolled per site — #8).
///
/// NOT [AnimatedSize]: AnimatedSize re-dirties itself during its own performLayout when the child resizes,
/// which ASSERTS when reveals are NESTED (a group containing a type containing a branch — the sidebar's
/// shape). ClipRect + Align(heightFactor) driven by an explicit controller has no such re-dirty, so it nests
/// safely. [child] shows when [open], else it collapses to zero height AND is removed from the tree once fully
/// closed (so collapsed rows aren't focusable / screen-reader-announced). Pass [duration] = `Duration.zero`
/// to force-skip the tween (e.g. a filter query is driving the open state — per-keystroke tweens are janky).
///
/// 套件统一折叠/展开揭示:控制器驱动的 ClipRect + Align(heightFactor)(ExpansionTile 习语),仅向下,reduced 即时。
/// **非 AnimatedSize**(后者在嵌套时会 performLayout 内自脏断言——sidebar 是嵌套树);ClipRect+Align 可安全嵌套。
/// open 显 child,否则补间到 0 高、全收后从树移除(收起的行不可聚焦/不被屏读)。duration=Duration.zero 强制即时。
class AnExpandReveal extends StatefulWidget {
  const AnExpandReveal({
    required this.open,
    required Widget this.child,
    this.duration,
    this.axis = Axis.vertical,
    this.keepMounted = false,
    super.key,
  }) : childBuilder = null;

  /// LAZY reveal (C-006): the child is built ONLY while open / animating — a fully-collapsed row never
  /// evaluates [childBuilder]. Use this when the child is EXPENSIVE to build (a tool-card family body runs
  /// jsonDecode / regex / arg extraction every build); the eager [child] form would pay that cost each
  /// parent rebuild even while collapsed (during streaming: N collapsed cards × per frame). 惰性揭示:收起
  /// 态绝不调 builder,贵的体(族体 jsonDecode/正则/取参)收起时零成本。
  const AnExpandReveal.builder({
    required this.open,
    required WidgetBuilder this.childBuilder,
    this.duration,
    this.axis = Axis.vertical,
    super.key,
  }) : child = null,
       keepMounted = false; // lazy + keepMounted是矛盾的:前者要收起零成本,后者要收起仍活

  final bool open;

  /// Reveal axis: vertical grows downward (the disclosure default); horizontal grows from the start
  /// edge (an inline control sliding out — the pager's ↵ confirmer, 0718 首用). Same tween, same
  /// reduced gating, same removed-when-closed hygiene on both axes.
  /// 揭示轴:纵=向下(披露默认);横=自起始缘长出(行内控件滑出,翻页器 ↵ 首用)。同补间/同 reduced/
  /// 同「全收即出树」卫生。
  final Axis axis;

  /// The eager child (built by the caller before this widget). Null on the [AnExpandReveal.builder] form.
  /// 急切子件(调用方先建);builder 形为 null。
  final Widget? child;

  /// The lazy child builder — called only when the child is needed. Null on the default form. 惰性子件建造器。
  final WidgetBuilder? childBuilder;

  /// Override the reveal duration. `Duration.zero` → instant (e.g. filter-forced open). Default = [AnMotion.mid]
  /// (→ instant under reduced motion). 覆写时长,zero=即时(如过滤强制展开),默认 mid(reduced 即时)。
  final Duration? duration;

  /// Keep the subtree MOUNTED while collapsed (default false = dropped once fully closed). For a body that
  /// owns live state the collapse must not destroy — a form with a debounced autosave + edit buffers, whose
  /// source provider is deliberately not refetched mid-edit, so an unmount would drop a pending save and
  /// stale-remount. The reveal still animates; at zero height the subtree is made inert (no hit-test, no
  /// semantics, no focus) so a collapsed body is as invisible to a screen reader / Tab as the dropped form.
  ///
  /// 收起仍保持子树挂载(默认 false=全收即出树)。给「收起不可摧毁其状态」的体用——持防抖 autosave + 编辑缓冲、
  /// 源 provider 刻意不中途 refetch 的表单,卸载会丢在途保存并陈旧重挂。动画照旧;零高时子树惰化(不命中/无语义/
  /// 不可聚焦),对屏读与 Tab 而言与「已出树」等价。
  final bool keepMounted;

  @override
  State<AnExpandReveal> createState() => _AnExpandRevealState();
}

class _AnExpandRevealState extends State<AnExpandReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final CurvedAnimation
  _factor; // CurvedAnimation (not Animation) so it can be disposed 须具体类型以便 dispose

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: AnMotion.mid,
      value: widget.open ? 1 : 0,
    );
    _factor = CurvedAnimation(parent: _ctl, curve: AnMotion.easeOut);
  }

  @override
  void didUpdateWidget(AnExpandReveal old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      // instant when reduced motion OR the caller forces it (filter-driven open) 即时:reduced 或调用方强制
      if (widget.duration == Duration.zero || AnMotionPref.reduced(context)) {
        _ctl.value = widget.open ? 1 : 0;
      } else {
        _ctl.duration = widget.duration ?? AnMotion.mid;
        widget.open ? _ctl.forward() : _ctl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _factor
        .dispose(); // before the parent controller (CurvedAnimation owns a parent listener) 先于父控制器
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fully collapsed AND settled → take no space, drop the subtree, and (the lazy form) NEVER build the
    // child. This short-circuit runs on every parent rebuild, so a collapsed expensive body pays nothing
    // during streaming (C-006). [keepMounted] opts OUT: its subtree must survive the collapse.
    // 全收静止:不占位、移出树、惰性形绝不建体——收起态每次父重建零成本。keepMounted 豁免(子树须活过折叠)。
    if (_ctl.value == 0 && !widget.open && !widget.keepMounted) {
      return const SizedBox.shrink();
    }
    // Built once here (not per animation frame — it rides AnimatedBuilder's `child`). 建一次,非逐帧。
    final child = widget.childBuilder?.call(context) ?? widget.child!;
    return AnimatedBuilder(
      animation: _factor,
      child: child,
      builder: (context, child) {
        if (_ctl.value == 0 && !widget.open && !widget.keepMounted) {
          return const SizedBox.shrink();
        }
        final f = _factor.value.clamp(0.0, 1.0);
        final horizontal = widget.axis == Axis.horizontal;
        // At zero extent a KEPT-MOUNTED subtree must read as absent: no hit-test, no semantics, no focus
        // stop. The wrapper chain is UNCONDITIONAL (only the flags flip) so the element tree — and thus the
        // child's State — is never re-parented. 零延展时保挂的子树须「读作不存在」;包裹链恒在、只翻标志位,
        // 故元素树不重挂(State 不丢)。
        final inert = f == 0;
        return ClipRect(
          child: Align(
            // vertical grows downward only; horizontal grows from the start edge. 纵仅向下;横自起始缘。
            alignment: horizontal
                ? AlignmentDirectional.centerStart
                : Alignment.topCenter,
            heightFactor: horizontal ? null : f,
            widthFactor: horizontal ? f : null,
            child: ExcludeFocus(
              excluding: inert,
              child: ExcludeSemantics(
                excluding: inert,
                child: IgnorePointer(ignoring: inert, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
