import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/features/notifications/ui/notification_copy.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// The type→sentence mapper. Pins: compositional lifecycle (kind lead + name + verb), the important 7
// (danger/warn tone + detail), payload-shape branches (reconnected/attention/sandbox/dependency), the
// name/path/nameless fallbacks, and the unknown-type generic fallback. Never throws.

NotificationItem _n(String type, {Map<String, dynamic> payload = const {}}) =>
    NotificationItem(
      id: 'noti_x',
      type: type,
      payload: payload,
      createdAt: DateTime.utc(2026, 7, 6),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  test('compositional lifecycle: kind lead + emphasized name + verb', () {
    final l = notificationLine(
      _n('function.created', payload: {'name': 'fetch'}),
      t,
    );
    expect(l.lead, 'Function');
    expect(l.name, 'fetch');
    expect(l.trail, 'created');
    expect(l.tone, AnTone.none);
  });

  test('every lifecycle verb resolves (no silent empty trail)', () {
    for (final a in [
      'created',
      'edited',
      'reverted',
      'updated',
      'deleted',
      'env_rebuilt',
      'config_updated',
      'config_cleared',
    ]) {
      final l = notificationLine(_n('handler.$a', payload: {'name': 'h'}), t);
      expect(l.trail, isNotEmpty, reason: a);
    }
  });

  test('run_failed → danger + error detail', () {
    final l = notificationLine(
      _n('workflow.run_failed', payload: {'name': 'w', 'error': 'boom'}),
      t,
    );
    expect(l.tone, AnTone.danger);
    expect(l.name, 'w');
    expect(l.detail, 'boom');
  });

  test('crashed → danger; approval_pending → warn', () {
    expect(
      notificationLine(_n('handler.crashed', payload: {'name': 'h'}), t).tone,
      AnTone.danger,
    );
    expect(
      notificationLine(
        _n('workflow.approval_pending', payload: {'name': 'w'}),
        t,
      ).tone,
      AnTone.warn,
    );
  });

  test(
    'handler.restarted splits by outcome — ok:true → neutral, ok:false → danger',
    () {
      // Regression: the tone must honor payload['ok']. ok:true is frame-only but the toast dispatcher reads
      // this line's tone, so rendering a success as danger pops a false "restart failed" toast/OS notification.
      final ok = notificationLine(
        _n('handler.restarted', payload: {'name': 'h', 'ok': true}),
        t,
      );
      expect(ok.tone, AnTone.none, reason: '成功重启绝不渲成失败');
      final failed = notificationLine(
        _n('handler.restarted', payload: {'name': 'h', 'ok': false}),
        t,
      );
      expect(failed.tone, AnTone.danger);
      expect(failed.trail, isNotEmpty);
    },
  );

  test('attention_changed: needs → warn+reason, cleared → neutral', () {
    final needs = notificationLine(
      _n(
        'workflow.attention_changed',
        payload: {'name': 'w', 'needsAttention': true, 'attentionReason': 'r'},
      ),
      t,
    );
    expect(needs.tone, AnTone.warn);
    expect(needs.detail, 'r');
    final cleared = notificationLine(
      _n(
        'workflow.attention_changed',
        payload: {'name': 'w', 'needsAttention': false},
      ),
      t,
    );
    expect(cleared.tone, AnTone.none);
  });

  test(
    'sandbox env: failed → danger (no kind lead — verb self-describes), ready → neutral',
    () {
      final f = notificationLine(
        _n(
          'sandbox.env_status_changed',
          payload: {'status': 'failed', 'errorMsg': 'e'},
        ),
        t,
      );
      expect(f.tone, AnTone.danger);
      expect(f.lead, isNull);
      expect(f.detail, 'e');
      expect(
        notificationLine(
          _n('sandbox.env_status_changed', payload: {'status': 'ready'}),
          t,
        ).tone,
        AnTone.none,
      );
    },
  );

  test('mcp.reconnected splits by outcome status', () {
    expect(
      notificationLine(
        _n('mcp.reconnected', payload: {'name': 'm', 'status': 'ready'}),
        t,
      ).tone,
      AnTone.none,
    );
    expect(
      notificationLine(
        _n('mcp.reconnected', payload: {'name': 'm', 'status': 'failed'}),
        t,
      ).tone,
      AnTone.danger,
    );
  });

  test(
    'dependency_broken: standard subject clause (kind lead + deleted id as name), deps in detail',
    () {
      // 0719 «句式归队»: the deleted entity IS the subject (kind lead + id name — its name is gone from the
      // store by notify time), the trail is a proper verb phrase, the dependents ride the detail line.
      final l = notificationLine(
        _n(
          'relation.dependency_broken',
          payload: {
            'deletedKind': 'workflow',
            'deletedId': 'nightly_sync',
            'dependents': [
              {'kind': 'agent', 'name': 'a1'},
              {'kind': 'workflow', 'name': 'w1'},
            ],
          },
        ),
        t,
      );
      expect(
        l.lead,
        t.ref.workflow,
      ); // the deleted entity's kind = the subject lead
      expect(l.name, 'nightly_sync'); // named by id
      expect(l.tone, AnTone.warn);
      expect(l.detail, 'a1 · w1'); // dependents ride the detail line
      expect(l.trail, contains('2')); // "…leaving 2 references dangling"
    },
  );

  test('document uses path as the name', () {
    expect(
      notificationLine(
        _n('document.deleted', payload: {'path': 'a/b.md'}),
        t,
      ).name,
      'a/b.md',
    );
  });

  test(
    'nameless payload → null name (row renders honestly without an object)',
    () {
      expect(notificationLine(_n('agent.created'), t).name, isNull);
    },
  );

  test('unknown type → generic non-empty line, never throws', () {
    final l = notificationLine(_n('quasar.collapsed', payload: {'x': 1}), t);
    expect(l.trail, isNotEmpty);
    expect(l.name, isNull);
  });
}
