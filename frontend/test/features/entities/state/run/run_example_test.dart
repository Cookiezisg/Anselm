import 'dart:convert';

import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/features/entities/state/run/run_example.dart';
import 'package:flutter_test/flutter_test.dart';

// The example generator (v3 JSON-first, 0719 拍板) — the matrix lock: precedence (example → default →
// enum-first → type skeleton), the coarse-type skeletons, recursion (nested object / array items), the
// fn/hd/ag Field adapter, and the workflow per-source fire-payload templates. Pure functions, so the
// ladder can never silently rot.

void main() {
  group('exampleValue precedence', () {
    test('example wins over everything', () {
      expect(
        exampleValue(const ExampleNode(
          type: 'string',
          example: 'hi',
          defaultValue: 'def',
          enumValues: ['a', 'b'],
        )),
        'hi',
      );
    });

    test('default wins when no example', () {
      expect(
        exampleValue(const ExampleNode(type: 'number', defaultValue: 42, enumValues: [1, 2])),
        42,
      );
    });

    test('enum-first wins when no example/default', () {
      expect(exampleValue(const ExampleNode(type: 'string', enumValues: ['red', 'green'])), 'red');
    });

    test('empty enum falls through to the type skeleton', () {
      expect(exampleValue(const ExampleNode(type: 'string', enumValues: [])), '');
    });
  });

  group('type skeletons', () {
    test('string → empty string', () => expect(exampleValue(const ExampleNode(type: 'string')), ''));
    test('number → 0', () => expect(exampleValue(const ExampleNode(type: 'number')), 0));
    test('boolean → false', () => expect(exampleValue(const ExampleNode(type: 'boolean')), false));
    test('object (no props) → {}', () => expect(exampleValue(const ExampleNode(type: 'object')), <String, Object?>{}));
    test('array (no items) → []', () => expect(exampleValue(const ExampleNode(type: 'array')), <Object?>[]));
    test('unknown type → null (honest, not a fake scalar)',
        () => expect(exampleValue(const ExampleNode(type: 'weird')), isNull));
  });

  group('recursion', () {
    test('nested object descends per-property', () {
      final v = exampleValue(const ExampleNode(type: 'object', properties: {
        'name': ExampleNode(type: 'string'),
        'age': ExampleNode(type: 'number'),
        'flags': ExampleNode(type: 'object', properties: {'on': ExampleNode(type: 'boolean')}),
      }));
      expect(v, {
        'name': '',
        'age': 0,
        'flags': {'on': false},
      });
    });

    test('array yields a single-element sample of its item node', () {
      expect(
        exampleValue(const ExampleNode(type: 'array', items: ExampleNode(type: 'string', example: 'x'))),
        ['x'],
      );
    });
  });

  group('fn/hd/ag Field adapter (type skeleton — the contract carries no example/default/enum)', () {
    test('a mixed field list → its top-level skeleton object', () {
      final fields = const [
        Field(name: 'text', type: 'string', description: 'raw input'),
        Field(name: 'limit', type: 'number'),
        Field(name: 'strict', type: 'boolean'),
        Field(name: 'options', type: 'object'),
        Field(name: 'tags', type: 'array'),
      ];
      expect(exampleForFields(fields), {
        'text': '',
        'limit': 0,
        'strict': false,
        'options': <String, Object?>{},
        'tags': <Object?>[],
      });
    });

    test('empty fields → empty object; the JSON seed is valid + runnable', () {
      expect(exampleForFields(const []), <String, Object?>{});
      expect(exampleJsonForFields(const []), '{}');
      // Round-trips as a JSON object (the coerce contract). 可作 JSON 对象回环。
      final decoded = jsonDecode(exampleJsonForFields(const [Field(name: 'a', type: 'string')]));
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map)['a'], '');
    });
  });

  group('workflow per-source templates (verbatim backend fire payloads)', () {
    final now = DateTime.utc(2026, 7, 19, 2);
    final iso = now.toIso8601String();

    test('cron → {firedAt} only (NOT {firedAt, schedule} — the real cron payload)', () {
      expect(workflowPayloadTemplate('cron', now: now), {'firedAt': iso});
    });

    test('webhook → {firedAt, method, path, headers, body}', () {
      expect(workflowPayloadTemplate('webhook', now: now), {
        'firedAt': iso,
        'method': 'POST',
        'path': '/webhooks/example',
        'headers': <String, Object?>{},
        'body': <String, Object?>{},
      });
    });

    test('fsnotify → {firedAt, path, eventKind}', () {
      expect(workflowPayloadTemplate('fsnotify', now: now), {
        'firedAt': iso,
        'path': '/path/to/file',
        'eventKind': 'modify',
      });
    });

    test('sensor → {value} (CEL output wrapped)', () {
      expect(workflowPayloadTemplate('sensor', now: now), {'value': 0});
    });

    test('manual → a free empty object', () {
      expect(workflowPayloadTemplate('manual', now: now), <String, Object?>{});
    });

    test('the JSON seed is a valid object for every source', () {
      for (final k in ['cron', 'webhook', 'fsnotify', 'sensor', 'manual']) {
        final decoded = jsonDecode(workflowPayloadTemplateJson(k, now: now));
        expect(decoded, isA<Map<String, dynamic>>(), reason: k);
      }
    });
  });
}
