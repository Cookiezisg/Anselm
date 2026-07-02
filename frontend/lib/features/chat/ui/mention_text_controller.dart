import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';

/// A [TextEditingController] that paints known `@name` tokens as accent "pseudo pills" — the plain-
/// TextField folk approach (a real atomic pill needs a rich editor; buildTextSpan tinting + the host's
/// atomic-backspace interception is the established Flutter idiom). While an IME composition is open it
/// falls back to the default span (never fight the underline). Only names in [pillNames] tint, and only
/// at token boundaries (start-of-line/whitespace before, whitespace/end after) — a coincidental
/// substring stays plain.
///
/// 把已知 `@name` 染成 accent「伪药丸」的 controller——纯 TextField 阵营的成熟做法(真原子药丸需富编辑器;
/// buildTextSpan 染色 + 宿主拦原子退格是 Flutter 惯用法)。IME 合成期回退默认 span(不与下划线打架)。仅
/// [pillNames] 中的名、且在 token 边界(前=行首/空白,后=空白/文末)才染——巧合子串不染。
class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({super.text});

  /// The names picked this session (the pseudo-pill vocabulary). 本次会话选中的名(伪药丸词表)。
  final Set<String> pillNames = {};

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (pillNames.isEmpty || (withComposing && value.composing.isValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final c = context.colors;
    final pillStyle = (style ?? AnText.body)
        .copyWith(color: c.accent, fontWeight: AnText.emphasisWeight, fontVariations: const [FontVariation('wght', 400)]);
    final spans = <InlineSpan>[];
    final s = text;
    var i = 0;
    while (i < s.length) {
      final at = s.indexOf('@', i);
      if (at < 0) break;
      final match = _tokenAt(s, at);
      if (match == null) {
        i = _emit(spans, s, i, at + 1, style);
        continue;
      }
      if (at > i) spans.add(TextSpan(text: s.substring(i, at), style: style));
      spans.add(TextSpan(text: '@$match', style: pillStyle));
      i = at + match.length + 1;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i), style: style));
    return TextSpan(style: style, children: spans);
  }

  /// The pill name starting at [at] (an '@'), or null. Longest name wins (nested names both picked).
  /// at 处的药丸名(最长优先,嵌套名都选过时不切错)。
  String? _tokenAt(String s, int at) {
    if (at > 0 && !_ws(s[at - 1])) return null;
    String? best;
    for (final name in pillNames) {
      final end = at + 1 + name.length;
      if (end > s.length || s.substring(at + 1, end) != name) continue;
      if (end < s.length && !_ws(s[end])) continue; // boundary 后边界
      if (best == null || name.length > best.length) best = name;
    }
    return best;
  }

  int _emit(List<InlineSpan> spans, String s, int from, int to, TextStyle? style) {
    spans.add(TextSpan(text: s.substring(from, to), style: style));
    return to;
  }
}

bool _ws(String ch) => ch == ' ' || ch == '\n' || ch == '\t';
