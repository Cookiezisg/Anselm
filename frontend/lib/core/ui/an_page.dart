import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 海洋内容包装 — a scrollable, centered (max 720) content column inside the ocean. Top
/// padding clears the shell's floating header so the big [AnOceanHeader] sits just under it.
/// Pass the shell's [controller] so its compact-title fade tracks this scroll. No background
/// (the ocean reads as the window's white surface).
/// 海洋内容:可滚、居中(最大 720)。顶部留白避开 shell 浮动头,使大页头恰在其下。传 shell 的 [controller]
/// 以驱动紧凑标题淡入。无背景(海洋即窗体白面)。
class AnPage extends StatelessWidget {
  const AnPage({
    super.key,
    required this.child,
    this.controller,
    this.maxWidth = AnSize.content,
    this.padding,
  });

  final Widget child;
  final ScrollController? controller;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        const EdgeInsets.fromLTRB(
          AnSpace.s24,
          AnSize.islandHead + AnSpace.s12, // clear the floating header
          AnSpace.s24,
          AnSpace.s48,
        );
    return Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        padding: pad,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
