import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_code_surface.dart';

/// A read-only mono text block — [AnCodeSurface] (the shared framed code container) wrapping a standard
/// s8-inset mono [Text]. For plain code/data payloads that don't need the [AnCodeEditor] bar/gutter/copy
/// chrome (run-terminal output, node-debug JSON). [AnCodeSurface] deliberately ships no inner padding, so
/// this padded-mono wrapping was the actually-reusable piece the run terminal and run cockpit each
/// hand-composed. [bare] drops the frame (passes through [AnCodeSurface.bare]).
///
/// 只读 mono 文本块——AnCodeSurface(共享代码框)裹标准 s8 内距的 mono Text。给不需要 AnCodeEditor
/// 栏/行号/复制 chrome 的纯代码/数据(run 终端输出、节点调试 JSON)。AnCodeSurface 刻意不带内距,故这层
/// 「内距 + mono 文本」才是 run 终端与 run 驾驶舱各自手拼的真正可复用件。[bare]=无框透传。
class AnCodeBlock extends StatelessWidget {
  const AnCodeBlock(this.text, {this.bare = false, super.key});

  final String text;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    return AnCodeSurface(
      bare: bare,
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s8),
        child: Text(
          text,
          style: AnText.code.copyWith(color: context.colors.ink),
        ),
      ),
    );
  }
}
