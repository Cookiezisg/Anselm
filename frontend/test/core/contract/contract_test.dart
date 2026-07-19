import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/page.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 1 gate — the contract layer mirrors the backend N1 envelope / N4 paging / DTO wire
// EXACTLY. These are the round-trip + parse goldens the rest of 4.0 builds on.
void main() {
  group('ApiException (N1 error envelope)', () {
    test('fromEnvelope maps code/message/details + status', () {
      final e = ApiException.fromEnvelope(
        {'code': 'WORKFLOW_INVALID_GRAPH', 'message': 'bad graph', 'details': {'node': 'n1'}},
        409,
      );
      expect(e.code, 'WORKFLOW_INVALID_GRAPH');
      expect(e.message, 'bad graph');
      expect(e.httpStatus, 409);
      expect(e.details, {'node': 'n1'});
      expect(e.isConflict, isTrue);
    });

    test('missing code → CLIENT_UNKNOWN; null body tolerated', () {
      final e = ApiException.fromEnvelope(null, 500);
      expect(e.code, AnselmErr.unknown);
      expect(e.message, isNotEmpty);
      expect(e.httpStatus, 500);
    });

    test('transport() = httpStatus 0 + CLIENT_TRANSPORT', () {
      final e = ApiException.transport('connection refused');
      expect(e.code, AnselmErr.transport);
      expect(e.httpStatus, 0);
      expect(e.isTransport, isTrue);
    });

    test('status predicates', () {
      expect(ApiException.fromEnvelope(const {}, 410).isGone, isTrue);
      expect(ApiException.fromEnvelope(const {}, 401).isUnauthorized, isTrue);
      expect(ApiException.fromEnvelope(const {}, 404).isNotFound, isTrue);
    });

    test('the curated codes the new 4.0 flows branch on exist', () {
      expect(AnselmErr.unauthNoWorkspace, 'UNAUTH_NO_WORKSPACE');
      expect(AnselmErr.unauthBadToken, 'UNAUTH_BAD_TOKEN'); // loopback hardening
      expect(AnselmErr.seqTooOld, 'SEQ_TOO_OLD'); // SSE resume
    });
  });

  group('Page (N4 keyset paging — coords TOP-level, never inside data)', () {
    int item(Map<String, dynamic> m) => m['n'] as int;

    test('normal page: hasMore + nextCursor → not last', () {
      final p = Page.fromBody({
        'data': [{'n': 1}, {'n': 2}],
        'nextCursor': 'c2',
        'hasMore': true,
      }, item);
      expect(p.items, [1, 2]);
      expect(p.nextCursor, 'c2');
      expect(p.isLastPage, isFalse);
    });

    test('last page: nextCursor absent + hasMore false → isLastPage', () {
      final p = Page.fromBody({'data': [{'n': 9}], 'hasMore': false}, item);
      expect(p.nextCursor, isNull);
      expect(p.isLastPage, isTrue);
    });

    test('empty page: {data:[]} → empty, last', () {
      final p = Page.fromBody({'data': const [], 'hasMore': false}, item);
      expect(p.items, isEmpty);
      expect(p.isLastPage, isTrue);
    });

    test('isLastPage also true when hasMore but nextCursor missing (defensive)', () {
      final p = Page.fromBody({'data': const [], 'hasMore': true}, item);
      expect(p.isLastPage, isTrue);
    });
  });

  group('PageWithAggregate (data is object: list + aggregate sidecar)', () {
    test('parses list-under-key + aggregate + top-level paging', () {
      final p = PageWithAggregate<int, int>.fromBody(
        {
          'data': {
            'executions': [{'n': 1}, {'n': 2}, {'n': 3}],
            'total': 42,
          },
          'nextCursor': 'c3',
          'hasMore': true,
        },
        'executions',
        (m) => m['n'] as int,
        (data) => data['total'] as int,
      );
      expect(p.items, [1, 2, 3]);
      expect(p.aggregate, 42);
      expect(p.nextCursor, 'c3');
      expect(p.isLastPage, isFalse);
    });
  });

  group('DTO round-trip (camelCase wire ↔ json_serializable, no rename maps)', () {
    test('ModelRef fromJson/toJson + options default', () {
      const ref = ModelRef(apiKeyId: 'key_1', modelId: 'deepseek-v4-flash');
      final json = ref.toJson();
      expect(json['apiKeyId'], 'key_1');
      expect(ModelRef.fromJson(json), ref);
      // options defaults to empty map when absent
      final parsed = ModelRef.fromJson({'apiKeyId': 'k', 'modelId': 'm'});
      expect(parsed.options, isEmpty);
    });

    test('Workspace round-trips required + optional fields', () {
      final json = {
        'id': 'ws_abc',
        'name': 'Personal',
        'language': 'zh-CN',
        'defaultDialogue': {'apiKeyId': 'k', 'modelId': 'm', 'options': <String, String>{}},
        'createdAt': '2026-06-26T00:00:00.000Z',
        'updatedAt': '2026-06-26T01:00:00.000Z',
      };
      final ws = Workspace.fromJson(json);
      expect(ws.id, 'ws_abc');
      expect(ws.language, 'zh-CN');
      expect(ws.defaultDialogue?.modelId, 'm');
      // round-trip preserves identity
      expect(Workspace.fromJson(ws.toJson()), ws);
    });
  });
}
