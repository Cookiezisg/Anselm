import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SyntaxColors = G5.0 syntax palette (separate ThemeExtension). Tests: light≠dark, copyWith/lerp all
// fields, theme registration via context.syntax, and the documented arg==accent mirror invariant.
// 语法调色板的全字段 lerp/copyWith + 明暗异 + theme 注册 + arg 镜像 accent 不变式。
void main() {
  const light = SyntaxColors.light;
  const dark = SyntaxColors.dark;
  List<Color> fields(SyntaxColors s) => [s.comment, s.keyword, s.string, s.number, s.function, s.arg];

  test('light and dark differ on every field (no copy-paste leftover)', () {
    final l = fields(light);
    final d = fields(dark);
    for (var i = 0; i < l.length; i++) {
      expect(l[i], isNot(d[i]), reason: 'field $i must differ between light/dark');
    }
  });

  test('arg mirrors AnColors.accent BY VALUE (documented invariant — catches a retune drift)', () {
    expect(light.arg, AnColors.light.accent);
    expect(dark.arg, AnColors.dark.accent);
  });

  test('copyWith replaces only the named field', () {
    const red = Color(0xFFFF0000);
    final s = light.copyWith(keyword: red);
    expect(s.keyword, red);
    expect(s.comment, light.comment);
    expect(s.string, light.string);
    expect(s.number, light.number);
    expect(s.function, light.function);
    expect(s.arg, light.arg);
  });

  test('lerp endpoints + midpoint across all fields', () {
    expect(fields(light.lerp(dark, 0)), fields(light));
    expect(fields(light.lerp(dark, 1)), fields(dark));
    final mid = light.lerp(dark, 0.5);
    for (var i = 0; i < 6; i++) {
      expect(fields(mid)[i], Color.lerp(fields(light)[i], fields(dark)[i], 0.5));
    }
  });

  test('lerp with a non-SyntaxColors other returns self (defensive)', () {
    expect(identical(light.lerp(null, 0.5), light), isTrue);
  });

  // Separate tests per theme (one pumpWidget each) — reusing the element tree across a loop iteration
  // can leave the Builder reading the prior theme. 每主题独立 test(避免元素树复用读到旧主题)。
  Future<void> expectRegistered(WidgetTester tester, ThemeData theme, SyntaxColors expected) async {
    late SyntaxColors got;
    late Color accent;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (context) {
        got = context.syntax;
        accent = context.colors.accent;
        return const SizedBox();
      }),
    ));
    expect(fields(got), fields(expected));
    expect(got.arg, accent, reason: 'arg is the accent at runtime too');
  }

  testWidgets('light theme registers SyntaxColors; context.syntax resolves + arg == accent', (tester) async {
    await expectRegistered(tester, AnTheme.light(), light);
  });

  testWidgets('dark theme registers SyntaxColors; context.syntax resolves + arg == accent', (tester) async {
    await expectRegistered(tester, AnTheme.dark(), dark);
  });

  test('G5.0 metric/style tokens exist with the floor + demo-faithful values', () {
    expect(AnSize.trail, 36); // line-number gutter floor (≥4 digits) 行号槽下界
    expect(AnText.code.fontSize, 12); // demo --t-meta
    expect(AnText.code.height, 1.6); // demo --lh-prose
    expect(AnText.code.fontFamily, AnText.monoFamily);
  });
}
