// The CONVERGENCE RATCHET (WRK-066「同轨」§3.3) — a source-scanning gate with a BASELINE file that
// freezes today's hand-rolled visual debt and only lets it SHRINK. The campaign's progress bar IS this
// baseline (`wc -l` it any time); its completion criterion IS an empty baseline. Mechanics:
//
//   • Scan lib/features/ + lib/app/ for the banned idioms below, aggregate per (file · category) counts.
//   • Compare EXACTLY against test/guards/convergence_baseline.txt:
//       count ABOVE baseline  → RED: a new violation crept in — use the An* family primitive instead
//                               (see docs/working/frontend/convergence.md §4-A / the design-system 法典).
//       count BELOW baseline  → RED too: progress must be RECORDED — shrink the baseline in the same
//                               commit (run: UPDATE_BASELINE=1 flutter test test/guards/).
//     Strict equality makes every improvement land in the baseline diff (the campaign's audit trail)
//     and leaves no slack a later regression could silently consume.
//   • Baseline edits that INCREASE a count are forbidden (reviewable in any diff) — the ratchet only
//     turns one way. Legitimate exceptions go through the charter's §7 exemption table (user-signed),
//     never through a quiet baseline bump.
//
// Categories (v0 — line-scoped, deliberately low-false-positive; the qualitative census catches the rest):
//   boxdecoration      raw `BoxDecoration(` — hand-rolled cards/chips/windows belong to An* families
//   token-arith        `AnSize.x - 4` etc — arithmetic on a token mints a private size tier
//   edgeinsets-literal an `EdgeInsets.*(...)` call carrying a bare numeric literal (spacing off-token)
//   raw-color          `Colors.*` / `Color(0x...)` — colours must flow from context.colors tokens
//   alpha-tweak        `withValues(alpha:` / `withOpacity(` — private opacity tiers (use AnOpacity)
//
// 收敛棘轮(WRK-066「同轨」§3.3):扫源码 + 基线文件——冻结今日手搓债、只许收缩。战役进度=基线本身
// (随时 wc -l),完成判据=基线为空。超基线=红(新违规,改用当家原语);低于基线=也红(进步必须同提交
// 记进基线:UPDATE_BASELINE=1 flutter test test/guards/)。严格相等使每次改进都留在基线 diff 里成为
// 审计痕,也不留可被回吃的余量。基线只准调小(diff 可查);合法例外走契约 §7 用户签字豁免表,绝不走
// 悄悄调大基线。类别 v0 行级扫描、刻意低假阳;其余由定性普查兜底。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/guards/convergence_baseline.txt';

/// The scanned roots — feature/assembly layers where visuals must come from An* primitives.
/// core/ui + core/design implement the primitives and are exempt by design; lib/dev (gallery)
/// is a census target but not ratcheted in v0 (specimens legitimately scaffold raw boxes).
/// 扫描根——视觉必须来自 An* 原语的 feature/装配层;core/ui·core/design 是原语本体天然豁免;
/// gallery 进普查台账但 v0 不进棘轮(specimen 合法搭裸盒)。
const _roots = ['lib/features', 'lib/app'];

final _categories = <String, RegExp>{
  'boxdecoration': RegExp(r'\bBoxDecoration\('),
  'token-arith': RegExp(
    r'An(?:Size|Space|Radius|Motion|Opacity)\.\w+\s*[-+*/]\s*\d',
  ),
  // An EdgeInsets call whose line carries a BARE number (AnSpace.s8's digit is preceded by a word
  // char, so the lookbehind skips it). Line-scoped: a multi-line ctor escapes v0 — accepted, the
  // census covers it. 行内裸数字的 EdgeInsets(代币 s8 的数字前是字母,lookbehind 放行);多行体 v0 漏网可接受。
  'edgeinsets-literal': RegExp(
    r'EdgeInsets(?:Directional)?\.(?:all|only|symmetric|fromLTRB)\(',
  ),
  'raw-color': RegExp(r'(?:\bColors\.\w|\bColor\(0x)'),
  'alpha-tweak': RegExp(r'withValues\(\s*alpha|withOpacity\('),
};
final _bareNumber = RegExp(r'(?<![\w.$])\d');

Map<String, int> _scan() {
  final counts = <String, int>{}; // "path\tcategory" → count
  for (final root in _roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) {
        continue;
      }
      final rel = e.path.replaceAll(r'\', '/');
      final lines = e.readAsLinesSync();
      for (final raw in lines) {
        final line = raw.trimLeft();
        if (line.startsWith('//')) continue; // comments may NAME idioms 注释可点名
        for (final entry in _categories.entries) {
          if (!entry.value.hasMatch(raw)) continue;
          // edgeinsets-literal only counts when a bare number rides the same line. 仅裸数字才算。
          if (entry.key == 'edgeinsets-literal' && !_bareNumber.hasMatch(raw)) {
            continue;
          }
          final key = '$rel\t${entry.key}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
  }
  return counts;
}

String _render(Map<String, int> counts) {
  final keys = counts.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln(
      '# WRK-066「同轨」convergence ratchet baseline — counts may ONLY decrease.',
    )
    ..writeln(
      '# 基线只许收缩。降到 0 的条目必须删除;新违规=guard 红。格式: path<TAB>category<TAB>count',
    );
  for (final k in keys) {
    b.writeln('$k\t${counts[k]}');
  }
  return b.toString();
}

Map<String, int> _parseBaseline(String text) {
  final out = <String, int>{};
  for (final line in text.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length != 3) continue;
    out['${parts[0]}\t${parts[1]}'] = int.parse(parts[2]);
  }
  return out;
}

void main() {
  test('convergence ratchet: hand-rolled visual debt only shrinks (WRK-066)', () {
    final actual = _scan();
    final file = File(_baselinePath);

    if (Platform.environment['UPDATE_BASELINE'] == '1') {
      file.writeAsStringSync(_render(actual));
      final total = actual.values.fold(0, (a, b) => a + b);
      // ignore: avoid_print
      print(
        'convergence baseline updated: ${actual.length} entries, $total violations.',
      );
      return;
    }

    expect(
      file.existsSync(),
      isTrue,
      reason:
          'baseline missing — generate with UPDATE_BASELINE=1 flutter test test/guards/',
    );
    final baseline = _parseBaseline(file.readAsStringSync());

    final grew = <String>[];
    final shrank = <String>[];
    for (final key in {...actual.keys, ...baseline.keys}) {
      final a = actual[key] ?? 0;
      final b = baseline[key] ?? 0;
      if (a > b) grew.add('${key.replaceAll('\t', ' · ')}: $a > baseline $b');
      if (a < b) shrank.add('${key.replaceAll('\t', ' · ')}: $a < baseline $b');
    }

    expect(
      grew,
      isEmpty,
      reason:
          'NEW hand-rolled visuals crept in — use the An* family primitive instead '
          '(WRK-066 convergence.md §4-A; exceptions need a user-signed §7 exemption):\n${grew.join('\n')}',
    );
    expect(
      shrank,
      isEmpty,
      reason:
          'Progress! Record it in the SAME commit — shrink the baseline:\n'
          '  UPDATE_BASELINE=1 flutter test test/guards/\n${shrank.join('\n')}',
    );
  });
}
