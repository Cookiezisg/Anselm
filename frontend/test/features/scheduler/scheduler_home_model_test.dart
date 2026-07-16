import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/scheduler/ui/scheduler_home_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stub_scheduler_repo.dart';

// S3 · the operations home's PURE projections (WRK-069 §4) — the filter grammar, the run row's
// source identity and the replay real-numbers, all headless. 纯投影单测:过滤文法/来源短语/真数字。

final _now = DateTime.utc(2026, 7, 16, 9);

Flowrun _run({
  String id = 'fr_a',
  String? origin,
  String? triggerId,
  String? conversationId,
  String status = 'completed',
  DateTime? startedAt,
}) =>
    Flowrun(
      id: id,
      workflowId: 'wf_a',
      origin: origin,
      triggerId: triggerId,
      conversationId: conversationId,
      status: status,
      startedAt: startedAt,
      updatedAt: _now,
    );

TriggerEntity _trigger(String id, {String name = 'T', Map<String, dynamic> config = const {}}) =>
    TriggerEntity(id: id, name: name, config: config, createdAt: _now, updatedAt: _now);

void main() {
  group('runListFilter — the ONE wire grammar', () {
    test('all: no status, no window bound when «全部时间»', () {
      final f = runListFilter(filter: RunStatusFilter.all, window: RunWindow.all, now: _now);
      expect(f.status, isNull);
      expect(f.startedAfter, isNull);
      expect(f.origin, isNull);
    });

    test('running / failed map to the closed-set words', () {
      expect(runListFilter(filter: RunStatusFilter.running, window: RunWindow.d7, now: _now).status,
          'running');
      expect(runListFilter(filter: RunStatusFilter.failed, window: RunWindow.d7, now: _now).status,
          'failed');
    });

    test('waiting asks for RUNNING — never ?status=parked (封闭集无此值,422)', () {
      final f = runListFilter(filter: RunStatusFilter.waiting, window: RunWindow.d7, now: _now);
      expect(f.status, 'running', reason: '等人=running∩inbox,绝不把 parked 发上线缆');
      expect(f.status, isNot('parked'));
    });

    test('windows subtract their exact span from now (工单⑥ startedAfter)', () {
      expect(runListFilter(filter: RunStatusFilter.all, window: RunWindow.h24, now: _now).startedAfter,
          _now.subtract(const Duration(hours: 24)));
      expect(runListFilter(filter: RunStatusFilter.all, window: RunWindow.d7, now: _now).startedAfter,
          _now.subtract(const Duration(days: 7)));
      expect(runListFilter(filter: RunStatusFilter.all, window: RunWindow.d30, now: _now).startedAfter,
          _now.subtract(const Duration(days: 30)));
    });

    test('origin rides through untouched', () {
      final f = runListFilter(
          filter: RunStatusFilter.all, origin: 'cron', window: RunWindow.d7, now: _now);
      expect(f.origin, 'cron');
    });
  });

  group('runSourceOf — the row IS its source phrase', () {
    test('manual / chat (chat carries its conversation coordinate)', () {
      expect(runSourceOf(_run(origin: 'manual'), const {}).origin, 'manual');
      final chat = runSourceOf(_run(origin: 'chat', conversationId: 'cv_1'), const {});
      expect(chat.origin, 'chat');
      expect(chat.conversationId, 'cv_1');
    });

    test('cron detail = THIS run\'s local fire time-of-day', () {
      final started = DateTime(2026, 7, 16, 9, 5); // local — the phrase is a wall-clock read. 本地。
      final s = runSourceOf(_run(origin: 'cron', startedAt: started), const {});
      expect(s.detail, '09:05');
    });

    test('cron with no start stamp → no fake time', () {
      expect(runSourceOf(_run(origin: 'cron'), const {}).detail, isNull);
    });

    test('webhook detail = its path (config beats the name)', () {
      final t = _trigger('tr_h', name: '发票回调', config: const {'path': '/invoice'});
      expect(runSourceOf(_run(origin: 'webhook', triggerId: 'tr_h'), {'tr_h': t}).detail, '/invoice');
    });

    test('webhook with no path falls back to the trigger name', () {
      final t = _trigger('tr_h', name: '发票回调');
      expect(runSourceOf(_run(origin: 'webhook', triggerId: 'tr_h'), {'tr_h': t}).detail, '发票回调');
    });

    test('fsnotify / sensor detail = the trigger name', () {
      final t = _trigger('tr_f', name: '监听 inbox/');
      expect(runSourceOf(_run(origin: 'fsnotify', triggerId: 'tr_f'), {'tr_f': t}).detail, '监听 inbox/');
      expect(runSourceOf(_run(origin: 'sensor', triggerId: 'tr_f'), {'tr_f': t}).detail, '监听 inbox/');
    });

    test('a pre-provenance row (origin null) is honestly UNKNOWN — never a zero-value lie', () {
      final s = runSourceOf(_run(), const {});
      expect(s.origin, isNull);
      expect(s.detail, isNull);
    });

    test('an unknown future origin word degrades to unknown, never crashes', () {
      expect(runSourceOf(_run(origin: 'telepathy'), const {}).origin, isNull);
    });

    test('a dangling triggerId (deleted trigger) leaves the detail absent, not a crash', () {
      expect(runSourceOf(_run(origin: 'webhook', triggerId: 'tr_gone'), const {}).detail, isNull);
    });
  });

  group('waitingRunIds — inbox-derived membership', () {
    test('this workflow only, de-duped, order preserved', () {
      final rows = [
        stubInboxRow('fr_1', 'gate_a', wfId: 'wf_a'),
        stubInboxRow('fr_2', 'gate_b', wfId: 'wf_b'), // another workflow. 别的 workflow。
        stubInboxRow('fr_1', 'gate_c', wfId: 'wf_a'), // same run, second gate. 同 run 两闸。
        stubInboxRow('fr_3', 'gate_d', wfId: 'wf_a'),
      ];
      expect(waitingRunIds(rows, 'wf_a'), ['fr_1', 'fr_3']);
    });

    test('empty inbox → empty set', () => expect(waitingRunIds(const [], 'wf_a'), isEmpty));
  });

  group('replayCounts — the memoization promise\'s real numbers', () {
    FlowrunNode node(String id, String status) => FlowrunNode(
        id: 'frn_$id',
        flowrunId: 'fr_a',
        nodeId: id,
        status: status,
        createdAt: _now,
        updatedAt: _now);

    test('failed rows re-run, completed rows are reused, parked counts as neither', () {
      final c = replayCounts([
        node('a', 'completed'),
        node('b', 'completed'),
        node('c', 'failed'),
        node('d', 'parked'),
      ]);
      expect(c.failed, 1);
      expect(c.completed, 2);
    });

    test('no nodes → zeros (the caller renders the numberless sentence)', () {
      final c = replayCounts(const []);
      expect(c.failed, 0);
      expect(c.completed, 0);
    });
  });
}
