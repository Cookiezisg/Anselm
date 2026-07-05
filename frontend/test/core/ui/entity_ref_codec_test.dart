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

  group('expandEntityRefs (load)', () {
    test('rewrites [[id]] → [name](anselm-entity:id) using the resolved name', () {
      expect(
        expandEntityRefs('call [[$id1]] now', {id1: 'sync_inventory'}),
        'call [sync_inventory]($kEntityRefScheme:$id1) now',
      );
    });

    test('falls back to the raw id when the name is unresolved', () {
      expect(expandEntityRefs('[[$id1]]', const {}), '[$id1]($kEntityRefScheme:$id1)');
    });

    test('leaves prose without wikilinks untouched', () {
      expect(expandEntityRefs('nothing here', const {}), 'nothing here');
    });
  });

  group('collapseEntityRefs (save)', () {
    test('collapses [name](anselm-entity:id) → [[id]], dropping the display name', () {
      expect(
        collapseEntityRefs('call [sync_inventory]($kEntityRefScheme:$id1) now'),
        'call [[$id1]] now',
      );
    });

    test('leaves ordinary markdown links alone', () {
      const link = '[docs](https://example.com)';
      expect(collapseEntityRefs('read $link please'), 'read $link please');
    });
  });

  group('round-trip', () {
    test('expand ∘ collapse restores the stored wire form (name-agnostic)', () {
      const stored = 'wire [[$id1]] and [[$id2]] here';
      final expanded = expandEntityRefs(stored, {id1: 'alpha', id2: 'beta gamma'});
      expect(collapseEntityRefs(expanded), stored);
    });

    test('collapse is idempotent + independent of the resolved name', () {
      final a = expandEntityRefs('[[$id1]]', {id1: 'one_name'});
      final b = expandEntityRefs('[[$id1]]', {id1: 'totally_different'});
      expect(collapseEntityRefs(a), collapseEntityRefs(b));
      expect(collapseEntityRefs(a), '[[$id1]]');
    });
  });
}
