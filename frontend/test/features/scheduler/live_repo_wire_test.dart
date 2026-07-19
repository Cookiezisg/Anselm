import 'dart:convert';
import 'dart:typed_data';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wire-shape lock for the Live repository — the seam every other scheduler test bypasses.
///
/// This exists because of a bug that reached the REAL app (0717): `workflowTriggerEdges` sent
/// `fromKind=workflow&toKind=trigger` with no ids, the backend's validateFilter requires kind/id in
/// PAIRS, so the call 400'd and took the whole Overview down — while every fixture-seam test and all
/// of testend stayed green (neither exercises this wire). The lock is therefore on the REQUEST SHAPE
/// itself: kind=equip only, never a kind-only from/to pair.
///
/// Live 仓库的线缆形锁——其他所有 scheduler 测试都绕过的那道缝。真机 0717 现形的 400(成对校验)曾拖死
/// 整个 Overview,而 fixture 缝与 testend 全绿。故锁**请求形**本身:只发 kind=equip,绝不发无 id 的
/// from/to 对。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data) => ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  ({LiveSchedulerRepository repo, _FakeAdapter adapter}) build(
    ResponseBody Function(RequestOptions) respond,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/'));
    final adapter = _FakeAdapter(respond);
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio: dio, workspaceId: () => 'ws_1', authToken: () => null);
    return (repo: LiveSchedulerRepository(client), adapter: adapter);
  }

  Map<String, dynamic> edge(String id, String fromKind, String toKind) => {
        'id': id,
        'kind': 'equip',
        'fromKind': fromKind,
        'fromId': '${fromKind}_1',
        'fromName': fromKind,
        'toKind': toKind,
        'toId': '${toKind}_1',
        'toName': toKind,
      };

  test('workflowTriggerEdges sends kind=equip ONLY — a kind-only from/to pair is a backend 400', () async {
    final b = build((o) => _json([
          edge('rel_1', 'workflow', 'trigger'),
          edge('rel_2', 'agent', 'function'), // must be narrowed away client-side. 客户端须滤掉。
          edge('rel_3', 'workflow', 'trigger'),
        ]));

    final edges = await b.repo.workflowTriggerEdges();

    final q = b.adapter.requests.single.queryParameters;
    expect(q['kind'], 'equip');
    // The exact keys the backend rejects when unpaired — locked to NEVER reappear.
    // 后端对无 id 的 from/to 判 400 —— 锁死这些键永不再出现。
    expect(q.containsKey('fromKind'), isFalse,
        reason: 'fromKind 无 fromId = validateFilter 成对校验 400(真机 0717 的事故形)');
    expect(q.containsKey('toKind'), isFalse);

    expect(edges.map((e) => e.id), ['rel_1', 'rel_3'],
        reason: '客户端收窄只留 workflow→trigger,非 workflow 边不得漏入甘特连线');
  });

  test('runMatrix sends ONE flowrunIds csv — never recentN/workflowId (0717 主页重建线缆形)',
      () async {
    final b = build((o) => _json({'cols': [], 'rows': [], 'cells': []}));
    await b.repo.runMatrix(['fr_a', 'fr_b', 'fr_c']);
    final q = b.adapter.requests.single.queryParameters;
    expect(b.adapter.requests.single.path, contains('/flowrun-matrix'));
    expect(q['flowrunIds'], 'fr_a,fr_b,fr_c', reason: 'csv 一次批查');
    expect(q.containsKey('recentN'), isFalse, reason: 'recentN 模式已按 #7 整体删除');
    expect(q.containsKey('workflowId'), isFalse, reason: '端点不再有 workflow 轴——内容就是 ids');
  });

  test('listFlowruns serializes the time window as RFC3339 UTC (picker absolute range wire form)',
      () async {
    final b = build((o) => _json(<dynamic>[]));
    await b.repo.listFlowruns(
      workflowId: 'wf_1',
      startedAfter: DateTime(2026, 6, 1, 9, 0),
      startedBefore: DateTime(2026, 7, 1, 0, 0),
    );
    final q = b.adapter.requests.single.queryParameters;
    // Local wall-clock picks must reach the wire as UTC with the Z suffix — a local
    // toIso8601String has NO offset marker and would be a contract accident.
    // 本地墙钟选择上线缆必须转 UTC 带 Z 后缀——本地 toIso8601String 不带时区标记,发出去就是契约事故。
    expect(q['startedAfter'], endsWith('Z'), reason: 'RFC3339 UTC,绝不发无时区的本地串');
    expect(q['startedBefore'], endsWith('Z'));
    expect(DateTime.parse(q['startedAfter']!), DateTime(2026, 6, 1, 9, 0).toUtc());
  });
}
