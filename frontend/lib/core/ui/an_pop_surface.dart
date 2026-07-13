import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The ONE floating-popover surface — a white island that lifts off the content beneath it: `surface`
/// fill + `AnRadius.chip` + a hairline `line` border + the `shadowPop` lift. Every transient pop-up
/// chrome (a menu / dropdown panel, the editor's format bar, the link-input bar) is this same box; the
/// caller supplies the inner clip/scroll/padding. Owning it here keeps the lift byte-identical and stops
/// each site re-hand-rolling the `DecoratedBox(BoxDecoration(...))`.
/// 唯一浮层面:白岛浮于内容之上(surface 底 + chip 圆角 + line 发丝边 + shadowPop 抬起)。菜单/下拉/编辑器格式条/
/// 链接输入条同一盒;内部 clip/滚动/内距归调用方。收此处防各站重手搓 DecoratedBox。
class AnPopSurface extends StatelessWidget {
  const AnPopSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.chip),
        border: Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: c.shadowPop,
      ),
      child: child,
    );
  }
}
