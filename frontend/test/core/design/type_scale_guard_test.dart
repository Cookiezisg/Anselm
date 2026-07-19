// The TYPE-SCALE GUARD — a source-scanning gate that keeps the whole app on ONE type system, so no new
// code can quietly re-introduce a bespoke size or a banned weight. It enforces the two mechanical
// invariants the design system rests on (the semantic "prose vs chrome" choice is a human call the guard
// can't make — it only guarantees the raw material is centralized):
//
//   1. NO raw font-size literals. Every size must flow from `AnText.*` (core/design/typography.dart) —
//      the single source. A `fontSize: 15` anywhere else forks the scale.
//   2. TWO weights only (w300 / w400). `FontWeight.w500`/`w600`/`bold`/… and any `wght` axis value
//      outside {300,400} break the two-weight rule. Code SYNTAX highlighting is the sole exception
//      (a separate font system, not UI text).
//   3. NO raw line-height literals (`height: 1.6`) — a bespoke leading forks the ladder as surely
//      as a bespoke size (every rung pins its own height in typography.dart).
//   4. NO bare `copyWith(fontWeight:` — on the pinned-axis variable font the wght axis OVERRIDES
//      fontWeight, so a bare copyWith silently renders the base weight; every re-weight goes
//      through `.weight()` (the double-axis idiom).
//
// 字号阶梯守卫:扫源码的门禁,锁住全应用单一字号体系——任何新代码都无法悄悄引入 bespoke 字号或违规字重。守四条
// 机械不变量(prose vs chrome 的语义判断是人的活、守卫管不了,它只保证原料集中在 typography.dart):①禁裸字号
// 字面(一切走 AnText.*)②只两档字重(w300/w400;代码高亮是唯一例外)③禁裸行高字面(bespoke leading 同样
// 分叉阶梯)④禁裸 copyWith(fontWeight:)(VF 钉轴覆盖之、实渲底重;重定权必走 .weight())。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The single source of type sizes — the only file allowed to name a raw size / a `wght` axis value.
  // 字号单源——唯一可写裸字号 / wght 轴值的文件。
  const sizeSource = 'lib/core/design/typography.dart';
  // Two files legitimately name `fontWeight:` outside the two-weight ramp:
  //  • syntax_highlighter.dart — code highlighting rides its own font system (bold keywords/args).
  //  • an_fonts.dart — AnFace.on()'s system-face rebuild (copyWith can't NULL fontFamily) FAITHFULLY
  //    copies BOTH the source fontWeight AND its fontVariations, so it never has the pinned-axis bug this
  //    rule guards against (it preserves the exact weight, not re-weights it). 代码高亮自成字体体系;
  //    an_fonts 的系统脸重建忠实拷贝 fontWeight+fontVariations 双轴(copyWith 无法清空 family),非钉轴 bug。
  const weightExceptions = {
    'lib/core/ui/syntax_highlighter.dart',
    'lib/core/design/an_fonts.dart',
  };

  // fontSize: <number> — a raw literal (identifiers like `AnSize.iconSm` are fine). 裸字号字面。
  final rawSize = RegExp(r'fontSize:\s*[0-9]');
  // Any FontWeight other than the two allowed (w300/w400). 除 w300/w400 外的字重。
  final bannedWeight = RegExp(r'FontWeight\.(w100|w200|w500|w600|w700|w800|w900|bold)\b');
  // FontVariation('wght', N) with N not 300/400. wght 轴非 300/400。
  final wghtAxis = RegExp(r"""FontVariation\(\s*['"]wght['"]\s*,\s*([0-9]+)""");

  Iterable<File> dartSources() sync* {
    final dir = Directory('lib');
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) continue; // generated 生成物
      yield e;
    }
  }

  // Normalize to forward-slash repo-relative paths for stable membership checks. 归一路径。
  String rel(File f) => f.path.replaceAll(r'\', '/');

  // Comment lines (// and ///) may NAME the banned idioms while documenting them — only code counts.
  // 注释行可为说明而点名违规写法——只扫代码。
  bool isComment(String line) => line.trimLeft().startsWith('//');

  test('no raw font-size literals outside typography.dart (single source of sizes)', () {
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (rel(f).endsWith(sizeSource)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (rawSize.hasMatch(lines[i])) offenders.add('${rel(f)}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Raw font sizes fork the scale — route every size through AnText.* '
            '(add a token to typography.dart if a new rung is genuinely needed):\n${offenders.join('\n')}');
  });

  test('only two font weights (w300/w400) — no w500/w600/bold outside code highlighting', () {
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (weightExceptions.contains(rel(f))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (bannedWeight.hasMatch(lines[i])) offenders.add('${rel(f)}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Two-weight rule: emphasis is w400 via `.weight(AnText.emphasisWeight)`, never heavier. '
            'Hierarchy is size+colour, not weight:\n${offenders.join('\n')}');
  });

  test('wght axis values are 300 or 400 only (outside typography.dart)', () {
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (rel(f).endsWith(sizeSource)) continue;
      if (weightExceptions.contains(rel(f))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        for (final m in wghtAxis.allMatches(lines[i])) {
          final v = m.group(1);
          if (v != '300' && v != '400') offenders.add('${rel(f)}:${i + 1}  wght=$v  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'The variable-font weight axis may only be 300 or 400 (two-weight rule):\n${offenders.join('\n')}');
  });

  // TextStyle height: — a raw leading forks the ladder (body 1.4 / reading 1.6 / code 1.6 are all
  // pinned in typography.dart). Only matches decimal literals so widget-layout `height: 32` props
  // (SizedBox/Container) don't false-positive: a TextStyle leading is always fractional. `height: 1.0`
  // is allowed — the NEUTRAL leading (the markdown block-gap trick sizes a blank line by fontSize,
  // not a ladder leading). 裸 TextStyle 行高字面(小数才匹配,布局整数 height: 不误伤);1.0=中性行高放行
  // (markdown 块间距 trick,非阶梯 leading)。
  test('no raw line-height (TextStyle height) literals outside typography.dart', () {
    // MATCH-level exemption: a line holding both `height: 1.0` and a real bespoke leading must
    // still offend — a line-level skip would whitelist the whole line. 逐匹配豁免:同一行混 1.0 与
    // 真 leading 仍须报,整行跳过会连带放行。
    final heightValue = RegExp(r'height:\s*([0-9]+\.[0-9]+)');
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (rel(f).endsWith(sizeSource)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        for (final m in heightValue.allMatches(lines[i])) {
          if (double.parse(m.group(1)!) != 1.0) {
            offenders.add('${rel(f)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'A bespoke leading forks the type ladder — every rung pins its height in AnText.* '
            '(mint a token if a new leading is genuinely needed):\n${offenders.join('\n')}');
  });

  // ANY `fontWeight:` argument outside typography.dart — the strongest form of the VF rule: a bare
  // fontWeight (in copyWith OR a TextStyle ctor) silently loses to the pinned wght axis, and a
  // line-scoped copyWith regex missed the multi-line form. Every legit re-weight goes through
  // `.weight()`; the only raw uses live in typography.dart (the ramp) and the highlighter exception.
  // typography 外一律禁 `fontWeight:` 实参——VF 规则最强形(裸 fontWeight 被钉轴覆盖;行级 copyWith
  // 正则漏多行形)。合法重定权全走 .weight();裸用仅存 typography.dart(阶梯本体)与高亮例外。
  final bareFontWeight = RegExp(r'fontWeight:');

  test('re-weights go through .weight() — no bare fontWeight: outside typography.dart', () {
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (rel(f).endsWith(sizeSource)) continue; // the ramp + the extension live there 阶梯与扩展本体所在
      if (weightExceptions.contains(rel(f))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (bareFontWeight.hasMatch(lines[i])) offenders.add('${rel(f)}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'On the pinned-axis variable font a bare fontWeight renders the BASE weight '
            '(the wght axis overrides it) — use `.weight(AnText.emphasisWeight)`:\n${offenders.join('\n')}');
  });

}
