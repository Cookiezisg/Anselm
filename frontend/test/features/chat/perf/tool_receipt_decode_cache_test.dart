import 'dart:convert';

import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:flutter_test/flutter_test.dart';

// C-005 — the lifecycle receipt parsers decode the SAME settled result JSON on every re-render (the 1s
// ticker + live-turn rebuilds), so a large result re-parsed unboundedly. `_obj` now memoizes the decode
// (immutable per string). Tested through the public revertReceipt (which calls `_obj`). 记忆化解码。
void main() {
  test(
    'C-005 revertReceipt reads the version correctly (behaviour preserved)',
    () {
      final r = revertReceipt(
        '{"id":"fn_1","version":7}',
        rewind: (v) => 'rolled back to v$v',
      );
      expect(r?.text, 'rolled back to v7');
    },
  );

  test('C-005 non-object / bad JSON is tolerated (null)', () {
    expect(revertReceipt('not json', rewind: (v) => 'v$v'), isNull);
    expect(revertReceipt('[1,2,3]', rewind: (v) => 'v$v'), isNull);
  });

  test(
    'C-005 budget: re-parsing the SAME large result is O(1) after the first (cache hit)',
    () {
      // A large result JSON — without the cache, 5000 re-renders re-parse it every time. 大结果 JSON。
      final big = jsonEncode({
        'version': 4,
        'log': List.filled(4000, 'a line of output').join('\n'),
      });
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        revertReceipt(big, rewind: (v) => 'v$v');
      }
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(150),
        reason: '缓存命中:${sw.elapsedMilliseconds}ms(无缓存=5000× 全量 parse)',
      );
    },
  );
}
