import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/net/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 2 gate — the net layer encodes the envelope/pagination/error contract once and
// attaches the workspace + bearer headers. Driven through a fake HttpClientAdapter (no
// real server, no extra dep), which also captures the outgoing request for header asserts.

/// A canned-response adapter that records the last request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({ApiClient client, _FakeAdapter adapter}) _build(
  ResponseBody Function(RequestOptions) respond, {
  String? ws = 'ws_1',
  String? token = 'tok_abc',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'));
  final adapter = _FakeAdapter(respond);
  dio.httpClientAdapter = adapter;
  final client = ApiClient(
    dio: dio,
    workspaceId: () => ws,
    authToken: () => token,
  );
  return (client: client, adapter: adapter);
}

void main() {
  test('getEntity unwraps {data:<obj>}', () async {
    final b = _build(
      (_) => _json({
        'data': {'id': 'fn_1', 'name': 'norm'},
      }),
    );
    final got = await b.client.getEntity(
      '/functions/fn_1',
      (m) => m['name'] as String,
    );
    expect(got, 'norm');
  });

  test('getPage parses {data:[…],nextCursor,hasMore}', () async {
    final b = _build(
      (_) => _json({
        'data': [
          {'n': 1},
          {'n': 2},
        ],
        'nextCursor': 'c2',
        'hasMore': true,
      }),
    );
    final page = await b.client.getPage('/functions', (m) => m['n'] as int);
    expect(page.items, [1, 2]);
    expect(page.nextCursor, 'c2');
    expect(page.isLastPage, isFalse);
  });

  test('postForId returns data.id (202 async action)', () async {
    final b = _build(
      (_) => _json({
        'data': {'id': 'run_9'},
      }, 202),
    );
    final id = await b.client.postForId('/workflows/wf_1:trigger');
    expect(id, 'run_9');
  });

  test('postBare returns the bare (unwrapped) result', () async {
    final b = _build((_) => _json({'ok': true, 'out': 42}));
    final r =
        await b.client.postBare('/functions/fn_1:run') as Map<String, dynamic>;
    expect(r['out'], 42);
  });

  test('error envelope → typed ApiException (code + status)', () async {
    final b = _build(
      (_) => _json({
        'error': {'code': 'WORKFLOW_INVALID_GRAPH', 'message': 'bad graph'},
      }, 409),
    );
    expect(
      () => b.client.getEntity('/workflows/wf_1', (m) => m),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'WORKFLOW_INVALID_GRAPH')
            .having((e) => e.httpStatus, 'httpStatus', 409)
            .having((e) => e.isConflict, 'isConflict', true),
      ),
    );
  });

  test(
    'transport failure (no response) → ApiException.transport (status 0)',
    () async {
      final b = _build((_) => throw Exception('connection refused'));
      expect(
        () => b.client.getData('/health'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isTransport, 'isTransport', true)
              .having((e) => e.httpStatus, 'httpStatus', 0),
        ),
      );
    },
  );

  test(
    'interceptor attaches X-Anselm-Workspace-ID + Authorization: Bearer',
    () async {
      final b = _build(
        (_) => _json({
          'data': {'status': 'ok'},
        }),
      );
      await b.client.getData('/health');
      expect(b.adapter.last!.headers['X-Anselm-Workspace-ID'], 'ws_1');
      expect(b.adapter.last!.headers['Authorization'], 'Bearer tok_abc');
    },
  );

  test(
    'no workspace / no token → headers omitted (not empty strings)',
    () async {
      final b = _build(
        (_) => _json({
          'data': {'status': 'ok'},
        }),
        ws: null,
        token: '',
      );
      await b.client.getData('/health');
      expect(
        b.adapter.last!.headers.containsKey('X-Anselm-Workspace-ID'),
        isFalse,
      );
      expect(b.adapter.last!.headers.containsKey('Authorization'), isFalse);
    },
  );
}
