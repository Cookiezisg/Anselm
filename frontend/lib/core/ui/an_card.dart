import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A surface container — a white island on the canvas. Default is a hairline-bordered card
/// (flat, airy); set [elevated] for a borderless shadowed surface (floating panels).
/// 表面容器——canvas 上的白岛。默认细线描边卡(扁平通透);[elevated] 时改无边柔阴影(浮层)。
class AnCard extends StatelessWidget {
  const AnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AnSpace.s16),
    this.elevated = false,
    this.radius = AnRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: elevated ? null : Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: elevated ? c.shadowIsland : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
