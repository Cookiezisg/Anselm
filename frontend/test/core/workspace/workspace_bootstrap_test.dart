import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/workspace/workspace_bootstrap.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Cold-start gate — use the first workspace if any; an empty roster is server truth that holds the
// shell on onboarding until the user explicitly creates one.
// 冷启动 gate:有行取首行;空名册是服务端真相,壳停在 onboarding,直到用户显式创建。

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? lastPost;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? c,
  ) async {
    if (o.method == 'POST') lastPost = o;
    return respond(o);
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

ProviderContainer _container(ResponseBody Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'));
  dio.httpClientAdapter = _FakeAdapter(respond);
  final api = ApiClient(
    dio: dio,
    workspaceId: () => null,
    authToken: () => null,
  );
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api)],
  );
  addTearDown(c.dispose);
  return c;
}

Map<String, dynamic> _ws(String id, String name) => {
  'id': id,
  'name': name,
  'language': 'en',
  'createdAt': '2026-06-26T00:00:00.000Z',
  'updatedAt': '2026-06-26T00:00:00.000Z',
};

void main() {
  test('uses the first existing workspace + sets it active', () async {
    final c = _container(
      (o) => _json({
        'data': [_ws('ws_1', 'Personal'), _ws('ws_2', 'Work')],
      }),
    );
    final id = await c.read(workspaceBootstrapProvider.future);
    expect(id, 'ws_1');
    expect(c.read(activeWorkspaceProvider), 'ws_1');
  });

  test(
    'no workspace → waits for onboarding; explicit create settles the axis',
    () async {
      var posts = 0;
      final c = _container((o) {
        if (o.method == 'POST') {
          posts++;
          return _json({'data': _ws('ws_new', 'Fresh')}, 201);
        }
        return _json({'data': const []});
      });
      final id = await c.read(workspaceBootstrapProvider.future);
      expect(id, isNull);
      expect(posts, 0, reason: 'empty server truth must never silently POST');
      expect(c.read(activeWorkspaceProvider), isNull);

      final row = await c
          .read(workspaceBootstrapProvider.notifier)
          .create('Fresh');
      expect(row.id, 'ws_new');
      expect(posts, 1);
      expect(c.read(activeWorkspaceProvider), 'ws_new');
      expect(c.read(activeWorkspaceNameProvider), 'Fresh');
      expect(c.read(workspaceBootstrapProvider).value, 'ws_new');
    },
  );
}
