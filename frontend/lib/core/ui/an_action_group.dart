import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// D7 — a button group with unified spacing / alignment, so pages never hand-place buttons. The
/// structure welds alignment + gap; assembly only decides which actions and which way they hug.
/// [end] right-aligns · [compact] tightens the gap · [block] fills width · [stack] goes vertical ·
/// [footer] sits as a content-bottom action area (top margin + full width). Wraps instead of
/// overflowing when the row is too narrow.
///
/// D7——统一间距/对齐的按钮组,页面不再手摆钮。end 右对齐 · compact 紧间距 · block 占满 · stack 竖排 ·
/// footer 内容底部动作区(上间距 + 占满)。过窄时换行而非溢出。
class AnActionGroup extends StatelessWidget {
  const AnActionGroup(
    this.children, {
    this.end = false,
    this.compact = false,
    this.block = false,
    this.stack = false,
    this.footer = false,
    super.key,
  });

  final List<Widget> children;
  final bool end;
  final bool compact;
  final bool block;
  final bool stack;
  final bool footer;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? AnSpace.s4 : AnSpace.s8;

    Widget content;
    if (stack) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: children,
      );
    } else {
      content = Wrap(
        spacing: gap,
        runSpacing: gap,
        alignment: end ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    // end / block / footer / stack all need a bounded width to align or stretch within.
    // end/block/footer/stack 都需占满宽以在内对齐或拉伸。
    if (end || block || footer || stack) {
      content = SizedBox(width: double.infinity, child: content);
    }
    if (footer) {
      content = Padding(padding: const EdgeInsets.only(top: AnGap.block), child: content); // content → footer actions (12, was 16) 内容→底部动作
    }
    return content;
  }
}
