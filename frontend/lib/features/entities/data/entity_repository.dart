import 'dart:async';

import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/common.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';
import 'entity_kind.dart';
import 'entity_row.dart';
import 'entity_signal.dart';

/// THE seam for the Entities feature's data access — every read/execute/realtime call the feature makes
/// passes through here, so the whole feature can be driven by one [FixtureEntityRepository] override (no
/// per-provider SSE/HTTP mocking). [LiveEntityRepository] wires the Phase-4.0 pipeline (ApiClient +
/// SseGateway); the fixture is in-memory + scriptable. Reads come in three shapes the backend actually
/// serves: bare-entity gets, N4 [Page] lists, and the [PageWithAggregate] log pages.
///
/// Entities feature 数据访问的唯一缝——feature 的每个读/执行/实时调用都过此,故整 feature 可被单个
/// fixture override 驱动。Live 接 Phase 4.0 管道,fixture 内存 + 可脚本化。
abstract interface class EntityRepository {
  // ── rail / list (uniform row across all 4 kinds) ──────────────────────────
  Future<Page<EntityRow>> listEntities(EntityKind kind, {String? cursor, int? limit, String? search});

  /// Fetch the rail ROW for one instance — the list uses this to materialize/refresh a row when a
  /// `created`/`edited`/`updated` lifecycle signal arrives (the signal carries only an id). 据 id 取单行
  /// (列表对 created/edited/updated 信号就地 patch 用)。
  Future<EntityRow> getEntityRow(EntityKind kind, String id);

  // ── detail (typed, embeds activeVersion) ──────────────────────────────────
  Future<FunctionEntity> getFunction(String id);
  Future<HandlerEntity> getHandler(String id);
  Future<AgentEntity> getAgent(String id);
  Future<WorkflowEntity> getWorkflow(String id);

  // ── version history (typed, append-only) ──────────────────────────────────
  Future<Page<FunctionVersion>> listFunctionVersions(String id, {String? cursor, int? limit});
  Future<Page<HandlerVersion>> listHandlerVersions(String id, {String? cursor, int? limit});
  Future<Page<AgentVersion>> listAgentVersions(String id, {String? cursor, int? limit});
  Future<Page<WorkflowVersion>> listWorkflowVersions(String id, {String? cursor, int? limit});

  // ── execution logs (日志 tab — list + ok/failed aggregate sidecar) ─────────
  Future<PageWithAggregate<FunctionExecution, ExecutionAggregates>> listFunctionExecutions(
      String id, {String? cursor, int? limit, String? status});
  Future<PageWithAggregate<HandlerCall, ExecutionAggregates>> listHandlerCalls(
      String id, {String? cursor, int? limit, String? status});
  Future<PageWithAggregate<AgentExecution, ExecutionAggregates>> listAgentExecutions(
      String id, {String? cursor, int? limit, String? status});

  // ── workflow runs (the workflow 日志 tab = flowruns, NOT executions) ───────
  Future<Page<Flowrun>> listFlowruns({required String workflowId, String? status, String? cursor, int? limit});
  Future<FlowrunComposite> getFlowrun(String id, {String? cursor, int? limit});

  // ── execute (the verb CTAs) ───────────────────────────────────────────────
  Future<FunctionRunResult> runFunction(String id, {required Map<String, dynamic> args, int? version});
  Future<dynamic> callHandler(String id, {required String method, required Map<String, dynamic> args});
  Future<InvokeResult> invokeAgent(String id, {required Map<String, dynamic> input, int? version});

  /// Trigger a workflow once now → the async flowrun id (202). 触发一次 → flowrun id。
  Future<String> triggerWorkflow(String id, {Map<String, dynamic>? payload});

  // ── agent mount health (overview preflight) ───────────────────────────────
  Future<MountHealthReport> getMountHealth(String id);

