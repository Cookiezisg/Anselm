import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:flutter_test/flutter_test.dart';

// C-028 — family bodies / receipts decoded state.resultText every build (13 sites); settled cards
// re-render on the 1s ticker + inside live turns, so a KB~百KB result re-parsed every frame. resultObj
// memoizes the decode PER INSTANCE (ToolCardState.of is revision-memoized → same instance until the
// result changes). 记忆化解码,每实例一次。
ToolCardState _state(String resultText) => ToolCardState(
      phase: ToolCardPhase.succeeded,
      toolName: 't',
      summary: '',
      danger: 'safe',
      argsText: '{}',
      resultText: resultText,
      errorText: '',
      progressText: '',
      progressLive: false,
    );

void main() {
  group('C-028 resultObj behaviour', () {
    test('a JSON object decodes to a Map', () {
      expect(_state('{"version":3,"ok":true}').resultObj, {'version': 3, 'ok': true});
    });
    test('non-object / bad / empty → null', () {
      expect(_state('[1,2,3]').resultObj, isNull, reason: 'List 非 Map');
      expect(_state('not json').resultObj, isNull);
      expect(_state('').resultObj, isNull);
      expect(_state('42').resultObj, isNull);
    });
  });

  test('C-028 memoized: the SAME instance returns the SAME decoded Map (identity)', () {
    final s = _state('{"a":1}');
    final first = s.resultObj;
    expect(identical(first, s.resultObj), isTrue, reason: '同实例→同一 Map(缓存)');
    // A different instance decodes independently (equal value, different identity). 异实例独立解。
    final s2 = _state('{"a":1}');
    expect(s2.resultObj, first);
    expect(identical(s2.resultObj, first), isFalse);
  });

  test('C-028 memoized null: a non-object result caches as null (no re-parse)', () {
    final s = _state('garbage');
    expect(s.resultObj, isNull);
    expect(s.resultObj, isNull); // second read hits the null sentinel 命中空哨兵
  });
}
