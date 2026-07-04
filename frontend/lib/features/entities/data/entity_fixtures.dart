import 'dart:async';
import 'dart:convert';

import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/common.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/graph/graph_edit_ops.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../../../core/sse/frame.dart';
import 'entity_format.dart';
import 'entity_kind.dart';
import 'entity_row.dart';
import 'entity_signal.dart';
import 'entity_repository.dart';

/// In-memory, scriptable [EntityRepository] — the SINGLE seam the whole feature is driven by in
/// gallery/widget/provider tests and the zero-backend demo. Reads page over typed seed lists (rows are
/// derived from the same seed via `toJson()` → [EntityRow.fromListItem], so the fixture exercises the
/// exact parsing the Live path does); realtime is scripted by [emitLifecycle] / [emitPanel] so a test
/// can assert "this durable signal patches the list" with no SSE socket. Stateless-ish: seeds are
/// final, signals flow through lazy broadcast controllers.
///
/// 内存、可脚本化的 EntityRepository——gallery/widget/provider 测试与零后端 demo 驱动整 feature 的唯一
/// 缝。读分页 over typed 种子列表(行经 toJson→fromListItem 派生,故走与 Live 一致的解析);实时由
/// emitLifecycle/emitPanel 脚本化,使测试无需 SSE socket 即可断言"durable 信号 patch 列表"。
class FixtureEntityRepository implements EntityRepository {
  FixtureEntityRepository({
    List<FunctionEntity>? functions,
    List<HandlerEntity>? handlers,
    List<AgentEntity>? agents,
    List<WorkflowEntity>? workflows,
    Map<String, List<FunctionVersion>>? functionVersions,
    Map<String, List<HandlerVersion>>? handlerVersions,
    Map<String, List<AgentVersion>>? agentVersions,
    Map<String, List<WorkflowVersion>>? workflowVersions,
    Map<String, List<FunctionExecution>>? functionExecutions,
    Map<String, List<HandlerCall>>? handlerCalls,
    Map<String, List<AgentExecution>>? agentExecutions,
    Map<String, List<Flowrun>>? flowruns,
    Map<String, FlowrunComposite>? flowrunDetail,
    Map<String, MountHealthReport>? mountHealth,
    List<RefCandidate>? mcpServers,
    Map<String, List<RefCandidate>>? mcpTools,
    List<RefCandidate>? triggers,
    List<RefCandidate>? controls,
    List<RefCandidate>? approvals,
    this.runDelay = const Duration(milliseconds: 10),
  })  : _functions = List.of(functions ?? const []),
        _handlers = List.of(handlers ?? const []),
        _agents = List.of(agents ?? const []),
        _workflows = List.of(workflows ?? const []),
        _functionVersions = functionVersions ?? const {},
        _handlerVersions = handlerVersions ?? const {},
        _agentVersions = agentVersions ?? const {},
        _workflowVersions = Map.of(workflowVersions ?? const {}),
        _functionExecutions = functionExecutions ?? const {},
        _handlerCalls = handlerCalls ?? const {},
        _agentExecutions = agentExecutions ?? const {},
        _flowruns = flowruns ?? const {},
        _flowrunDetail = Map.of(flowrunDetail ?? const {}),
        _mountHealth = mountHealth ?? const {},
        _mcpServers = mcpServers ?? const [],
        _mcpTools = mcpTools ?? const {},
        _triggers = triggers ?? const [],
        _controls = controls ?? const [],
        _approvals = approvals ?? const [];

  /// Inter-frame delay for the scripted run-terminal streams (so `make demo` shows a live terminal).
  /// Tests pass [Duration.zero] for an instant burst. 脚本流的帧间延迟(demo 现真实流式);测试用 zero 即时。
  final Duration runDelay;
  int _runCount = 0;

  final List<FunctionEntity> _functions;
  final List<HandlerEntity> _handlers;
  final List<AgentEntity> _agents;
  final List<WorkflowEntity> _workflows;
  final Map<String, List<FunctionVersion>> _functionVersions;
  final Map<String, List<HandlerVersion>> _handlerVersions;
  final Map<String, List<AgentVersion>> _agentVersions;
  final Map<String, List<WorkflowVersion>> _workflowVersions;
  final Map<String, List<FunctionExecution>> _functionExecutions;
  final Map<String, List<HandlerCall>> _handlerCalls;
  final Map<String, List<AgentExecution>> _agentExecutions;
  final Map<String, List<Flowrun>> _flowruns;
  final Map<String, FlowrunComposite> _flowrunDetail;
  final Map<String, MountHealthReport> _mountHealth;
  final List<RefCandidate> _mcpServers;
  final Map<String, List<RefCandidate>> _mcpTools;
  final List<RefCandidate> _triggers;
  final List<RefCandidate> _controls;
  final List<RefCandidate> _approvals;

