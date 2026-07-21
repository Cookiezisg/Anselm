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
    expect(byPath[''], {
      'name': 'foo',
      'n': 3,
      'ok': true,
    }); // the root container
  });

  test(
    'nested paths + completion order (innermost closes first, root last)',
    () {
      final ev = partialJsonEvents('{"a":{"b":1}}');
      expect(ev.map((e) => e.path.join('/')).toList(), ['a/b', 'a', '']);
      expect(ev.first.value, 1);
      expect(ev.last.value, {
        'a': {'b': 1},
      });
    },
  );

  test('array elements carry int indices, in source order', () {
    final items = partialJsonArrayItems(
      '{"ops":[{"op":"add_node","id":"a"},{"op":"add_edge"}]}',
      ['ops'],
    );
    expect(items.length, 2);
    expect((items[0] as Map)['op'], 'add_node');
    expect((items[1] as Map)['op'], 'add_edge');
  });

  test(
    'truncation: only COMPLETED array elements surface (never a partial one)',
    () {
      // Second op is cut off mid-object → only the first completed op is reported. 第二个 op 截断→只报第一个。
      final items = partialJsonArrayItems(
        '{"ops":[{"op":"add_node","id":"a"},{"op":"add_e',
        ['ops'],
      );
      expect(items.length, 1);
      expect((items[0] as Map)['id'], 'a');
    },
  );

  test(
    'a bare number at end-of-input is INCOMPLETE (12 could still become 123)',
    () {
      // {"n":12  — the 12 hasn't closed, so [n] is not emitted; a closed one is. 到尾数字不发。
      expect(
        partialJsonEvents('{"n":12').where((e) => e.path.join() == 'n'),
        isEmpty,
      );
      expect(
        partialJsonEvents(
          '{"n":12}',
        ).where((e) => e.path.join() == 'n').single.value,
        12,
      );
    },
  );

  test('MONOTONICITY: feeding growing prefixes never un-completes a value', () {
    const full =
        '{"name":"quarterly_rollup","ops":[{"op":"set_meta"},{"op":"add_node","id":"n1"},'
        '{"op":"add_edge","from":"n1","to":"n2"}],"concurrency":4}';
    var lastOps = 0;
    for (var cut = 0; cut <= full.length; cut++) {
      final frag = full.substring(0, cut);
      final ops = partialJsonArrayItems(frag, ['ops']).length;
      expect(
        ops,
        greaterThanOrEqualTo(lastOps),
        reason: 'ops count must never decrease at cut=$cut',
      );
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

  test(
    'a partial string value does NOT complete (that is argStringPartial\'s job)',
    () {
      // The code string is still streaming → no [code] completion event. 流中字符串不发完成事件。
      expect(
        partialJsonEvents(
          '{"code":"def foo():',
        ).where((e) => e.path.join() == 'code'),
        isEmpty,
      );
    },
  );

  test('facade path matching is exact (nested arrays do not leak)', () {
    final s = '{"a":{"ops":[1,2]},"ops":[9]}';
    expect(partialJsonArrayItems(s, ['ops']), [9]); // top-level ops only
    expect(partialJsonArrayItems(s, ['a', 'ops']), [1, 2]); // nested ops
    expect(_pathOf(s, 9), ['ops', 0]);
  });

  // ── PartialJsonSession — the incremental engine (WRK-061 W0) ────────────────────────────────────
  // Batteries: chunking equivalence (any split == one-shot), no re-emission, the path-aware in-flight
  // string channel, boundary-straddling escapes/numbers/keywords, malformed freeze, memoization, perf.
  // 增量会话电池:任意切分等价/不重发/带路径在途通道/跨界转义/畸形冻结/记忆化/性能界。

  group('PartialJsonSession', () {
    const corpus = [
      '{"name":"foo","n":3,"ok":true}',
      '{"a":{"b":1}}',
      '{"ops":[{"op":"add_node","id":"a"},{"op":"add_edge"}],"concurrency":4}',
      '{"a":[],"b":{},"c":[[]],"d":[{"e":null}]}',
      r'{"code":"a\nb\t\"c\\dA"}',
      '{"n":-12.5e+3,"m":0}',
      '  [true, false, null, "x", 7]  ',
      '{"ops":[{"op":"a"}, @bad',
      '{"code":"def foo():',
      '{"n":12',
      '{"k":tru',
      '',
    ];

    test('EQUIVALENCE: any chunking of any fragment == the one-shot parse', () {
      for (final s in corpus) {
        final oneShot = partialJsonEvents(s);
        for (final chunk in [1, 2, 3, 7, 16]) {
          final sess = PartialJsonSession();
          for (var i = 0; i < s.length; i += chunk) {
            sess.append(
              s.substring(i, i + chunk > s.length ? s.length : i + chunk),
            );
          }
          expect(
            sess.events.length,
            oneShot.length,
            reason: 'len mismatch for "$s" chunk=$chunk',
          );
          for (var k = 0; k < oneShot.length; k++) {
            expect(
              sess.events[k].path,
              oneShot[k].path,
              reason: 'path[$k] for "$s" chunk=$chunk',
            );
            expect(
              sess.events[k].value,
              oneShot[k].value,
              reason: 'value[$k] for "$s" chunk=$chunk',
            );
          }
        }
      }
    });

    test(
      'NO RE-EMISSION: a consumer cursor sees each completion exactly once',
      () {
        const s = '{"ops":[{"op":"a"},{"op":"b"},{"op":"c"}]}';
        final sess = PartialJsonSession();
        var cursor = 0;
        final seen = <String>[];
        for (var i = 0; i < s.length; i += 5) {
          sess.append(s.substring(i, i + 5 > s.length ? s.length : i + 5));
          for (; cursor < sess.events.length; cursor++) {
            seen.add(sess.events[cursor].path.join('/'));
          }
        }
        // Every completion appears once — three elements, three op strings, the array, the root.
        expect(seen, [
          'ops/0/op',
          'ops/0',
          'ops/1/op',
          'ops/1',
          'ops/2/op',
          'ops/2',
          'ops',
          '',
        ]);
      },
    );

    test(
      'in-flight channel: the open string value surfaces with its full path',
      () {
        final sess = PartialJsonSession()..append('{"code":"def foo(');
        expect(sess.inFlightString!.path, ['code']);
        expect(sess.inFlightString!.text, 'def foo(');
        expect(sess.inFlightStringAt(['code']), 'def foo(');
        expect(sess.inFlightStringAt(['other']), isNull);
      },
    );

    test(
      'in-flight channel: same-key values are told apart by path (handler multi-method body)',
      () {
        final sess = PartialJsonSession()
          ..append(
            '{"ops":[{"method":{"name":"a","body":"AAA"}},{"method":{"name":"b","body":"BB',
          );
        expect(sess.inFlightString!.path, ['ops', 1, 'method', 'body']);
        expect(sess.inFlightString!.text, 'BB');
        expect(
          sess.inFlightStringAt(['ops', 0, 'method', 'body']),
          isNull,
        ); // that one CLOSED
        expect(sess.inFlightStringAt(['ops', 1, 'method', 'body']), 'BB');
      },
    );

    test('in-flight channel: keys never surface; closing flips to null', () {
      final sess = PartialJsonSession()..append('{"lo');
      expect(sess.inFlightString, isNull); // an open KEY is not a value 键不上通道
      sess.append('ng_key":"v"');
      expect(sess.inFlightString, isNull); // value closed 值已闭
      expect(sess.events.single.value, 'v');
    });

    test(
      'in-flight text is decoded, and a pending escape is withheld until resolved',
      () {
        final sess = PartialJsonSession()..append(r'{"c":"a\nb');
        expect(sess.inFlightString!.text, 'a\nb');
        sess.append('\\'); // lone trailing backslash — undecidable yet 悬空反斜杠
        expect(sess.inFlightString!.text, 'a\nb');
        sess.append('t');
        expect(sess.inFlightString!.text, 'a\nb\t');
      },
    );

    test(
      'boundary straddles: \\uXXXX, surrogate pair, number, keyword split across appends',
      () {
        final u = PartialJsonSession()
          ..append(r'{"c":"\u00')
          ..append('41"}');
        expect(u.events.first.value, 'A');

        final emoji = PartialJsonSession()
          ..append(r'{"c":"\ud83d')
          ..append(r'\ude00"}');
        expect(emoji.events.first.value, '😀');

        final n = PartialJsonSession()
          ..append('{"n":12')
          ..append('3}');
        expect(n.events.first.value, 123);

        final k = PartialJsonSession()
          ..append('{"k":tr')
          ..append('ue}');
        expect(k.events.first.value, true);
      },
    );

    test(
      'malformed freezes the session but keeps completions; further input is ignored',
      () {
        final sess = PartialJsonSession()..append('{"a":1, @');
        expect(sess.malformed, isTrue);
        final kept = sess.events.length;
        sess.append('"b":2}');
        expect(sess.events.length, kept);
        expect(sess.events.first.value, 1);
        expect(sess.inFlightString, isNull);
      },
    );

    test(
      'done: root close ends the session; trailing input is ignored (facade semantics)',
      () {
        final sess = PartialJsonSession()..append('{"a":1} trailing garbage');
        expect(sess.done, isTrue);
        expect(sess.events.last.value, {'a': 1});
        sess.append('{"more":2}');
        expect(sess.events.length, 2); // a + root only
      },
    );

    test('memoization: unchanged in-flight text is not re-materialized', () {
      final sess = PartialJsonSession()..append('{"c":"abc');
      final a = sess.inFlightString!.text;
      final b = sess.inFlightString!.text;
      expect(identical(a, b), isTrue); // same length → cached instance 同长→同实例
      sess.append('d');
      expect(sess.inFlightString!.text, 'abcd');
    });

    test(
      'PERF: 1MB value streamed in 4KB deltas with per-delta in-flight reads stays cheap',
      () {
        final chunk = 'x' * 4096;
        final sess = PartialJsonSession()..append('{"content":"');
        final sw = Stopwatch()..start();
        for (var i = 0; i < 256; i++) {
          sess.append(chunk);
          sess.inFlightString; // the live window reads every frame 活窗每帧读
        }
        sw.stop();
        expect(sess.inFlightString!.path, ['content']);
        expect(sess.inFlightString!.text.length, 256 * 4096);
        // O(delta) per append: the whole 1MB stream must land far under one second even on CI.
        // 每次 append O(delta):1MB 全程远低于 1 秒。旧引擎(整段重扫)在此量级是分钟级。
        expect(
          sw.elapsedMilliseconds,
          lessThan(1000),
          reason: 'incremental feed must be O(delta)',
        );
      },
    );
  });
}
