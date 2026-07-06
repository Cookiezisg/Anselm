import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:flutter_test/flutter_test.dart';

// F07 searchReceipt + parseSearchHits (WRK-056 §F07.5) — double wire shape (engine {count,total} /
// fallback {count}) + nil-slice defense + soft-string empty. F07 双形状 + nil 防御 + 软空串。

String _hits(int n) => '$n hits';
String _hitsTotal(int n, int t) => '$n of $t';
const _empty = 'empty';

ToolReceipt? r(String out, {String key = 'functions'}) =>
    searchReceipt(out, listKey: key, hits: _hits, hitsOfTotal: _hitsTotal, empty: _empty);

void main() {
  group('parseSearchHits — shape probing by key existence', () {
    test('engine path: has total → truncation known', () {
      final h = parseSearchHits(
          '{"count":20,"total":47,"functions":[{"id":"fn_1","name":"a"}]}', 'functions');
      expect(h!.count, 20);
      expect(h.total, 47);
      expect(h.items.length, 1);
    });

    test('fallback path: no total', () {
      final h = parseSearchHits('{"count":3,"functions":[{"id":"fn_1"},{"id":"fn_2"},{"id":"fn_3"}]}', 'functions');
      expect(h!.count, 3);
      expect(h.total, isNull);
      expect(h.items.length, 3);
    });

    test('nil-slice defense: count 0 with null list is a VALID empty', () {
      final h = parseSearchHits('{"count":0,"functions":null}', 'functions');
      expect(h!.count, 0);
      expect(h.items, isEmpty);
    });

    test('nil-slice defense: count 0 with the list key entirely absent is a valid empty', () {
      final h = parseSearchHits('{"count":0}', 'functions');
      expect(h!.count, 0);
    });

    test('broken shape: count>0 but list missing → null (never a phantom count)', () {
      expect(parseSearchHits('{"count":5}', 'functions'), isNull);
      expect(parseSearchHits('{"count":5,"functions":null}', 'functions'), isNull);
      expect(parseSearchHits('{"count":5,"functions":[]}', 'functions'), isNull);
    });

    test('no JSON / no int count → null', () {
      expect(parseSearchHits('not json', 'functions'), isNull);
      expect(parseSearchHits('{"functions":[]}', 'functions'), isNull); // no count
      expect(parseSearchHits('', 'functions'), isNull);
    });
  });

  group('searchReceipt — N / N·共M / empty', () {
    test('plain count', () {
      expect(r('{"count":12,"functions":[{"id":"a"}]}')!.text, '12 hits');
      expect(r('{"count":12,"functions":[{"id":"a"}]}')!.tone, ToolReceiptTone.none);
    });

    test('server-truncated → hitsOfTotal', () {
      expect(r('{"count":20,"total":47,"functions":[{"id":"a"}]}')!.text, '20 of 47');
    });

    test('total == count is NOT truncation (exact page)', () {
      expect(r('{"count":5,"total":5,"functions":[{"id":"a"}]}')!.text, '5 hits');
    });

    test('count 0 → honest empty (receipt IS the card, never falls through)', () {
      expect(r('{"count":0,"functions":null}')!.text, 'empty');
      expect(r('{"count":0,"functions":null}')!.tone, ToolReceiptTone.none);
    });

    test('search_blocks soft-empty string → empty', () {
      expect(r('No blocks matched "http retry". Try different keywords.', key: 'blocks')!.text, 'empty');
    });

    test('unparseable → null (never guess)', () {
      expect(r('garbage'), isNull);
      expect(r('{"count":9}'), isNull); // count claims hits, list missing → broken
    });
  });
}
