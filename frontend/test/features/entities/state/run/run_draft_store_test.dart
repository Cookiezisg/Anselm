import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/run/run_draft_store.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_test/flutter_test.dart';

// 调试台参数记忆 (JSON-first, 0719) — the session draft store: buckets keyed by (entity, dimension) hold
// JSON TEXT; setText writes quietly (no notify — a keystroke must not rebuild), seed is a one-time
// idempotent fill, and fill overwrites + bumps the revision so an open editor re-seeds.

void main() {
  const fn = EntityRef(EntityKind.function, 'fn_1');
  const hd = EntityRef(EntityKind.handler, 'hd_1');

  test('runDraftKey: fn/ag collapse the dimension, hd/wf carry it', () {
    expect(runDraftKey(fn), '$fn');
    expect(runDraftKey(hd, 'send'), '$hd/send');
    expect(runDraftKey(hd, 'recv'), isNot(runDraftKey(hd, 'send'))); // per-method buckets 按方法分桶
  });

  test('textFor: null until seeded/edited; setText writes, isolated per dimension', () {
    final store = RunDraftStore();
    expect(store.textFor(runDraftKey(hd, 'send')), isNull);
    store.setText(runDraftKey(hd, 'send'), '{"to":"a@b.c"}');
    expect(store.textFor(runDraftKey(hd, 'send')), '{"to":"a@b.c"}');
    expect(store.textFor(runDraftKey(hd, 'recv')), isNull); // the other method is untouched
  });

  test('setText is QUIET (no notify — typing must not rebuild the lifecycle)', () {
    final store = RunDraftStore();
    var notified = 0;
    store.addListener(() => notified++);
    store.setText(runDraftKey(fn), '{"a":1}');
    expect(notified, 0);
  });

  test('seed is one-time idempotent (never clobbers an existing bucket)', () {
    final store = RunDraftStore();
    store.seed(runDraftKey(fn), '{"seed":1}');
    store.seed(runDraftKey(fn), '{"seed":2}'); // second seed is a no-op 幂等
    expect(store.textFor(runDraftKey(fn)), '{"seed":1}');
  });

  test('fill: overwrites the bucket, bumps revision, notifies (an open editor re-seeds)', () {
    final store = RunDraftStore();
    store.setText(runDraftKey(fn), 'old');
    var notified = 0;
    store.addListener(() => notified++);
    final r0 = store.revision;

    store.fill(runDraftKey(fn), '{"text":"from-the-ledger"}');

    expect(store.textFor(runDraftKey(fn)), '{"text":"from-the-ledger"}');
    expect(store.revision, r0 + 1); // the editor keys on this → re-seeds 重播种
    expect(notified, 1);
  });
}
