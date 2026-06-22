import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A small, restrained loading spinner (ink-muted by default). For inline "busy" states.
/// 克制的小转圈(默认 inkMuted)。用于内联"忙"态。
class AnSpinner extends StatelessWidget {
  const AnSpinner({super.key, this.size = AnSize.icon, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? context.colors.inkMuted,
      ),
    );
  }
}
