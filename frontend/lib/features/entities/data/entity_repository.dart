import 'dart:async';

import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/common.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';
import 'entity_kind.dart';
import 'entity_row.dart';
import 'entity_signal.dart';

/// A lean projection of one selectable option for the workflow node-ref picker — a target entity or a
/// member (handler method / mcp tool). [id] is the value written into the ref, [name] the display name,
/// [meta] an optional secondary (e.g. an mcp server's status / a tool's description). ref 选择器的精简候选
/// (目标实体 / 成员):id=写进 ref 的值,name=显示名,meta=可选次级(mcp 状态 / 工具描述)。
typedef RefCandidate = ({String id, String name, String? meta});

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

  /// The whole-workspace relation snapshot (`GET /api/v1/relgraph`) — deduped nodes + all edges. Backs
  /// the Entities Overview relationship graph. No params, no pagination (bounded system resource). The
  /// snapshot's nodes span all 11 backend EntityKinds, NOT just the 7 rail kinds. 全 workspace 关系快照。
  Future<EntityRelGraph> getRelGraph();

  /// Fetch the rail ROW for one instance — the list uses this to materialize/refresh a row when a
  /// `created`/`edited`/`updated` lifecycle signal arrives (the signal carries only an id). 据 id 取单行
  /// (列表对 created/edited/updated 信号就地 patch 用)。
  Future<EntityRow> getEntityRow(EntityKind kind, String id);

  // ── detail (typed, embeds activeVersion) ──────────────────────────────────
  Future<FunctionEntity> getFunction(String id);
  Future<HandlerEntity> getHandler(String id);
  Future<AgentEntity> getAgent(String id);
  Future<WorkflowEntity> getWorkflow(String id);

  /// A control logic (branches/ports) — not a rail entity, fetched for the workflow editor's edge-port
  /// picker. control 逻辑(分支/端口),供图编辑器边端口下拉。
  Future<ControlLogic> getControl(String id);

  /// An approval form (template/decision rules) — a support rail kind. 审批表(模板/决策规则),支撑 rail kind。
  Future<ApprovalForm> getApproval(String id);

  /// A trigger (config signal source) — a support rail kind, UNVERSIONED. Carries read-derived
  /// `refCount`/`listening`/`lastFiredAt`/`nextFireAt`. trigger(配置信号源),支撑 rail kind,无版本。
  Future<TriggerEntity> getTrigger(String id);

  // ── version history (typed, append-only) ──────────────────────────────────
  Future<Page<FunctionVersion>> listFunctionVersions(String id, {String? cursor, int? limit});
  Future<Page<HandlerVersion>> listHandlerVersions(String id, {String? cursor, int? limit});
  Future<Page<AgentVersion>> listAgentVersions(String id, {String? cursor, int? limit});
  Future<Page<WorkflowVersion>> listWorkflowVersions(String id, {String? cursor, int? limit});

  // ── execution logs (日志 tab — list + ok/failed aggregate sidecar) ─────────
  Future<PageWithAggregate<FunctionExecution, ExecutionAggregates>> listFunctionExecutions(
      String id, {String? cursor, int? limit, String? status});
  Future<PageWithAggregate<HandlerCall, ExecutionAggregates>> listHandlerCalls(
      String id, {String? cursor, int? limit, String? status, String? method});
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

  /// Decide a parked approval node (first-wins; the loser gets 422 FLOWRUN_APPROVAL_NOT_PARKED) →
  /// the fresh flowrun snapshot (202). 决断 parked 审批(first-wins)→ 新快照。
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason});

  /// Every PARKED approval node across the workspace (the cross-run approval inbox, `GET /flowrun-inbox`).
  /// 跨 run 审批收件箱:workspace 内所有 parked approval 节点。
  Future<List<FlowrunNode>> listFlowrunInbox();

  /// `:replay` a FAILED flowrun (422 FLOWRUN_NOT_REPLAYABLE otherwise) → the fresh snapshot (202).
  /// 重跑失败 flowrun → 新快照。
  Future<FlowrunComposite> replayFlowrun(String flowrunId);

  /// `:kill` a workflow — hard-stop every in-flight run (→ cancelled) → the workflow snapshot.
  /// 终止 workflow:硬停全部在途 run。
  Future<WorkflowEntity> killWorkflow(String id);

  // ── trigger observability + manual fire (the trigger detail's two log streams + its CTA) ──────
  /// `:fire` a trigger — fan a manual signal to its current listeners (payload is always `{manual:true}`,
  /// no custom body) → the new activation id (202). 手动催一次(合成 {manual:true})→ 新 activation id。
  Future<String> fireTrigger(String id);

  /// The trigger's ACTIVATION log (触发面) — one row per action, fired or not (`?firedOnly` narrows to
  /// the fired ones). N4 keyset-paged. trigger 活动日志(触没触发都记)。
  Future<Page<Activation>> listActivations(String id, {bool firedOnly, String? cursor, int? limit});

  /// The trigger's FIRING inbox (运行面) — one row per fired→listener dispatch, `?status` narrows to a
  /// disposition (pending/started/skipped/superseded/shed). N4 keyset-paged. trigger 派发收件箱。
  Future<Page<Firing>> listFirings(String id, {String? status, String? cursor, int? limit});

  // ── write plane (WRK-054 F2 — function first, signatures kind-generic where the endpoint is) ──
  /// PATCH meta (name/description/tags) — does NOT bump the version. 改 meta,不升版本。
  Future<FunctionEntity> patchFunctionMeta(String id, Map<String, dynamic> patch);

  /// PATCH handler meta (name/description/tags) — no version bump, no instance restart. 改 handler meta。
  Future<HandlerEntity> patchHandlerMeta(String id, Map<String, dynamic> patch);

  /// Handler config (init-arg values, sensitive masked). Read the masked blob + schema + gate state;
  /// merge-patch it (null deletes a key); or clear it. A PUT or a clear RESTARTS the resident instance
  /// (re-runs `__init__`), so both re-read the handler for its new config/runtime state. handler config:
  /// 读掩码值+schema+闸门态 / 合并写(null 删键)/ 清;写或清都重启实例、故都回读 handler 新态。
  Future<HandlerConfig> getHandlerConfig(String id);
  Future<HandlerEntity> putHandlerConfig(String id, Map<String, Object?> patch);
  Future<HandlerEntity> clearHandlerConfig(String id);

  /// `POST :restart` — stop + respawn the resident instance (new instanceId). 重启常驻实例。
  Future<HandlerEntity> restartHandler(String id);

  /// PATCH workflow meta (name/description/tags/concurrency) — no version bump (WRK-055 W2).
  /// 改 workflow meta,不升版本。
  Future<WorkflowEntity> patchWorkflowMeta(String id, Map<String, dynamic> patch);

  /// `:edit` a workflow — apply graph ops → a NEW version (WRK-055 W5). One edit session's diff is
  /// one ops array is one version. 编辑 workflow:图 ops → 新版本(一次会话一版)。
  Future<WorkflowVersion> editWorkflow(String id, List<Map<String, Object?>> ops, {String? changeReason});

  /// `POST :revert` — move the active pointer to version [version] (any versioned kind; the endpoint
  /// shape is uniform). 把 active 指针移到指定版本号(版本化 kind 通用,端点同形)。
  Future<void> revertVersion(EntityKind kind, String id, int version);

  // ── ref-picker candidates (lean id/name/meta projections for the workflow node-ref picker) ─────
  // These families are NOT the four rail EntityKinds, so they get their own list endpoints. The
  // picker only needs id + display name (+ an optional meta), never the full entity. 非四大 rail 实体的
  // 族,走各自 list 端点;选择器只要 id + 名(+ 可选 meta),不要整实体。
  Future<List<RefCandidate>> listMcpServers();
  Future<List<RefCandidate>> listMcpTools(String server);
  Future<List<RefCandidate>> listTriggers();
  Future<List<RefCandidate>> listControls();
  Future<List<RefCandidate>> listApprovals();

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

  // No query params — a bounded workspace snapshot (the backend takes none). `getData` returns the `data`
  // object = {nodes, edges}. 无参:有界快照;getData 返 data 对象 {nodes, edges}。
  @override
  Future<EntityRelGraph> getRelGraph() async =>
      EntityRelGraph.fromJson(await _api.getData('/api/v1/relgraph'));

  @override
  Future<EntityRow> getEntityRow(EntityKind kind, String id) async => EntityRow.fromListItem(
        kind,
        switch (kind) {
          EntityKind.function => (await getFunction(id)).toJson(),
          EntityKind.handler => (await getHandler(id)).toJson(),
          EntityKind.agent => (await getAgent(id)).toJson(),
          EntityKind.workflow => (await getWorkflow(id)).toJson(),
          EntityKind.control => (await getControl(id)).toJson(),
          EntityKind.approval => (await getApproval(id)).toJson(),
          EntityKind.trigger => (await getTrigger(id)).toJson(),
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
  Future<ControlLogic> getControl(String id) =>
      _api.getEntity('/api/v1/controls/$id', ControlLogic.fromJson);
  @override
  Future<ApprovalForm> getApproval(String id) =>
      _api.getEntity('/api/v1/approvals/$id', ApprovalForm.fromJson);
  @override
  Future<TriggerEntity> getTrigger(String id) =>
      _api.getEntity('/api/v1/triggers/$id', TriggerEntity.fromJson);

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
          String id, {String? cursor, int? limit, String? status, String? method}) =>
      _api.getPageWithAggregate('${EntityKind.handler.itemPath(id)}/calls', 'calls',
          HandlerCall.fromJson, _agg,
          query: _query(cursor, limit, {'status': ?status, 'method': ?method}));
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
    final r = await _api.postBare(EntityKind.function.actionPath(id)!,
        body: {'args': args, 'version': ?version});
    return FunctionRunResult.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<dynamic> callHandler(String id, {required String method, required Map<String, dynamic> args}) =>
      _api.postBare(EntityKind.handler.actionPath(id)!, body: {'method': method, 'args': args});

  @override
  Future<InvokeResult> invokeAgent(String id, {required Map<String, dynamic> input, int? version}) async {
    final r = await _api.postBare(EntityKind.agent.actionPath(id)!,
        body: {'input': input, 'version': ?version});
    return InvokeResult.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<String> triggerWorkflow(String id, {Map<String, dynamic>? payload}) =>
      _api.postForId(EntityKind.workflow.actionPath(id)!, body: {'payload': ?payload});

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
          {required String decision, String? reason}) =>
      _api.postEntity('/api/v1/flowruns/$flowrunId/approvals/$nodeId:decide',
          FlowrunComposite.fromJson, body: {'decision': decision, 'reason': ?reason});

  @override
  Future<List<FlowrunNode>> listFlowrunInbox() async {
    final data = await _api.getData('/api/v1/flowrun-inbox');
    return [
      for (final e in (data['parked'] as List? ?? const []))
        FlowrunNode.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<FlowrunComposite> replayFlowrun(String flowrunId) =>
      _api.postEntity('/api/v1/flowruns/$flowrunId:replay', FlowrunComposite.fromJson);

  @override
  Future<WorkflowEntity> killWorkflow(String id) =>
      _api.postEntity('${EntityKind.workflow.itemPath(id)}:kill', WorkflowEntity.fromJson);

  @override
  Future<String> fireTrigger(String id) =>
      _api.postForId('${EntityKind.trigger.itemPath(id)}:fire');
  @override
  Future<Page<Activation>> listActivations(String id, {bool firedOnly = false, String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.trigger.itemPath(id)}/activations', Activation.fromJson,
          query: _query(cursor, limit, {if (firedOnly) 'firedOnly': 'true'}));
  @override
  Future<Page<Firing>> listFirings(String id, {String? status, String? cursor, int? limit}) =>
      _api.getPage('${EntityKind.trigger.itemPath(id)}/firings', Firing.fromJson,
          query: _query(cursor, limit, {'status': ?status}));

  @override
  Future<FunctionEntity> patchFunctionMeta(String id, Map<String, dynamic> patch) =>
      _api.patchEntity(EntityKind.function.itemPath(id), FunctionEntity.fromJson, body: patch);

  @override
  Future<HandlerEntity> patchHandlerMeta(String id, Map<String, dynamic> patch) =>
      _api.patchEntity(EntityKind.handler.itemPath(id), HandlerEntity.fromJson, body: patch);

  @override
  Future<HandlerConfig> getHandlerConfig(String id) =>
      _api.getEntity('${EntityKind.handler.itemPath(id)}/config', HandlerConfig.fromJson);

  // PUT/DELETE config restart the instance; the response shape isn't relied on — re-read the handler for
  // its canonical new config/runtime state. PUT/DELETE 重启实例;不依赖其响应体、回读 handler 取新态。
  @override
  Future<HandlerEntity> putHandlerConfig(String id, Map<String, Object?> patch) async {
    await _api.patchEntity('${EntityKind.handler.itemPath(id)}/config', (m) => m, body: patch, put: true);
    return getHandler(id);
  }

  @override
  Future<HandlerEntity> clearHandlerConfig(String id) async {
    await _api.delete('${EntityKind.handler.itemPath(id)}/config');
    return getHandler(id);
  }

  @override
  Future<HandlerEntity> restartHandler(String id) =>
      _api.postEntity('${EntityKind.handler.itemPath(id)}:restart', HandlerEntity.fromJson);

  @override
  Future<WorkflowEntity> patchWorkflowMeta(String id, Map<String, dynamic> patch) =>
      _api.patchEntity(EntityKind.workflow.itemPath(id), WorkflowEntity.fromJson, body: patch);

  @override
  Future<WorkflowVersion> editWorkflow(String id, List<Map<String, Object?>> ops, {String? changeReason}) =>
      _api.postEntity('${EntityKind.workflow.itemPath(id)}:edit', WorkflowVersion.fromJson,
          body: {'ops': ops, 'changeReason': ?changeReason});

  // :revert answers `{data: <version>}` (N1 envelope, unlike the BARE `:run`). :revert 走 N1 信封返版本。
  @override
  Future<void> revertVersion(EntityKind kind, String id, int version) async =>
      await _api.postEntity('${kind.itemPath(id)}:revert', (m) => m, body: {'version': version});

  @override
  Future<MountHealthReport> getMountHealth(String id) =>
      _api.getEntity('${EntityKind.agent.itemPath(id)}/mount-health', MountHealthReport.fromJson);

  // ── ref-picker candidates ──────────────────────────────────────────────────
  // An mcp SERVER is keyed by name (id == name), status is the meta. mcp server 以 name 为键(id=name)。
  @override
  Future<List<RefCandidate>> listMcpServers() async => (await _api.getPage<RefCandidate>(
        '/api/v1/mcp-servers',
        (m) => (id: m['name'] as String? ?? '', name: m['name'] as String? ?? '', meta: m['status'] as String?),
        query: const {'limit': 200},
      ))
          .items;

  // GET /mcp-servers/{name} answers {data:{name, status, tools:[{name, description}], …}} — project the
  // tools cache. 取工具缓存。
  @override
  Future<List<RefCandidate>> listMcpTools(String server) async {
    final data = await _api.getEntity<Map<String, dynamic>>('/api/v1/mcp-servers/$server', (m) => m);
    final tools = (data['tools'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [];
    return [
      for (final t in tools)
        (id: t['name'] as String? ?? '', name: t['name'] as String? ?? '', meta: t['description'] as String?),
    ];
  }

  @override
  Future<List<RefCandidate>> listTriggers() => _refList('/api/v1/triggers');
  @override
  Future<List<RefCandidate>> listControls() => _refList('/api/v1/controls');
  @override
  Future<List<RefCandidate>> listApprovals() => _refList('/api/v1/approvals');

  // trigger/control/approval list items carry id + name (N4 paginated; local sets are small, one page).
  // trigger/control/approval 列表项带 id + name。
  Future<List<RefCandidate>> _refList(String path) async => (await _api.getPage<RefCandidate>(
        path,
        (m) => (
          id: m['id'] as String? ?? '',
          name: (m['name'] as String?)?.isNotEmpty == true ? m['name'] as String : (m['id'] as String? ?? ''),
          meta: null,
        ),
        // Explicit 200 cap (backend MaxLimit) so the picker isn't silently trimmed to the default 50 —
        // matches the rail families' bound. 显式 200 上限(后端 MaxLimit),不被默认 50 静默截断。
        query: const {'limit': 200},
      ))
          .items;

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
