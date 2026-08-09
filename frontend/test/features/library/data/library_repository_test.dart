import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? last;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      lastBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    }
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

({LiveLibraryRepository repo, _FakeAdapter adapter}) _build(
  ResponseBody Function(RequestOptions) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'));
  final adapter = _FakeAdapter(respond);
  dio.httpClientAdapter = adapter;
  final api = ApiClient(
    dio: dio,
    workspaceId: () => 'ws_1',
    authToken: () => 'token_1',
  );
  return (repo: LiveLibraryRepository(api), adapter: adapter);
}

void main() {
  test(
    'iterateDocument posts the exact action path and request body',
    () async {
      final b = _build(
        (_) => _json({
          'data': {'id': 'cv_doc_0011223344556677_iterate'},
        }, 202),
      );

      final id = await b.repo.iterateDocument(
        'doc_0011223344556677',
        request: 'Help me edit the introduction',
      );

      expect(id, 'cv_doc_0011223344556677_iterate');
      expect(b.adapter.last?.method, 'POST');
      expect(
        b.adapter.last?.path,
        '/api/v1/documents/doc_0011223344556677:iterate',
      );
      expect(jsonDecode(b.adapter.lastBody!), {
        'request': 'Help me edit the introduction',
      });
      expect(b.adapter.last?.headers['X-Anselm-Workspace-ID'], 'ws_1');
      expect(b.adapter.last?.headers['Authorization'], 'Bearer token_1');
    },
  );
}
