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

ResponseBody _json(
  Object body, [
  int status = 200,
  Map<String, List<String>> extraHeaders = const {},
]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...extraHeaders,
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

  test(
    'getPage reads entity total from response metadata, not the N4 body',
    () async {
      final b = _build(
        (_) => _json(
          {
            'data': [
              {'n': 1},
            ],
            'hasMore': true,
          },
          200,
          {
            'X-Anselm-Total-Count': ['45'],
          },
        ),
      );
      final page = await b.client.getPage('/agents', (m) => m['n'] as int);
      expect(page.total, 45);
      expect(page.items, [1]);
    },
  );

  test('postForId returns data.id (202 async action)', () async {
    final b = _build(
      (_) => _json({
        'data': {'id': 'run_9'},
      }, 202),
    );
    final id = await b.client.postForId('/workflows/wf_1:trigger');
    expect(id, 'run_9');
  });

  // `postBare` is GONE (WRK-083 L14). It existed for the three synchronous executors
  // (`:run`/`:call`/`:invoke`) on the belief that they answer un-enveloped — they do not; N1 admits no
  // exception. The test that used to sit here fed itself a hand-made bare body and then asserted the
  // body was bare: it never asked what the server sends, so it could not fail, and it made the loaded
  // gun look covered. The executors now read `postData` like everything else.
  // `postBare` **已删**(WRK-083 L14)。它是为三个同步执行器(`:run`/`:call`/`:invoke`)而存在的,前提是
  // 它们答**不裹信封**——并非如此,N1 不认这种例外。原本站在这里的测试**喂自己一个手造的裸 body、再断言 body
  // 是裸的**:它从没问过服务器发的是什么,所以它不可能失败,却让那把上膛的枪看起来是被覆盖的。执行器现在与其他
  // 一切一样走 `postData`。

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
    'raw byte error envelope stays typed instead of becoming CLIENT_UNKNOWN',
    () async {
      final b = _build(
        (_) => _json({
          'error': {
            'code': 'SKILL_FILE_TOO_LARGE',
            'message': 'skill file exceeds size limit',
          },
        }, 422),
      );
      expect(
        () => b.client.getBytes('/skills/example/files/oversize.md'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'SKILL_FILE_TOO_LARGE')
              .having((e) => e.httpStatus, 'httpStatus', 422),
        ),
      );
    },
  );

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
