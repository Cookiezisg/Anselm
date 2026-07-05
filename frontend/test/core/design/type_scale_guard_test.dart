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
//
// 字号阶梯守卫:扫源码的门禁,锁住全应用单一字号体系——任何新代码都无法悄悄引入 bespoke 字号或违规字重。守两条
// 机械不变量(prose vs chrome 的语义判断是人的活、守卫管不了,它只保证原料集中在 typography.dart):①禁裸字号
// 字面(一切走 AnText.*)②只两档字重(w300/w400;代码高亮是唯一例外)。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The single source of type sizes — the only file allowed to name a raw size / a `wght` axis value.
  // 字号单源——唯一可写裸字号 / wght 轴值的文件。
  const sizeSource = 'lib/core/design/typography.dart';
  // Code syntax highlighting rides its own font system (bold keywords/args) — outside the two-weight
  // UI rule by design. 代码高亮自成字体体系(粗关键字/参数),按设计不入两档 UI 规。
  const weightExceptions = {'lib/core/ui/syntax_highlighter.dart'};

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

  test('no raw font-size literals outside typography.dart (single source of sizes)', () {
    final offenders = <String>[];
    for (final f in dartSources()) {
      if (rel(f).endsWith(sizeSource)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
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
        for (final m in wghtAxis.allMatches(lines[i])) {
          final v = m.group(1);
          if (v != '300' && v != '400') offenders.add('${rel(f)}:${i + 1}  wght=$v  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'The variable-font weight axis may only be 300 or 400 (two-weight rule):\n${offenders.join('\n')}');
  });
}
