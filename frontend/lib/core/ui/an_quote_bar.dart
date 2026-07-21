import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The ONE quote-bar treatment — a quiet left rule ([AnSize.quoteBar] wide, `lineStrong`) + a left inset,
/// the shared «this is quoted / set-aside prose» grammar (a markdown blockquote, a gate's echoed free-text
/// answer). The [child] carries its own muted voice. 唯一引用条:左细条(quoteBar 宽 · lineStrong)+ 左内距,
/// 「引用/旁白」统一文法(markdown 引用、人闸回显自由答复);child 自带静默声。
class AnQuoteBar extends StatelessWidget {
  const AnQuoteBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: AnSpace.s12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: context.colors.lineStrong,
          width: AnSize.quoteBar,
        ),
      ),
    ),
    child: child,
  );
}
