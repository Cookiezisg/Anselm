import 'package:anselm/core/model/partial_json.dart';
import 'package:flutter_test/flutter_test.dart';

// partialJsonEvents — the streaming JSON event engine (WRK-056 #3). Five batteries: empty, complete,
// nested, truncated-at-any-byte (the monotonicity invariant — never emit an incomplete value), and
// malformed/escapes. partialJsonArrayItems is the op-ticker / rule-ladder facade.
// 流中 JSON 事件引擎五电池:空/完整/嵌套/任意字节截断(单调性:绝不发不完整值)/畸形·转义。

List<Object> _pathOf(String s, Object? value) =>
    partialJsonEvents(s).firstWhere((e) => e.value == value).path;

void main() {
  test('empty / whitespace → no events', () {
    expect(partialJsonEvents(''), isEmpty);
    expect(partialJsonEvents('   \n\t '), isEmpty);
  });

  test('a complete object emits every value at its path + the container', () {
    final ev = partialJsonEvents('{"name":"foo","n":3,"ok":true}');
    final byPath = {for (final e in ev) e.path.join('.'): e.value};
    expect(byPath['name'], 'foo');
    expect(byPath['n'], 3);
    expect(byPath['ok'], true);
    expect(byPath[''], {'name': 'foo', 'n': 3, 'ok': true}); // the root container
  });

  test('nested paths + completion order (innermost closes first, root last)', () {
    final ev = partialJsonEvents('{"a":{"b":1}}');
    expect(ev.map((e) => e.path.join('/')).toList(), ['a/b', 'a', '']);
    expect(ev.first.value, 1);
    expect(ev.last.value, {'a': {'b': 1}});
  });

  test('array elements carry int indices, in source order', () {
    final items = partialJsonArrayItems('{"ops":[{"op":"add_node","id":"a"},{"op":"add_edge"}]}', ['ops']);
    expect(items.length, 2);
    expect((items[0] as Map)['op'], 'add_node');
    expect((items[1] as Map)['op'], 'add_edge');
  });

  test('truncation: only COMPLETED array elements surface (never a partial one)', () {
    // Second op is cut off mid-object → only the first completed op is reported. 第二个 op 截断→只报第一个。
    final items = partialJsonArrayItems('{"ops":[{"op":"add_node","id":"a"},{"op":"add_e', ['ops']);
    expect(items.length, 1);
    expect((items[0] as Map)['id'], 'a');
  });

  test('a bare number at end-of-input is INCOMPLETE (12 could still become 123)', () {
    // {"n":12  — the 12 hasn't closed, so [n] is not emitted; a closed one is. 到尾数字不发。
    expect(partialJsonEvents('{"n":12').where((e) => e.path.join() == 'n'), isEmpty);
    expect(partialJsonEvents('{"n":12}').where((e) => e.path.join() == 'n').single.value, 12);
  });

  test('MONOTONICITY: feeding growing prefixes never un-completes a value', () {
    const full = '{"name":"quarterly_rollup","ops":[{"op":"set_meta"},{"op":"add_node","id":"n1"},'
        '{"op":"add_edge","from":"n1","to":"n2"}],"concurrency":4}';
    var lastOps = 0;
    for (var cut = 0; cut <= full.length; cut++) {
      final frag = full.substring(0, cut);
      final ops = partialJsonArrayItems(frag, ['ops']).length;
      expect(ops, greaterThanOrEqualTo(lastOps), reason: 'ops count must never decrease at cut=$cut');
      lastOps = ops;
      // No parse of any prefix may throw — truncation is swallowed. 任何前缀都不得抛(截断被吞)。
      expect(() => partialJsonEvents(frag), returnsNormally);
    }
    expect(lastOps, 3); // all three ops complete in the full string
  });

  test('escapes are unescaped (n / t / quote / backslash / \\u)', () {
    final ev = partialJsonEvents(r'{"code":"a\nb\t\"c\\dA"}');
    final code = ev.firstWhere((e) => e.path.join() == 'code').value;
    expect(code, 'a\nb\t"c\\dA');
  });

  test('malformed input stops but keeps what already completed', () {
    // First op completes, then a garbage byte — the completed op survives. 首 op 完成,后遇垃圾→保留。
    final items = partialJsonArrayItems('{"ops":[{"op":"a"}, @bad', ['ops']);
    expect(items.length, 1);
    expect((items[0] as Map)['op'], 'a');
  });

  test('a partial string value does NOT complete (that is argStringPartial\'s job)', () {
    // The code string is still streaming → no [code] completion event. 流中字符串不发完成事件。
    expect(partialJsonEvents('{"code":"def foo():').where((e) => e.path.join() == 'code'), isEmpty);
  });

  test('facade path matching is exact (nested arrays do not leak)', () {
    final s = '{"a":{"ops":[1,2]},"ops":[9]}';
    expect(partialJsonArrayItems(s, ['ops']), [9]); // top-level ops only
    expect(partialJsonArrayItems(s, ['a', 'ops']), [1, 2]); // nested ops
    expect(_pathOf(s, 9), ['ops', 0]);
  });
}
