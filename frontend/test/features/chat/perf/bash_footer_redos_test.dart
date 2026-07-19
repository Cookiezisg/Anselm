import 'package:anselm/features/chat/ui/tool_card_skins.dart';
import 'package:flutter_test/flutter_test.dart';

// C-027 (perf budget) — the bash footer strip's `(\[…\]\n?)*\[exit code…]` regex catastrophically
// backtracks on bracket-heavy output with NO trailing exit code (the failing match tries every
// partition). stripBashFooter guards it with a linear anchored check, so the pathological case is O(n).
// This test convicts (a budget on a pathological input) AND pins byte-exact behavior. C-027 ReDoS 预算。
void main() {
  group('C-027 stripBashFooter — behaviour preserved', () {
    test('strips a bare exit-code footer', () {
      expect(stripBashFooter('done\n[exit code: 0]').trimRight(), 'done');
    });
    test('strips a note + exit-code footer', () {
      expect(stripBashFooter('ok\n[note: bg]\n[exit code: 1]').trimRight(), 'ok');
    });
    test('strips a negative exit code', () {
      expect(stripBashFooter('boom\n[exit code: -1]').trimRight(), 'boom');
    });
    test('leaves output with NO footer unchanged', () {
      expect(stripBashFooter('just some output\nno footer'), 'just some output\nno footer');
    });
    test('leaves a mid-text (non-trailing) exit code alone', () {
      const s = '[exit code: 0]\nmore text after';
      expect(stripBashFooter(s), s, reason: '非尾部 exit code 不剥');
    });
  });

  test('C-027 budget: bracket-heavy output with no footer strips in O(n)', () {
    // Measured (raw regex, no guard): this input's replaceFirst is O(n²) — 1307ms at n=5000 (the
    // diagnosis' "catastrophic exponential" overstated it; it's polynomial). The linear anchored guard
    // short-circuits the no-footer case to O(n) → instant. 实测:无守卫 O(n²)、n=5000 达 1307ms;守卫下 O(n)。
    final pathological = List.filled(5000, '[warning: something happened]').join('\n');
    final sw = Stopwatch()..start();
    final out = stripBashFooter(pathological);
    sw.stop();
    expect(out, pathological, reason: '无尾 footer→原样返回');
    expect(sw.elapsedMilliseconds, lessThan(100),
        reason: 'O(n) 守卫生效:${sw.elapsedMilliseconds}ms(原 O(n²) 此规模 ~1.3s)');
  });
}
