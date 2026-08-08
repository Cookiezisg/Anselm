import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _CallsAdapter implements HttpClientAdapter {
  _CallsAdapter(this.body);

  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('MCP call aggregates decode from the nested data sidecar', () async {
    final adapter = _CallsAdapter({
      'data': {
        'calls': [
          {
            'id': 'mcl_1',
            'tool': 'call_fixture',
            'status': 'ok',
            'triggeredBy': 'manual',
            'elapsedMs': 3,
          },
        ],
        'aggregates': {'totalCount': 2, 'okCount': 1, 'failedCount': 1},
      },
      'hasMore': false,
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'))
      ..httpClientAdapter = adapter;
    final repo = LiveSettingsRepository(
      api: ApiClient(
        dio: dio,
        workspaceId: () => 'ws_1',
        authToken: () => null,
      ),
      workspaceId: () => 'ws_1',
    );

    final page = await repo.listMcpCalls('ep126-calls');

    expect(page.calls.single.tool, 'call_fixture');
    expect(page.okCount, 1);
    expect(page.failedCount, 1);
    expect(page.nextCursor, isNull);
    expect(adapter.last?.path, '/api/v1/mcp-servers/ep126-calls/calls');
  });
}
