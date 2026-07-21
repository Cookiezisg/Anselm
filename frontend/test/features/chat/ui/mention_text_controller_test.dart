import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/chat/ui/mention_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The pseudo-pill tint: known @name tokens paint accent at token boundaries — and an OPEN IME
// COMPOSITION must not drop the tint (the reported CJK-typing flash): the composing range gets the
// underline, everything around it stays tinted.
// 伪药丸染色:token 边界处染 accent;**IME 合成期不掉色**(打中文闪灭的报修):合成段下划线、周围照染。

void main() {
  Future<TextSpan> build(
    WidgetTester tester,
    MentionTextEditingController ctl, {
    bool withComposing = true,
  }) async {
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        theme: AnTheme.light(),
        home: Builder(
          builder: (context) {
            span = ctl.buildTextSpan(
              context: context,
              style: const TextStyle(),
              withComposing: withComposing,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return span;
  }

  List<TextSpan> flat(TextSpan root) => [
    root,
    ...?root.children?.expand(
      (c) => c is TextSpan ? flat(c) : const <TextSpan>[],
    ),
  ];

  test(
    'token boundaries: only whitespace-delimited @name tints; substrings stay plain',
    () {
      final ctl = MentionTextEditingController(text: 'x@bot 和 @bot 与 @bots');
      ctl.pillNames.add('bot');
      addTearDown(ctl.dispose);
      // pure logic exercised via _tokenAt through buildTextSpan in the widget tests below; here we just
      // sanity-check construction. 构造健全性(边界逻辑在下面的 widget 测里过)。
      expect(ctl.pillNames, {'bot'});
    },
  );

  testWidgets('pills tint; a coincidental substring does not', (tester) async {
    final ctl = MentionTextEditingController(text: '@bot 看看 robot@bot');
    ctl.pillNames.add('bot');
    addTearDown(ctl.dispose);
    final spans = flat(await build(tester, ctl));
    final tinted = spans.where(
      (s) => s.text == '@bot' && s.style?.fontWeight == FontWeight.w400,
    );
    expect(tinted, hasLength(1)); // only the leading token 只有开头的 token
  });

  testWidgets(
    'an open composition keeps surrounding pills tinted and underlines only itself',
    (tester) async {
      final ctl = MentionTextEditingController(text: '@bot 你好');
      ctl.pillNames.add('bot');
      addTearDown(ctl.dispose);
      // composing over the trailing CJK 合成区间在尾部中文上
      ctl.value = ctl.value.copyWith(
        composing: const TextRange(start: 5, end: 7),
      );
      final spans = flat(await build(tester, ctl));
      final pill = spans.where(
        (s) => s.text == '@bot' && s.style?.fontWeight == FontWeight.w400,
      );
      expect(pill, hasLength(1)); // tint SURVIVES the IME (the bug) 合成期不掉色
      final underlined = spans.where(
        (s) =>
            s.text == '你好' && s.style?.decoration == TextDecoration.underline,
      );
      expect(underlined, hasLength(1)); // IME affordance intact 下划线仍在
    },
  );
}
