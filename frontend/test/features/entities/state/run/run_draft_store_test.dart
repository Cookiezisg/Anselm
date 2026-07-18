import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/run/run_draft_store.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_test/flutter_test.dart';

// 调试台参数记忆 — the session draft store: buckets keyed by (entity, dimension), reproduce
// overwrites a bucket and bumps the revision so open forms re-seed.

void main() {
  const fn = EntityRef(EntityKind.function, 'fn_1');
  const hd = EntityRef(EntityKind.handler, 'hd_1');

  test('runDraftKey: fn/ag collapse the dimension, hd/wf carry it', () {
    expect(runDraftKey(fn), '$fn');
    expect(runDraftKey(hd, 'send'), '$hd/send');
    expect(runDraftKey(hd, 'recv'), isNot(runDraftKey(hd, 'send'))); // per-method buckets 按方法分桶
  });

  test('bucket: same key → same live map; different dimension → isolated values', () {
    final store = RunDraftStore();
    store.bucket(runDraftKey(hd, 'send'))['to'] = 'a@b.c';
    expect(store.bucket(runDraftKey(hd, 'send'))['to'], 'a@b.c'); // survives a re-read 重读仍在
    expect(store.bucket(runDraftKey(hd, 'recv'))['to'], isNull); // the other method is untouched
  });

  test('reproduce: overwrites the bucket, bumps revision, notifies', () {
    final store = RunDraftStore();
    store.bucket(runDraftKey(fn))['text'] = 'old';
    var notified = 0;
    store.addListener(() => notified++);
    final r0 = store.revision;

    store.reproduce(runDraftKey(fn), {'text': 'from-the-ledger', 'flag': true});

    expect(store.bucket(runDraftKey(fn)), {'text': 'from-the-ledger', 'flag': true});
    expect(store.revision, r0 + 1); // the form keys on this → uncontrolled inputs re-seed 重播种
    expect(notified, 1);
  });

  test('reproduce copies the values (later caller mutation cannot leak in)', () {
    final store = RunDraftStore();
    final src = <String, Object?>{'text': 'v1'};
    store.reproduce(runDraftKey(fn), src);
    src['text'] = 'mutated';
    expect(store.bucket(runDraftKey(fn))['text'], 'v1');
  });
}
