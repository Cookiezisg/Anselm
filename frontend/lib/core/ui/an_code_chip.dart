import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The inline-code chip — mono text on a padded, rounded [AnColors.surfaceSunken] pill. This is the ONE
/// truth for how `inline code` looks, shared by BOTH the chat renderer ([AnMarkdown]) and the document
/// editor's rest-state chip (the A′ focus-swap): the editor wraps this exact widget in a super_editor inline
/// placeholder so a document code chip is pixel-identical to a chat code chip — not a re-implementation that
/// can drift. `TextStyle.backgroundColor` can only paint a tight rectangle (no padding, no radius), so the
/// padded/rounded look is only achievable with a real widget like this — which is why the editor renders it
/// as an atomic placeholder at rest and swaps to editable text (rectangular styler) only while being edited.
/// 行内代码芯片:mono + padded 圆角 surfaceSunken 胶囊——`inline code` 外观的唯一真相,chat([AnMarkdown])与文档
/// 编辑器静置态(A′ 焦点换态)共用同一 widget,故文档代码芯片与 chat 逐像素一致、绝不各自实现漂移。TextStyle 背景只能
/// 画紧贴矩形(无内距/圆角),圆角胶囊只有真 widget 能画——所以编辑器静置渲此原子芯片、仅编辑时换成可编辑文本。
class AnCodeChip extends StatelessWidget {
  const AnCodeChip(this.code, {this.dense = false, super.key});

  final String code;

  /// DENSE (embedded scale) → the 12 [AnText.codeInline] face, a rung under the DEFAULT mono 13. The default
  /// is load-bearing: the document editor's rest-state chip AND the chat READING chip both use it, so they
  /// stay pixel-identical — only markdown living in an embedded window (tool cards / stages, the
  /// `AnMarkdownScale.embedded` scale) asks for the smaller rung. 密排(嵌入档)=12 小码档,默认仍 mono 13(编辑器静置 chip 与 chat 阅读 chip 逐像素一致)。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Text(code, style: (dense ? AnText.codeInline : AnText.mono).copyWith(color: c.ink)),
    );
  }
}
