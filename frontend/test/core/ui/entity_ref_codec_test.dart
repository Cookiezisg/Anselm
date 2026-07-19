import 'package:anselm/core/ui/entity_ref_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id1 = 'fn_0123456789abcdef';
  const id2 = 'ag_fedcba9876543210';

  group('extractEntityRefIds', () {
    test('pulls every [[id]] in order, repeats included', () {
      expect(
        extractEntityRefIds('see [[$id1]] and [[$id2]] and again [[$id1]]'),
        [id1, id2, id1],
      );
    });

    test('ignores non-id brackets + malformed ids', () {
      // Not the strict <prefix>_<16hex> shape → not a wikilink. 非严格形不算。
      expect(extractEntityRefIds('[[not_an_id]] [[fn_short]] [[wiki]] plain [text](url)'), isEmpty);
    });

    test('empty on plain prose', () => expect(extractEntityRefIds('just words, no refs'), isEmpty));
  });
}
