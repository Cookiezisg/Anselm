import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// 左岛左下角的 peek — a transient status chip floating at the bottom of the left island
/// (replicating the demo's `.peek`): a pulsing dot + message + "view" + dismiss. Fades in on
/// mount. Use for "a workflow is waiting for approval" style nudges; clicking "view" routes
/// to the relevant surface.
/// 左岛左下角浮条(复刻 demo `.peek`):呼吸点 + 文案 + 查看 + 关闭。挂载即淡入。用于"某流程等待审批"类提示。
class AnPeek extends StatefulWidget {
  const AnPeek({super.key, required this.message, this.onView, this.onDismiss});

  final String message;
  final VoidCallback? onView;
  final VoidCallback? onDismiss;

  @override
  State<AnPeek> createState() => _AnPeekState();
}

class _AnPeekState extends State<AnPeek> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: AnMotion.mid)..forward();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FadeTransition(
      opacity: _ac,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: _ac, curve: AnMotion.easeOut)),
        child: Container(
          height: AnSize.tab,
          padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line, width: AnSize.hairline),
            borderRadius: BorderRadius.circular(AnRadius.chip),
            boxShadow: c.shadowPop,
          ),
          child: Row(
            children: [
              Container(
                width: AnSize.dot,
                height: AnSize.dot,
                decoration: BoxDecoration(color: c.warn, shape: BoxShape.circle),
              ),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onView,
                  child: Text(widget.message,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.meta.copyWith(color: c.ink)),
                ),
              ),
              GestureDetector(
                onTap: widget.onView,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
                  child: Text('View', style: AnText.meta.copyWith(color: c.inkMuted)),
                ),
              ),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
