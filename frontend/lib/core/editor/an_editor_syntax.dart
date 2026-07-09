import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../ui/syntax_highlighter.dart';

/// A super_editor style phase that paints SYNTAX HIGHLIGHT onto fenced code blocks — by adding
/// [ColorAttribution]s to the code node's view-model text (which the editor's inline styler renders),
/// NOT by editing the document (so it never pollutes undo). It runs through the ONE [highlightCode]
/// tokenizer the rest of the product uses (唯一高亮源 铁律).
///
/// Freeze discipline (E0 #1 — custom style phases were the prime suspect for the old rebuild's freeze):
/// the tokenization is MEMOIZED per node on its plain text, so a style pass that isn't a code EDIT
/// (selection moves, caret blink, other-node edits) re-uses the cached token ranges and never re-runs the
/// regex. 语法高亮 style phase:给代码块 vm 文本加 ColorAttribution(内联 styler 渲染)、不改文档(不污染 undo);
/// 走唯一 highlightCode;**分词按节点+文本记忆化**,非代码编辑的样式过不重跑正则(E0 卡死首凶=style phase 每帧重算)。
class AnCodeSyntaxStylePhase extends SingleColumnLayoutStylePhase {
  AnCodeSyntaxStylePhase(this._colors);

  SyntaxColors _colors;

  /// One cache entry per code node: its last plain text + the token ranges computed from it. Bounded to
  /// the number of code blocks (not edits). 每代码节点一条:上次纯文本 + 其分词;界=代码块数。
  final Map<String, ({String plain, List<_Token> tokens})> _cache = {};

  /// Update the palette on a light/dark flip — invalidate the cache + mark dirty so the next pass repaints.
  /// 主题翻转换色:清缓存 + markDirty。
  set colors(SyntaxColors value) {
    if (value == _colors) return;
    _colors = value;
    _cache.clear();
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    final seen = <String>{};
    for (final vm in viewModel.componentViewModels) {
      if (vm is! ParagraphComponentViewModel || vm.blockType != codeAttribution) continue;
      final plain = vm.text.toPlainText();
      final cached = _cache[vm.nodeId];
      final tokens = (cached != null && cached.plain == plain) ? cached.tokens : _tokenize(plain);
      _cache[vm.nodeId] = (plain: plain, tokens: tokens);
      seen.add(vm.nodeId);
      if (tokens.isEmpty) continue;
      // Apply onto a COPY of the vm text (the vm is the pipeline's; we colour our view of it). 着色副本。
      final colored = vm.text.copy();
      for (final t in tokens) {
        colored.addAttribution(ColorAttribution(t.color), SpanRange(t.start, t.end), autoMerge: false);
      }
      vm.text = colored;
    }
    // Prune entries for code nodes that no longer exist — else deleted blocks' tokens linger for the
    // session (the cache is bounded to LIVE code nodes, not every one ever created). 删已消失节点的陈旧条目。
    if (_cache.length > seen.length) _cache.removeWhere((id, _) => !seen.contains(id));
    return viewModel;
  }

  List<_Token> _tokenize(String plain) {
    if (plain.isEmpty) return const [];
    final spans = highlightCode(plain, colors: _colors);
    final tokens = <_Token>[];
    var offset = 0;
    for (final span in spans) {
      final text = span.text ?? '';
      final color = span.style?.color;
      // Only the COLOURED runs become attributions; plain runs inherit the ambient code ink. 只着色段。
      if (color != null && text.isNotEmpty) tokens.add(_Token(offset, offset + text.length - 1, color));
      offset += text.length;
    }
    return tokens;
  }
}

/// A single coloured token range (inclusive end, matching [SpanRange]). 一个着色段(含端)。
class _Token {
  const _Token(this.start, this.end, this.color);
  final int start;
  final int end;
  final Color color;
}