  final _lifecycle = <EntityKind, StreamController<EntitySignal>>{};
  final _panels = <String, StreamController<StreamEnvelope>>{};

  // ── paging helpers (cursor = the next start index, as a string) ────────────
  static Page<T> _page<T>(List<T> all, String? cursor, int? limit) {
    final start = int.tryParse(cursor ?? '') ?? 0;
    final n = limit ?? all.length;
    final end = (start + n).clamp(0, all.length);
    final slice = all.sublist(start.clamp(0, all.length), end);
    final more = end < all.length;
    return Page(items: slice, nextCursor: more ? '$end' : null, hasMore: more);
  }

  static PageWithAggregate<T, A> _pageAgg<T, A>(List<T> all, A agg, String? cursor, int? limit) {
    final p = _page(all, cursor, limit);
    return PageWithAggregate(
        items: p.items, aggregate: agg, nextCursor: p.nextCursor, hasMore: p.hasMore);
  }

  ExecutionAggregates _aggOf(int ok, int failed) =>
      ExecutionAggregates(okCount: ok, failedCount: failed);

  // ── list / detail ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _itemsOf(EntityKind kind) => switch (kind) {
        EntityKind.function => _functions.map((e) => e.toJson()).toList(),
        EntityKind.handler => _handlers.map((e) => e.toJson()).toList(),
        EntityKind.agent => _agents.map((e) => e.toJson()).toList(),
        EntityKind.workflow => _workflows.map((e) => e.toJson()).toList(),
      };

  @override
  Future<Page<EntityRow>> listEntities(EntityKind kind, {String? cursor, int? limit, String? search}) async {
    // Mirror the server's ?search: case-insensitive name substring, applied before paging.
    // 镜像服务端 ?search:分页前对 name 大小写不敏感子串过滤。
    final term = search?.trim().toLowerCase() ?? '';
    var rows = _itemsOf(kind).map((m) => EntityRow.fromListItem(kind, m)).toList();
    if (term.isNotEmpty) {
      rows = rows.where((r) => r.name.toLowerCase().contains(term)).toList();
    }
    return _page(rows, cursor, limit);
  }

  // ── ref-picker candidates ──────────────────────────────────────────────────
  @override
  Future<List<RefCandidate>> listMcpServers() async => _mcpServers;
  @override
  Future<List<RefCandidate>> listMcpTools(String server) async => _mcpTools[server] ?? const [];
  @override
  Future<List<RefCandidate>> listTriggers() async => _triggers;
  @override
  Future<List<RefCandidate>> listControls() async => _controls;
  @override
  Future<List<RefCandidate>> listApprovals() async => _approvals;

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
  Future<FunctionEntity> getFunction(String id) async =>
      _functions.firstWhere((e) => e.id == id);
  @override
  Future<HandlerEntity> getHandler(String id) async => _handlers.firstWhere((e) => e.id == id);
  @override
  Future<AgentEntity> getAgent(String id) async => _agents.firstWhere((e) => e.id == id);
  @override
  Future<WorkflowEntity> getWorkflow(String id) async => _workflows.firstWhere((e) => e.id == id);

  // ── versions ────────────────────────────────────────────────────────────--
  @override
  Future<Page<FunctionVersion>> listFunctionVersions(String id, {String? cursor, int? limit}) async =>
      _page(_functionVersions[id] ?? const [], cursor, limit);
  @override
  Future<Page<HandlerVersion>> listHandlerVersions(String id, {String? cursor, int? limit}) async =>
      _page(_handlerVersions[id] ?? const [], cursor, limit);
  @override
  Future<Page<AgentVersion>> listAgentVersions(String id, {String? cursor, int? limit}) async =>
      _page(_agentVersions[id] ?? const [], cursor, limit);
  @override
  Future<Page<WorkflowVersion>> listWorkflowVersions(String id, {String? cursor, int? limit}) async =>
      _page(_workflowVersions[id] ?? const [], cursor, limit);

  // ── logs ────────────────────────────────────────────────────────────────--
  // The fixture ignores the `status` filter (the public params exist for interface conformance); it
  // computes the ok/failed tally over the whole seeded list. 夹具忽略 status 过滤,聚合算整列表。
  PageWithAggregate<T, ExecutionAggregates> _logPage<T>(
      List<T> all, String? cursor, int? limit, bool Function(T) ok) {
    final okN = all.where(ok).length;
    return _pageAgg(all, _aggOf(okN, all.length - okN), cursor, limit);
  }

  @override
  Future<PageWithAggregate<FunctionExecution, ExecutionAggregates>> listFunctionExecutions(
          String id, {String? cursor, int? limit, String? status}) async =>
      _logPage(_functionExecutions[id] ?? const [], cursor, limit, (e) => e.status == 'ok');
  @override
  Future<PageWithAggregate<HandlerCall, ExecutionAggregates>> listHandlerCalls(
          String id, {String? cursor, int? limit, String? status}) async =>
      _logPage(_handlerCalls[id] ?? const [], cursor, limit, (e) => e.status == 'ok');
  @override
  Future<PageWithAggregate<AgentExecution, ExecutionAggregates>> listAgentExecutions(
          String id, {String? cursor, int? limit, String? status}) async =>
      _logPage(_agentExecutions[id] ?? const [], cursor, limit, (e) => e.status == 'ok');

  // ── flowruns ──────────────────────────────────────────────────────────────
  @override
  Future<Page<Flowrun>> listFlowruns(
          {required String workflowId, String? status, String? cursor, int? limit}) async =>
      _page(_flowruns[workflowId] ?? const [], cursor, limit);
  @override
  Future<FlowrunComposite> getFlowrun(String id, {String? cursor, int? limit}) async {
    final comp = _flowrunDetail[id] ??
        (throw StateError('FixtureEntityRepository: no flowrun seeded for $id'));
    // Honest paging like the wire (newest-first; cursor = offset): the reconcile's page-through
    // path is exercised by fixtures too. 与线缆同形的诚实分页(最新在前,cursor=偏移)。
    final start = int.tryParse(cursor ?? '') ?? 0;
    final size = limit ?? 50;
    final end = (start + size).clamp(0, comp.nodes.length);
    return FlowrunComposite(
      flowrun: comp.flowrun,
      nodes: comp.nodes.sublist(start.clamp(0, comp.nodes.length), end),
      nextCursor: end < comp.nodes.length ? '$end' : null,
    );
  }

  // ── execute (scripted streaming over the panel scope, then the bare result — STEP 5) ──────────
  // Each verb scripts a realistic entities-stream sequence onto the entity's panel scope (the SAME shape
  // the Live path receives) BEFORE returning the sync result / async id, so the run terminal renders a
  // live stream in the zero-backend demo + widget tests. fn/hd = a `run` node (open→stderr deltas→close);
  // agent = a ReAct block tree (reasoning/tool_call/tool_result/text); workflow = ephemeral flowrun ticks
  // + a synthesized durable flowrun (so the terminal's GET /flowruns/{id} resolves).
  // 每个动词把一段真实 entities 流脚本到面板 scope(与 Live 同形)再返结果,使 demo/测试里 run 终端真流式。
  @override
  Future<FunctionRunResult> runFunction(String id, {required Map<String, dynamic> args, int? version}) async {
    await _streamRun(EntityKind.function.scope(id));
    return const FunctionRunResult(ok: true, output: {'result': 'ok'}, elapsedMs: 12, logs: 'normalized 1 field');
  }

  @override
  Future<dynamic> callHandler(String id, {required String method, required Map<String, dynamic> args}) async {
    await _streamRun(EntityKind.handler.scope(id));
    return {'ok': true, 'method': method};
  }

  @override
  Future<InvokeResult> invokeAgent(String id, {required Map<String, dynamic> input, int? version}) async {
    await _streamAgent(EntityKind.agent.scope(id));
    return const InvokeResult(
        executionId: 'agx_fixture', ok: true, output: {'summary': 'a concise answer'}, status: 'completed', steps: 3, tokensIn: 1840, tokensOut: 320, elapsedMs: 5200);
  }

  @override
  Future<String> triggerWorkflow(String id, {Map<String, dynamic>? payload}) async {
    final flowrunId = 'flr_run${++_runCount}';
    final now = DateTime.utc(2026, 6, 27, 10);
    final graph = graphOf((await getWorkflow(id)).activeVersion ??
            (throw StateError('FixtureEntityRepository: workflow $id has no active version'))) ??
        const Graph();
    _flowrunDetail[flowrunId] = FlowrunComposite(
      flowrun: Flowrun(id: flowrunId, workflowId: id, versionId: '${id}_v1', status: 'running', startedAt: now, updatedAt: now),
      nodes: const [],
    );
    // 202 semantics: the id returns FIRST, the walk runs async — exactly the Live path's shape (a
    // tick arriving before the caller knows its flowrunId would be self-filtered away).
    // 202 语义:先返 id、走图异步——与 Live 同形(id 未知前到的 tick 会被自滤丢)。
    unawaited(_walkFlowrun(id, flowrunId, graph, now));
    return flowrunId;
  }

  /// Walk the entity's ACTUAL graph in declaration order (so the overview hero lights the real
  /// nodes): control picks its first forward-edge port (recorded as __port, like the backend),
  /// approval PARKS the run (the terminal shows the gate; :decide resumes). Ticks mirror the wire
  /// (terminal statuses only, no result payload); the composite rows carry the results.
  /// 按实体真图声明序走:control 选首条前向口(落 __port),approval 停车(:decide 续走)。
  /// tick 同线缆(只有终态、无 result);composite 行带结果。
  Future<void> _walkFlowrun(String id, String flowrunId, Graph graph, DateTime now) async {
    final scope = EntityKind.workflow.scope(id);
    for (final n in graph.nodes) {
      await _delay();
      if (n.kind == NodeKind.approval) {
        _appendFlowrunRow(flowrunId, FlowrunNode(
            id: 'frn_${n.id}', flowrunId: flowrunId, nodeId: n.id, kind: n.kind.name, ref: n.ref,
            status: 'parked', result: const {'rendered': 'Approve this step to continue.'},
            createdAt: now, updatedAt: now));
        emitPanel(scope, _sig(scope, 'sig_${n.id}', {'flowrunId': flowrunId, 'nodeId': n.id, 'iteration': 0, 'status': 'parked'}));
        return; // parked — the run waits for :decide 停车等决断
      }
      final result = <String, Object?>{};
      if (n.kind == NodeKind.control) {
        final port = graph.edges
            .firstWhere((e) => e.from == n.id && (e.fromPort ?? '').isNotEmpty,
                orElse: () => const Edge(id: '', from: '', to: ''))
            .fromPort;
        if (port != null) result['__port'] = port;
      }
      _appendFlowrunRow(flowrunId, FlowrunNode(
          id: 'frn_${n.id}', flowrunId: flowrunId, nodeId: n.id, kind: n.kind.name, ref: n.ref,
          status: 'completed', result: result, createdAt: now, completedAt: now, updatedAt: now));
      emitPanel(scope, _sig(scope, 'sig_${n.id}', {'flowrunId': flowrunId, 'nodeId': n.id, 'iteration': 0, 'status': 'completed'}));
    }
    _updateFlowrun(flowrunId, status: 'completed', completedAt: now);
  }

  void _appendFlowrunRow(String flowrunId, FlowrunNode row) {
    final comp = _flowrunDetail[flowrunId];
    if (comp == null) return;
    _flowrunDetail[flowrunId] = FlowrunComposite(flowrun: comp.flowrun, nodes: [row, ...comp.nodes]);
  }

  void _updateFlowrun(String flowrunId, {required String status, DateTime? completedAt}) {
    final comp = _flowrunDetail[flowrunId];
    if (comp == null) return;
    _flowrunDetail[flowrunId] = FlowrunComposite(
      flowrun: comp.flowrun.copyWith(status: status, completedAt: completedAt),
      nodes: comp.nodes,
    );
  }

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason}) async {
    final comp = _flowrunDetail[flowrunId];
    if (comp == null) throw StateError('FixtureEntityRepository: no flowrun $flowrunId');
    final i = comp.nodes.indexWhere((n) => n.nodeId == nodeId && n.status == 'parked');
    if (i < 0) throw StateError('FixtureEntityRepository: $nodeId is not parked (first-wins)');
    final now = DateTime.utc(2026, 6, 27, 10, 5);
    final decided = comp.nodes[i].copyWith(
        status: 'completed',
        result: {...comp.nodes[i].result, 'decision': decision, 'reason': ?reason},
        completedAt: now,
        updatedAt: now);
    final next = FlowrunComposite(
      // The fixture resolves the whole run on decide (enough for demo/tests — the Live path's truth
      // is the backend walk). fixture 决断即收尾(demo/测试够用;Live 真相在后端)。
      flowrun: comp.flowrun.copyWith(status: 'completed', completedAt: now),
      nodes: [for (final n in comp.nodes) n.nodeId == nodeId ? decided : n],
    );
    _flowrunDetail[flowrunId] = next;
    final scope = EntityKind.workflow.scope(comp.flowrun.workflowId);
    emitPanel(scope, _sig(scope, 'sig_decide_$nodeId',
        {'flowrunId': flowrunId, 'nodeId': nodeId, 'iteration': 0, 'status': 'completed'}));
    return next;
  }

  Future<void> _delay() => runDelay == Duration.zero ? Future<void>.value() : Future<void>.delayed(runDelay);

  // fn/hd run node: open (durable) → stderr deltas (ephemeral) → close (durable). fn/hd run 节点。
  Future<void> _streamRun(StreamScope scope) async {
    const nid = 'blk_run';
    await _delay();
    emitPanel(scope, _open(scope, nid, 'run'));
    for (final line in const ['› starting…\n', '› processing input\n', '› done\n']) {
      await _delay();
      emitPanel(scope, _delta(scope, nid, line));
    }
    await _delay();
    emitPanel(scope, _close(scope, nid, 'run', 'completed'));
  }

  // agent ReAct trace: reasoning → tool_call → tool_result (nested) → text. agent 轨迹块树。
  Future<void> _streamAgent(StreamScope scope) async {
    Future<void> open(String id, String type, {String? parent, Map<String, dynamic>? content}) async {
      await _delay();
      emitPanel(scope, StreamEnvelope(seq: 1, scope: scope, id: id, frame: FrameOpen(parentId: parent, node: StreamNode(type: type, content: content))));
    }

    Future<void> delta(String id, String chunk) async {
      await _delay();
      emitPanel(scope, _delta(scope, id, chunk));
    }

    Future<void> close(String id, String type, Map<String, dynamic> content) async {
      await _delay();
      emitPanel(scope, StreamEnvelope(seq: 2, scope: scope, id: id, frame: FrameClose(status: 'completed', result: StreamNode(type: type, content: content))));
    }

    await open('b1', 'reasoning');
    await delta('b1', 'The topic needs a quick search, ');
    await delta('b1', 'then a summary.');
    await close('b1', 'reasoning', {'content': 'The topic needs a quick search, then a summary.'});

    await open('b2', 'tool_call', content: {'name': 'web-search'});
    await delta('b2', '{"q":"llm agents"}');
    await close('b2', 'tool_call', {'name': 'web-search', 'arguments': '{"q":"llm agents"}', 'danger': 'safe'});
    await open('b3', 'tool_result', parent: 'b2', content: {'content': '3 results found'});
    await close('b3', 'tool_result', {'content': '3 results found'});

    await open('b4', 'text');
    await delta('b4', 'Based on the search, ');
    await delta('b4', 'here is a concise answer.');
    await close('b4', 'text', {'content': 'Based on the search, here is a concise answer.'});
  }

  StreamEnvelope _open(StreamScope scope, String id, String type) =>
      StreamEnvelope(seq: 1, scope: scope, id: id, frame: FrameOpen(node: StreamNode(type: type)));
  StreamEnvelope _delta(StreamScope scope, String id, String chunk) =>
      StreamEnvelope(seq: 0, scope: scope, id: id, frame: FrameDelta(chunk: chunk));
  StreamEnvelope _close(StreamScope scope, String id, String type, String status) =>
      StreamEnvelope(seq: 2, scope: scope, id: id, frame: FrameClose(status: status, result: StreamNode(type: type)));
  StreamEnvelope _sig(StreamScope scope, String id, Map<String, dynamic> content) =>
      StreamEnvelope(seq: 0, scope: scope, id: id, frame: FrameSignal(node: StreamNode(type: 'run', content: content)));

  // ── write plane (F2) — mutate seeds + emit the same durable lifecycle signal the Live path would
  // see, so the detail/version providers reconcile through their normal re-fetch route.
  // 写面:改种子 + 发与 Live 同款 durable 生命周期信号,详情/版本 provider 走正常重取路收敛。
  @override
  Future<FunctionEntity> patchFunctionMeta(String id, Map<String, dynamic> patch) async {
    final e = await getFunction(id);
    final next = e.copyWith(
      name: (patch['name'] as String?) ?? e.name,
      description: (patch['description'] as String?) ?? e.description,
      tags: (patch['tags'] as List?)?.cast<String>() ?? e.tags,
    );
    upsertFunction(next);
    emitLifecycle(EntitySignal(
        kind: EntityKind.function, id: id, action: EntityAction.updated, durable: true));
    return next;
  }

  @override
  Future<WorkflowVersion> editWorkflow(String id, List<Map<String, Object?>> ops, {String? changeReason}) async {
    final wf = await getWorkflow(id);
    final cur = wf.activeVersion;
    final base = cur == null ? const Graph() : (graphOf(cur) ?? const Graph());
    final next = applyEditOps(base, ops);
    final version = (cur?.version ?? 0) + 1;
    final v = WorkflowVersion(
      id: '${id}_v$version',
      workflowId: id,
      version: version,
      graph: jsonEncode({
        'nodes': [for (final n in next.nodes) nodeWire(n)],
        'edges': [
          for (final e in next.edges)
            {'id': e.id, 'from': e.from, if ((e.fromPort ?? '').isNotEmpty) 'fromPort': e.fromPort, 'to': e.to}
        ],
      }),
      graphParsed: next,
      changeReason: changeReason,
      createdAt: DateTime.utc(2026, 6, 27, 13),
      updatedAt: DateTime.utc(2026, 6, 27, 13),
    );
    _workflowVersions[id] = [v, ...(_workflowVersions[id] ?? const [])];
    upsertWorkflow(wf.copyWith(activeVersionId: v.id, activeVersion: v));
    emitLifecycle(EntitySignal(
        kind: EntityKind.workflow, id: id, action: EntityAction.updated, durable: true));
    return v;
  }

  @override
  Future<WorkflowEntity> patchWorkflowMeta(String id, Map<String, dynamic> patch) async {
    final e = await getWorkflow(id);
    final next = e.copyWith(
      name: (patch['name'] as String?) ?? e.name,
      description: (patch['description'] as String?) ?? e.description,
      tags: (patch['tags'] as List?)?.cast<String>() ?? e.tags,
      concurrency: (patch['concurrency'] as String?) ?? e.concurrency,
    );
    upsertWorkflow(next);
    emitLifecycle(EntitySignal(
        kind: EntityKind.workflow, id: id, action: EntityAction.updated, durable: true));
    return next;
  }

  @override
  Future<void> revertVersion(EntityKind kind, String id, int version) async {
    T? pick<T>(List<T>? list, int Function(T) num) {
      final i = list?.indexWhere((x) => num(x) == version) ?? -1;
      return i < 0 ? null : list![i];
    }

    switch (kind) {
      case EntityKind.function:
        final v = pick(_functionVersions[id], (FunctionVersion x) => x.version);
        if (v == null) return;
        upsertFunction((await getFunction(id)).copyWith(activeVersionId: v.id, activeVersion: v));
      case EntityKind.handler:
        final v = pick(_handlerVersions[id], (HandlerVersion x) => x.version);
        if (v == null) return;
        upsertHandler((await getHandler(id)).copyWith(activeVersionId: v.id, activeVersion: v));
      case EntityKind.agent:
        final v = pick(_agentVersions[id], (AgentVersion x) => x.version);
        if (v == null) return;
        upsertAgent((await getAgent(id)).copyWith(activeVersionId: v.id, activeVersion: v));
      case EntityKind.workflow:
        final v = pick(_workflowVersions[id], (WorkflowVersion x) => x.version);
        if (v == null) return;
        upsertWorkflow((await getWorkflow(id)).copyWith(activeVersionId: v.id, activeVersion: v));
    }
    emitLifecycle(EntitySignal(kind: kind, id: id, action: EntityAction.updated, durable: true));
  }

  @override
  Future<FlowrunComposite> replayFlowrun(String flowrunId) async {
    final comp = _flowrunDetail[flowrunId];
    if (comp == null) throw StateError('FixtureEntityRepository: no flowrun $flowrunId');
    // :replay clears failed node rows + re-walks (record-once reuse). The fixture simply flips the
    // failed rows to completed + the header to completed, bumping replayCount. fixture:失败行翻完成。
    final now = DateTime.utc(2026, 6, 27, 11);
    final next = FlowrunComposite(
      flowrun: comp.flowrun.copyWith(
          status: 'completed', completedAt: now, replayCount: comp.flowrun.replayCount + 1),
      nodes: [
        for (final n in comp.nodes)
          n.status == 'failed'
              ? n.copyWith(status: 'completed', completedAt: now, updatedAt: now, error: null)
              : n,
      ],
    );
    _flowrunDetail[flowrunId] = next;
    return next;
  }

  @override
  Future<WorkflowEntity> killWorkflow(String id) async {
    final wf = await getWorkflow(id);
    final next = wf.copyWith(lifecycleState: 'inactive', active: false);
    upsertWorkflow(next);
    // Cancel every in-flight flowrun of this workflow. 硬停本 workflow 全部在途 run。
    for (final entry in _flowrunDetail.entries.toList()) {
      final comp = entry.value;
      if (comp.flowrun.workflowId == id &&
          (comp.flowrun.status == 'running' || comp.flowrun.status == 'parked')) {
        _flowrunDetail[entry.key] =
            FlowrunComposite(flowrun: comp.flowrun.copyWith(status: 'cancelled'), nodes: comp.nodes);
      }
    }
    emitLifecycle(EntitySignal(
        kind: EntityKind.workflow, id: id, action: EntityAction.updated, durable: true));
    return next;
  }

  @override
  Future<MountHealthReport> getMountHealth(String id) async =>
      _mountHealth[id] ?? const MountHealthReport(allHealthy: true);

  // ── realtime (scripted) ────────────────────────────────────────────────────
  @override
  Stream<EntitySignal> lifecycleSignals(EntityKind kind) => _lazyLifecycle(kind).stream;
  @override
  Stream<StreamEnvelope> panelSignals(StreamScope scope) => _lazyPanel(scope.key).stream;

  /// Script a lifecycle signal onto [kind]'s list stream (test/dev only). 脚本一条生命周期信号。
  void emitLifecycle(EntitySignal signal) => _lazyLifecycle(signal.kind).add(signal);

  /// Script a panel-realtime frame onto one scope's stream (test/dev only). 脚本一条面板实时帧。
  void emitPanel(StreamScope scope, StreamEnvelope env) => _lazyPanel(scope.key).add(env);

  // Upsert an entity AFTER construction (replace-by-id, else append) — lets a test/demo simulate a
  // server-side create (a new id, fetchable via getEntityRow though absent from the initial list) OR an
  // edit (same id, changed fields). 构造后 upsert(按 id 替换、否则追加):模拟服务端新建或编辑。
  void upsertFunction(FunctionEntity e) => _upsert(_functions, e, (x) => x.id);
  void upsertHandler(HandlerEntity e) => _upsert(_handlers, e, (x) => x.id);
  void upsertAgent(AgentEntity e) => _upsert(_agents, e, (x) => x.id);
  void upsertWorkflow(WorkflowEntity e) => _upsert(_workflows, e, (x) => x.id);

  static void _upsert<T>(List<T> list, T e, String Function(T) id) {
    final i = list.indexWhere((x) => id(x) == id(e));
    if (i >= 0) {
      list[i] = e;
    } else {
      list.add(e);
    }
  }

  StreamController<EntitySignal> _lazyLifecycle(EntityKind kind) =>
      _lifecycle.putIfAbsent(kind, () => StreamController<EntitySignal>.broadcast());
  StreamController<StreamEnvelope> _lazyPanel(String key) =>
      _panels.putIfAbsent(key, () => StreamController<StreamEnvelope>.broadcast());

  Future<void> dispose() async {
    for (final c in _lifecycle.values) {
      await c.close();
    }
    for (final c in _panels.values) {
      await c.close();
    }
    _lifecycle.clear();
    _panels.clear();
  }
}