  // ── realtime ──────────────────────────────────────────────────────────────
  /// Lifecycle signals for the LIST of one kind (created/edited/deleted/updated). Low-frequency
  /// (notifications stream); the list patches on `durable`, ignores ephemeral. 列表生命周期信号。
  Stream<EntitySignal> lifecycleSignals(EntityKind kind);

  /// Raw panel-realtime frames for ONE instance (run terminal / build mirror / flowrun tick), demuxed
  /// per scope (high-frequency entities stream). 单实例面板实时帧(按 scope demux)。
  Stream<StreamEnvelope> panelSignals(StreamScope scope);
}

/// The production repository over the Phase-4.0 pipeline. Holds no state; every method is a thin
/// envelope-decode over [ApiClient] plus, for realtime, a projection over the [SseGateway] demux.
/// `sse` is nullable because the gateway is null until the sidecar is READY — before that, signal
/// streams are empty (features mount post-startup-gate, so this is just defensive).
///
/// 生产 repository(接 Phase 4.0 管道)。无状态;每方法是 ApiClient 上的薄信封解码,实时则是 SseGateway
/// demux 上的投影。`sse` 可空(就绪前网关 null)。
class LiveEntityRepository implements EntityRepository {
  LiveEntityRepository({required ApiClient api, SseGateway? sse})
      : _api = api,
        _sse = sse;

  final ApiClient _api;
  final SseGateway? _sse;

  Map<String, dynamic>? _query(String? cursor, int? limit, [Map<String, dynamic>? extra]) {
    final q = <String, dynamic>{
      'cursor': ?cursor,
      'limit': ?limit,
      ...?extra,
    };
    return q.isEmpty ? null : q;
  }

  // The log endpoints nest the tally under an `aggregates` key inside `data` (backend
  // responsehttpapi.Paged with {<listKey>, aggregates}). 日志端点把计数嵌在 data 内的 aggregates 键下。
  static ExecutionAggregates _agg(Map<String, dynamic> data) =>
      ExecutionAggregates.fromJson((data['aggregates'] as Map<String, dynamic>?) ?? const {});

  @override
  Future<Page<EntityRow>> listEntities(EntityKind kind, {String? cursor, int? limit, String? search}) =>
      _api.getPage(kind.base, (m) => EntityRow.fromListItem(kind, m),
          query: _query(cursor, limit, {'search': ?search}));

  @override
  Future<EntityRow> getEntityRow(EntityKind kind, String id) async => EntityRow.fromListItem(
        kind,
        switch (kind) {
          EntityKind.function => (await getFunction(id)).toJson(),
          EntityKind.handler => (await getHandler(id)).toJson(),
          EntityKind.agent => (await getAgent(id)).toJson(),
          EntityKind.workflow => (await getWorkflow(id)).toJson(),
        },
      );

  @override
  Future<FunctionEntity> getFunction(String id) =>
      _api.getEntity(EntityKind.function.itemPath(id), FunctionEntity.fromJson);
  @override
  Future<HandlerEntity> getHandler(String id) =>
      _api.getEntity(EntityKind.handler.itemPath(id), HandlerEntity.fromJson);
  @override
  Future<AgentEntity> getAgent(String id) =>
      _api.getEntity(EntityKind.agent.itemPath(id), AgentEntity.fromJson);
  @override
  Future<WorkflowEntity> getWorkflow(String id) =>
      _api.getEntity(EntityKind.workflow.itemPath(id), WorkflowEntity.fromJson);

  @override
  Future<Page<FunctionVersion>> listFunctionVersions(String id, {String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.function.itemPath(id)}/versions', FunctionVersion.fromJson,
          query: _query(cursor, limit));
  @override
  Future<Page<HandlerVersion>> listHandlerVersions(String id, {String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.handler.itemPath(id)}/versions', HandlerVersion.fromJson,
          query: _query(cursor, limit));
  @override
  Future<Page<AgentVersion>> listAgentVersions(String id, {String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.agent.itemPath(id)}/versions', AgentVersion.fromJson,
          query: _query(cursor, limit));
  @override
  Future<Page<WorkflowVersion>> listWorkflowVersions(String id, {String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.workflow.itemPath(id)}/versions', WorkflowVersion.fromJson,
          query: _query(cursor, limit));

