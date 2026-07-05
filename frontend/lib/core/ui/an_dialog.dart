import 'dart:math' as math;

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'icons.dart';

/// F4 — the modal confirm dialog (WRK-041 G6.1). A full-screen BLOCKING overlay: a centred island
/// card over a scrim, with a focus trap, focus return, Escape-to-dismiss, and barrier-tap dismiss —
/// all of which the framework's [RawDialogRoute] gives for free (verified against the 3.41.9 SDK
/// source). The one thing it does NOT give is the route NAME — [RawDialogRoute.buildPage] sets
/// scopesRoute + explicitChildNodes but no namesRoute/label, so the card supplies `Semantics(namesRoute:
/// true, label: title)` itself (mirroring Material's AlertDialog) or a screen reader entering the modal
/// announces nothing. We DON'T use [showDialog]/[showGeneralDialog]: showDialog forces Material's canned
/// transition + SafeArea + a black54 barrier + needs the caller's context; building the route
/// directly lets us supply our own scrim barrier + spring transition AND hold the [Route] handle for
/// single-instance governance (the controller pops a stale dialog before pushing). The one gotcha a
/// direct construction must NOT forget: [TraversalEdgeBehavior.closedLoop] is NOT defaulted here (only
/// showDialog defaults it), so we pass it explicitly or Tab escapes the modal.
///
/// v1 = [anConfirmRoute] only (a confirm-delete: title + optional message + cancel/confirm). A
/// rich-content `openDialog(builder)` is deferred (WRK-041 §5) — every demo dialog is a confirm. The
/// card is inlined here (single consumer, YAGNI); an `AnModalCard` abstraction waits for a 2nd island
/// card (NOT named AnIslandCard — avoids colliding with the existing chip-tier [AnIsland]).
///
/// F4——模态确认框。全屏阻断:scrim 上居中岛卡,焦点陷阱/归还/Escape 关/点遮罩关**由框架 RawDialogRoute 白送**
/// (已核 3.41.9 源);**唯路由命名(namesRoute/label)不白送**(buildPage 仅给 scopesRoute+explicitChildNodes),故卡自补
/// `Semantics(namesRoute:true,label:title)`(仿 AlertDialog),否则屏读进 modal 无播报。不用 showDialog(强制 Material 转场/SafeArea/black54/需 caller context);自建路由换 scrim 遮罩
/// + spring 转场,且拿 Route 句柄做单实例(controller 先 pop 旧的)。直接构造**必须显式传 closedLoop**(showDialog 才默认),
/// 否则 Tab 逃出 modal。v1 仅 confirm-delete;富内容口推迟;卡内联(单消费者,YAGNI)。
enum AnDialogTone { primary, danger }

/// Build the confirm-dialog route. [scrim] + [reduced] are read once at construction (route-level,
/// pre-build); the card reads [AnColors] itself so it stays theme-reactive. The controller pushes
/// this on the root navigator and maps a null pop result (barrier/Escape) to `false`.
/// 构建确认框路由。scrim/reduced 构造期一次性读(路由级);卡自读色保主题响应。controller push 到 root navigator,
/// barrier/Escape 的 null 结果映射为 false。
RawDialogRoute<bool> anConfirmRoute({
  required Color scrim,
  required bool reduced,
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  required String barrierLabel,
  AnDialogTone confirmTone = AnDialogTone.danger,
}) {
  return RawDialogRoute<bool>(
    barrierColor: scrim,
    barrierDismissible:
        true, // tap-barrier + Escape both pop(null) → false 点遮罩 + Escape 均 pop(null)→false
    barrierLabel:
        barrierLabel, // required when dismissible (framework assert) 可关时框架 assert 必非空
    transitionDuration: reduced
        ? Duration.zero
        : AnMotion.mid, // reverse getter falls back to this 进退同源
    traversalEdgeBehavior: TraversalEdgeBehavior
        .closedLoop, // NOT defaulted on direct construction 直接构造不默认
    pageBuilder: (context, animation, secondary) => _AnConfirmCard(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmTone: confirmTone,
    ),
    transitionBuilder: (context, animation, secondary, child) {
      if (reduced) return child;
      // drive(CurveTween) — NOT CurvedAnimation (which must be disposed; inline-created it leaks). 用 drive 不用 CurvedAnimation。
      final curved = animation.drive(CurveTween(curve: AnMotion.spring));
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, (1 - curved.value) * AnSpace.s8),
            child: Transform.scale(
              scale: 0.98 + 0.02 * curved.value,
              child: child,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

class _AnConfirmCard extends StatelessWidget {
  const _AnConfirmCard({
    required this.title,
    this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmTone,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final AnDialogTone confirmTone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.sizeOf(context);
    // demo .an-dialog: width 100% capped at --w-content, inset by the mask's --sp-6 each side;
    // max-height 100vh − --sp-12. **clamp ≥0**: a sub-48 viewport (capture harness / tiny embed)
    // would otherwise feed a NEGATIVE BoxConstraint → RenderConstrainedBox assert (demo's CSS calc()
    // floors at 0, Flutter doesn't). 宽上限 720(两侧 s24)/ 高 vh−s48,均 clamp ≥0 防极小视口负约束断言。
    final w = math
        .min(AnSize.content, mq.width - AnSpace.s24 * 2)
        .clamp(0.0, double.infinity);
    final maxH = (mq.height - AnSpace.s48).clamp(0.0, double.infinity);

    // namesRoute + label — NOT free: RawDialogRoute.buildPage gives scopesRoute + explicitChildNodes
    // but no route NAME, so a screen reader entering the modal wouldn't announce "dialog, <title>" (a
    // real regression vs Material's AlertDialog, which names the route off its title). We supply it
    // here, mirroring AlertDialog. (The demo's dialog.js sets role=dialog but no aria-labelledby either
    // — this is a framework best-practice fix, not demo fidelity.) 路由命名须自补(RawDialogRoute 不白送)。
    return Semantics(
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: Center(
        child: SizedBox(
          width: w,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AnRadius.island),
                border: Border.all(color: c.line, width: AnSize.hairline),
                boxShadow: c.shadowWin,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AnRadius.island),
                // Material(transparency): the card lives in a RawDialogRoute, outside any Scaffold —
                // without a Material ancestor its text paints the debug yellow underline. 须 Material 祖先免黄线。
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _head(context, c),
                      if (message != null) Flexible(child: _body(context, c)),
                      _foot(context, c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _head(BuildContext context, AnColors c) {
    return Container(
      height: AnSize.islandHead,
      padding: const EdgeInsets.fromLTRB(AnSpace.s16, 0, AnSpace.s8, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: AnSize.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.strong.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton.iconOnly(
            AnIcons.close,
            semanticLabel: context.t.feedback.dismiss,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AnColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AnSpace.s16),
      child: Text(
        message!,
        style: AnText.body.copyWith(color: c.inkMuted),
      ), // chrome body 13/1.4 — dialogs are operational copy, not prose 对话框=操作文案、非 prose
    );
  }

  Widget _foot(BuildContext context, AnColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AnSpace.s16,
        AnSpace.s12,
        AnSpace.s16,
        AnSpace.s12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: AnSize.hairline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Autofocus the SAFE choice (cancel) so Enter never fires a destructive confirm; Tab reaches
          // the danger button. The trap needs an initial anchor too. 自动聚焦安全项(取消),Enter 不误删;Tab 可达危险钮。
          AnButton(
            label: cancelLabel,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: confirmLabel,
            variant: confirmTone == AnDialogTone.danger
                ? AnButtonVariant.danger
                : AnButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
