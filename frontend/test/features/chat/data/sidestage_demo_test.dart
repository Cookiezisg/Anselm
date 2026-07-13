import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// D-006/007/008/009/010/013 — the `make demo` chat sidestage needs a Cast row per kind AND the
// old-truth snapshot each stage GETs when opened, so every sidestage stage (agent / approval / control /
// handler / trigger) can actually open, plus a tombstone row (verb=deleted) for the banned-GET face.
// 每 kind 一个 Cast 行 + 对应旧真相快照,五舞台皆可开;外加墓碑行。
void main() {
  final repo = demoChatRepository();

  test('D-008/010 control + trigger stages: the wf_night graph refs resolve to real snapshots', () async {
    final rows = await repo.listTouchpoints('cv_sync');
    expect(rows.items.any((r) => r.itemKind == 'control' && r.itemId == 'amount_gate'), isTrue);
    expect(rows.items.any((r) => r.itemKind == 'trigger' && r.itemId == 'cron_nightly'), isTrue);
    // The stage GET (R-16: trigger trusts only this GET) must succeed. 舞台 GET 必成。
    expect((await repo.getControlSnapshot('amount_gate')).activeVersion!.branches, isNotEmpty);
    expect((await repo.getTriggerSnapshot('cron_nightly')).listening, isTrue);
  });

  test('D-006/007/009 agent + approval + handler stages open', () async {
    final rows = await repo.listTouchpoints('cv_sync');
    expect(rows.items.any((r) => r.itemKind == 'agent' && r.itemId == 'ag_reconcile'), isTrue);
    expect(rows.items.any((r) => r.itemKind == 'approval' && r.itemId == 'apf_refund'), isTrue);
    expect(rows.items.any((r) => r.itemKind == 'handler' && r.itemId == 'hd_ledger'), isTrue);
    expect((await repo.getAgentSnapshot('ag_reconcile')).activeVersion!.prompt, isNotEmpty);
    expect((await repo.getApprovalSnapshot('apf_refund')).activeVersion!.template, contains('{{ input.amount }}'));
    expect((await repo.getHandlerSnapshot('hd_ledger')).activeVersion!.methods, isNotEmpty);
  });

  test('D-013 tombstone: a deleted-verb Cast row (its GET is banned, never seeded)', () async {
    final rows = await repo.listTouchpoints('cv_sync', verb: TouchpointVerb.deleted);
    expect(rows.items, isNotEmpty, reason: '墓碑行存在');
    expect(rows.items.every((r) => r.verb == TouchpointVerb.deleted), isTrue);
    // The tombstoned id has NO snapshot — the stage must never GET it. 墓碑无快照,舞台不得 GET。
    expect(() => repo.getFunctionSnapshot('fn_legacy_sync'), throwsA(isA<StateError>()));
  });
}
