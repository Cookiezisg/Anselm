import 'package:anselm/core/model/status_state.dart';
import 'package:flutter_test/flutter_test.dart';

// The status fold is a pure single-source contract — the backend's many strings MUST land on the
// 5 universal states + their tones, or every dot/badge drifts. 状态折叠是纯单源契约,必须收敛。
void main() {
  group('AnStatus.fromRaw', () {
    test('direct names map to themselves (case-insensitive)', () {
      expect(AnStatus.fromRaw('run'), AnStatus.run);
      expect(AnStatus.fromRaw('DONE'), AnStatus.done);
      expect(AnStatus.fromRaw('Idle'), AnStatus.idle);
    });

    test('backend aliases fold to universal states', () {
      expect(AnStatus.fromRaw('running'), AnStatus.run);
      expect(AnStatus.fromRaw('listening'), AnStatus.run);
      expect(AnStatus.fromRaw('completed'), AnStatus.done);
      expect(AnStatus.fromRaw('fired'), AnStatus.done);
      expect(
        AnStatus.fromRaw('started'),
        AnStatus.done,
      ); // firing terminal-ok (批7 B-037)
      expect(AnStatus.fromRaw('failed'), AnStatus.err);
      expect(AnStatus.fromRaw('error'), AnStatus.err);
      expect(
        AnStatus.fromRaw('timeout'),
        AnStatus.err,
      ); // Log-table failure terminal (批7 B-037 — 删此别名=timeout 红变灰,exec 突变闸同钉)
      expect(AnStatus.fromRaw('parked'), AnStatus.wait);
      expect(AnStatus.fromRaw('pending'), AnStatus.wait);
      expect(
        AnStatus.fromRaw('claimed'),
        AnStatus.wait,
      ); // firing claim-transaction transient (批7 B-037)
      expect(AnStatus.fromRaw('cancelled'), AnStatus.idle);
      expect(AnStatus.fromRaw('future'), AnStatus.idle);
    });

    test('unknown / null / empty → idle', () {
      expect(AnStatus.fromRaw('nonsense'), AnStatus.idle);
      expect(AnStatus.fromRaw(null), AnStatus.idle);
      expect(AnStatus.fromRaw(''), AnStatus.idle);
    });
  });

  test('tone mapping is the single source (idle neutral)', () {
    expect(AnStatus.err.tone, AnTone.danger);
    expect(AnStatus.wait.tone, AnTone.warn);
    expect(AnStatus.done.tone, AnTone.ok);
    expect(AnStatus.run.tone, AnTone.accent);
    expect(AnStatus.idle.tone, AnTone.none);
  });
}
