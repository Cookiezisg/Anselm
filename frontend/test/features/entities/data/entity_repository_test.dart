import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 1 gate — the transport rung end-to-end: LiveEntityRepository over a fake HttpClientAdapter (no
// server), proving each non-obvious decode against the EXACT backend envelope: rail rows from a bare
// list, the PageWithAggregate whose tally is NESTED under data.aggregates, the flowrun composite
// (nextCursor inside data), the bare un-enveloped run result, and the request paths/bodies the verbs send.

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
      lastBody = utf8.decode(chunks.expand((c) => c).toList());
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

({LiveEntityRepository repo, _FakeAdapter adapter}) _build(
    ResponseBody Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'));
  final adapter = _FakeAdapter(respond);
  dio.httpClientAdapter = adapter;
  final api = ApiClient(dio: dio, workspaceId: () => 'ws_1', authToken: () => 't');
  return (repo: LiveEntityRepository(api: api), adapter: adapter);
}

void main() {
  test('listEntities decodes a bare list into rows with kind-specific badges', () async {
    final b = _build((_) => _json({
          'data': [
            {
              'id': 'hd_1',
              'name': 'slack',
              'runtimeState': 'running',
              'configState': 'partially_configured',
              'missingConfig': ['token', 'channel'],
              'createdAt': '2026-06-26T00:00:00.000Z',
              'updatedAt': '2026-06-26T00:00:00.000Z',
            }
          ],
          'hasMore': false,
        }));
    final page = await b.repo.listEntities(EntityKind.handler, limit: 50);
    expect(b.adapter.last!.path, '/api/v1/handlers');
    expect(b.adapter.last!.queryParameters['limit'], 50);
    final row = page.items.single;
    expect(row.kind, EntityKind.handler);
    expect(row.runtimeState, 'running');
    expect(row.missingConfigCount, 2);
  });

  test('listFunctionExecutions decodes the tally NESTED under data.aggregates', () async {
    final b = _build((_) => _json({
          'data': {
            'executions': [
              {'id': 'x1', 'functionId': 'fn_1', 'status': 'ok', 'createdAt': '2026-06-26T00:00:00.000Z'}
            ],
            'aggregates': {'okCount': 5, 'failedCount': 2},
          },
          'nextCursor': 'c2',
          'hasMore': true,
        }));
    final page = await b.repo.listFunctionExecutions('fn_1', status: 'ok');
    expect(b.adapter.last!.path, '/api/v1/functions/fn_1/executions');
    expect(b.adapter.last!.queryParameters['status'], 'ok');
    expect(page.items.single.id, 'x1');
    expect(page.aggregate.okCount, 5);
    expect(page.aggregate.failedCount, 2);
    expect(page.isLastPage, isFalse);
  });

  test('getFlowrun decodes the composite (nextCursor lives INSIDE data)', () async {
    final b = _build((_) => _json({
          'data': {
            'flowrun': {
              'id': 'flr_1',
              'workflowId': 'wf_1',
              'status': 'running',
              'updatedAt': '2026-06-26T00:00:00.000Z',
            },
            'nodes': [
              {
                'id': 'frn_1',
                'flowrunId': 'flr_1',
                'nodeId': 'n1',
                'status': 'completed',
                'createdAt': '2026-06-26T00:00:00.000Z',
                'updatedAt': '2026-06-26T00:00:00.000Z',
              }
            ],
            'nextCursor': 'c2',
          },
        }));
    final comp = await b.repo.getFlowrun('flr_1');
    expect(b.adapter.last!.path, '/api/v1/flowruns/flr_1');
    expect(comp.flowrun.status, 'running');
    expect(comp.nodes.single.nodeId, 'n1');
    expect(comp.nextCursor, 'c2');
  });

  test('runFunction posts {args,version} to :run and decodes the BARE result', () async {
    final b = _build((_) => _json({'ok': true, 'output': 42, 'elapsedMs': 7}));
    final r = await b.repo.runFunction('fn_1', args: {'a': 1, 'b': 2}, version: 3);
    expect(b.adapter.last!.path, '/api/v1/functions/fn_1:run');
    final body = jsonDecode(b.adapter.lastBody!) as Map<String, dynamic>;
    expect(body['args'], {'a': 1, 'b': 2});
    expect(body['version'], 3);
    expect(r.ok, isTrue);
    expect(r.output, 42);
    expect(r.elapsedMs, 7);
  });

  test('triggerWorkflow posts {payload} to :trigger → async flowrun id', () async {
    final b = _build((_) => _json({'data': {'id': 'flr_9'}}, 202));
    final id = await b.repo.triggerWorkflow('wf_1', payload: {'k': 'v'});
    expect(b.adapter.last!.path, '/api/v1/workflows/wf_1:trigger');
    final body = jsonDecode(b.adapter.lastBody!) as Map<String, dynamic>;
    expect(body['payload'], {'k': 'v'});
    expect(id, 'flr_9');
  });

  test('signal streams are empty when no SSE gateway is wired', () async {
    final b = _build((_) => _json({'data': {}}));
    expect(await b.repo.lifecycleSignals(EntityKind.function).isEmpty, isTrue);
    expect(await b.repo.panelSignals(EntityKind.agent.scope('ag_1')).isEmpty, isTrue);
  });
}
