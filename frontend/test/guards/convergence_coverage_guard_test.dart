// The CONVERGENCE COVERAGE LEDGER (WRK-066「同轨」§3.3b) — the campaign's DENOMINATOR. The ratchet
// (convergence_guard_test.dart) only proves that FOUND debt shrinks; this file proves every source
// file was actually LOOKED AT. Census-driven ledgers guarantee "what was found gets fixed" — they
// cannot guarantee "everything was seen" (P1 named 114 of 451 files). This ledger closes that gap:
//
//   • test/guards/convergence_coverage.txt lists EVERY non-generated lib/**.dart file with a status:
//       pending    not yet reviewed by the campaign (the starting state)
//       ledgered   named by a P1 census finding — will be visited by its P4 batch
//       reviewed   adversarially reviewed this campaign, findings fixed, but not yet on final primitives
//       converged  reviewed AND fully on An* primitives / grammar — the terminal state
//       exempt     user-signed §7 exemption (never AI-decided)
//   • This guard enforces SET EQUALITY with the real tree: a new file must be registered (run
//     UPDATE_COVERAGE=1 to add it as `pending`), a deleted file must be dropped. UPDATE_COVERAGE
//     never touches existing statuses — status changes are hand-edits, visible in the commit diff,
//     auditable like the ratchet baseline.
//   • Campaign completion (/goal criteria) = zero `pending`, zero `ledgered` — every file either
//     converged, reviewed-clean, or user-exempted. `grep -c pending` IS the progress bar.
//
// 收敛覆盖台账(「同轨」§3.3b)——战役的分母。棘轮只证明「找到的债在收缩」;本档证明「每个文件都被看过」
// (普查点名 114/451,发现驱动不等于全覆盖)。coverage.txt 给全部非生成 lib/**.dart 逐文件记状态
// (pending 未审/ledgered 普查在案/reviewed 已对抗复审/converged 已完全同轨/exempt 用户签字豁免);
// 本 guard 强制与真实文件树集合相等:新文件必登记(UPDATE_COVERAGE=1 以 pending 加入)、删文件必销账;
// UPDATE_COVERAGE 绝不改既有状态——状态推进=手改、diff 可审。完成判据=pending 与 ledgered 双清零。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _coveragePath = 'test/guards/convergence_coverage.txt';
const _statuses = {'pending', 'ledgered', 'reviewed', 'converged', 'exempt'};

Set<String> _tree() {
  final out = <String>{};
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) continue;
    out.add(e.path.replaceAll(r'\', '/'));
  }
  return out;
}

Map<String, String> _parse(String text) {
  final out = <String, String>{};
  for (final line in text.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length != 2) continue;
    out[parts[0]] = parts[1];
  }
  return out;
}

String _render(Map<String, String> entries) {
  final keys = entries.keys.toList()..sort();
  final b = StringBuffer();
  for (final k in keys) {
    b.writeln('$k\t${entries[k]}');
  }
  return b.toString();
}

void main() {
  test('convergence coverage: every lib file is registered with a review status (WRK-066 §3.3b)', () {
    final tree = _tree();
    final file = File(_coveragePath);
    expect(file.existsSync(), isTrue, reason: 'coverage ledger missing: $_coveragePath');
    final ledger = _parse(file.readAsStringSync());

    if (Platform.environment['UPDATE_COVERAGE'] == '1') {
      // Reconcile the SET only — never a status. 只对账集合,绝不动状态。
      final next = <String, String>{
        for (final f in tree) f: ledger[f] ?? 'pending',
      };
      file.writeAsStringSync(_render(next));
      final pending = next.values.where((s) => s == 'pending').length;
      // ignore: avoid_print
      print('coverage ledger reconciled: ${next.length} files, $pending pending.');
      return;
    }

    final unregistered = tree.difference(ledger.keys.toSet()).toList()..sort();
    final stale = ledger.keys.toSet().difference(tree).toList()..sort();
    final badStatus = [
      for (final e in ledger.entries)
        if (!_statuses.contains(e.value)) '${e.key} → "${e.value}"',
    ];

    expect(unregistered, isEmpty,
        reason: 'NEW files must enter the coverage denominator (as pending) — run '
            'UPDATE_COVERAGE=1 flutter test test/guards/:\n${unregistered.join('\n')}');
    expect(stale, isEmpty,
        reason: 'Deleted files must leave the ledger — run '
            'UPDATE_COVERAGE=1 flutter test test/guards/:\n${stale.join('\n')}');
    expect(badStatus, isEmpty,
        reason: 'Unknown status (allowed: ${_statuses.join('/')}):\n${badStatus.join('\n')}');
  });
}