  @override
  Future<PageWithAggregate<FunctionExecution, ExecutionAggregates>> listFunctionExecutions(
          String id, {String? cursor, int? limit, String? status}) =>
      _api.getPageWithAggregate('${EntityKind.function.itemPath(id)}/executions', 'executions',
          FunctionExecution.fromJson, _agg,
          query: _query(cursor, limit, {'status': ?status}));
  @override
  Future<PageWithAggregate<HandlerCall, ExecutionAggregates>> listHandlerCalls(
          String id, {String? cursor, int? limit, String? status}) =>
      _api.getPageWithAggregate('${EntityKind.handler.itemPath(id)}/calls', 'calls',
          HandlerCall.fromJson, _agg,
          query: _query(cursor, limit, {'status': ?status}));
  @override
  Future<PageWithAggregate<AgentExecution, ExecutionAggregates>> listAgentExecutions(
          String id, {String? cursor, int? limit, String? status}) =>
      _api.getPageWithAggregate('${EntityKind.agent.itemPath(id)}/executions', 'executions',
          AgentExecution.fromJson, _agg,
          query: _query(cursor, limit, {'status': ?status}));

  @override
  Future<Page<Flowrun>> listFlowruns({required String workflowId, String? status, String? cursor, int? limit}) =>
      _api.getPage('/api/v1/flowruns', Flowrun.fromJson,
          query: _query(cursor, limit, {'workflowId': workflowId, 'status': ?status}));
  @override
  Future<FlowrunComposite> getFlowrun(String id, {String? cursor, int? limit}) async =>
      FlowrunComposite.fromJson(await _api.getData('/api/v1/flowruns/$id', query: _query(cursor, limit)));

  @override
  Future<FunctionRunResult> runFunction(String id, {required Map<String, dynamic> args, int? version}) async {
    final r = await _api.postBare(EntityKind.function.actionPath(id),
        body: {'args': args, 'version': ?version});
    return FunctionRunResult.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<dynamic> callHandler(String id, {required String method, required Map<String, dynamic> args}) =>
      _api.postBare(EntityKind.handler.actionPath(id), body: {'method': method, 'args': args});

  @override
  Future<InvokeResult> invokeAgent(String id, {required Map<String, dynamic> input, int? version}) async {
    final r = await _api.postBare(EntityKind.agent.actionPath(id),
        body: {'input': input, 'version': ?version});
    return InvokeResult.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<String> triggerWorkflow(String id, {Map<String, dynamic>? payload}) =>
      _api.postForId(EntityKind.workflow.actionPath(id), body: {'payload': ?payload});

  @override
  Future<MountHealthReport> getMountHealth(String id) =>
      _api.getEntity('${EntityKind.agent.itemPath(id)}/mount-health', MountHealthReport.fromJson);

  @override
  Stream<EntitySignal> lifecycleSignals(EntityKind kind) {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    // The notifications stream is low-frequency and shares one scope (scope.kind="notification"), so a
    // `.where` over the raw feed is correct here — NOT the rebuild-storm the demux guards high-freq
    // paths against. We project each frame onto a kind-specific signal and drop non-matches.
    //
    // notifications 低频且共用单 scope,故对原始 feed `.where` 在此正确(非 demux 所防的高频重建风暴)。
    return sse
        .rawStream(StreamName.notifications)
        .map((env) => EntitySignal.fromEnvelope(kind, env))
        .where((s) => s != null)
        .cast<EntitySignal>();
  }

  @override
  Stream<StreamEnvelope> panelSignals(StreamScope scope) =>
      _sse?.scopeStream(scope) ?? const Stream.empty();
}
