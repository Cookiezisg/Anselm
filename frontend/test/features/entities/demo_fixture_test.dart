import 'package:anselm/core/graph/force_layout.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/entities_overview_model.dart';
import 'package:flutter_test/flutter_test.dart';

// D-024/025/026/027/028 — the `make demo` entity fixture must SEED the control/approval logics, the
// handler/agent version trails, a parked (human-gated) flowrun, and the graph-editor ref candidates,
// so every entities-sea section shows a populated state instead of an empty placeholder.
// 每个实体海洋区段都有数据态而非空占位。
void main() {
  final repo = demoEntityRepository();

  test(
    'D-025 control: ctl_quality logic with pass/retry branches (rail control section)',
    () async {
      final rows = await repo.listEntities(EntityKind.control);
      expect(rows.items, isNotEmpty, reason: 'rail control 段非空');
      final ctl = await repo.getControl('ctl_quality');
      final branches = ctl.activeVersion!.branches;
      expect(branches.map((b) => b.port), containsAll(['pass', 'retry']));
      expect(branches.last.when, 'true', reason: '末支 catch-all');
      // The wf_digest graph routes on this exact control ref. 图按此 ref 路由。
      expect(
        (await repo.listControls()).any((c) => c.id == 'ctl_quality'),
        isTrue,
      );
    },
  );

  test(
    'D-024 approval: ap_publish form with template + decision rules (rail approval section)',
    () async {
      final rows = await repo.listEntities(EntityKind.approval);
      expect(rows.items, isNotEmpty, reason: 'rail approval 段非空');
      final ap = await repo.getApproval('ap_publish');
      final v = ap.activeVersion!;
      expect(v.template, contains('{{ input.version }}'), reason: 'CEL 插值模板');
      expect(v.allowReason, isTrue);
      expect(v.timeout, isNotEmpty, reason: 'timeout+behavior 决策规则');
      expect(v.timeoutBehavior, isNotEmpty);
    },
  );

  test(
    'D-026 parked flowrun: a run halted at its human approval gate',
    () async {
      final inbox = await repo.listFlowrunInbox();
      expect(
        inbox.any((n) => n.status == 'parked' && n.kind == 'approval'),
        isTrue,
        reason: '收件箱有停车',
      );
      final comp = await repo.getFlowrun('flr_park');
      final parked = comp.nodes.firstWhere((n) => n.nodeId == 'approve_deploy');
      expect(parked.status, 'parked');
      expect(parked.result['rendered'], isNotNull, reason: '渲染出的信笺');
    },
  );

  test(
    'D-027 version history: handler + agent version trails (history tab)',
    () async {
      final hv = await repo.listHandlerVersions('hd_slack');
      expect(hv.items.length, greaterThanOrEqualTo(2), reason: 'handler 多版本轨迹');
      final av = await repo.listAgentVersions('ag_researcher');
      expect(av.items.length, greaterThanOrEqualTo(3), reason: 'agent 多版本轨迹');
      // Newest first. 最新在前。
      expect(av.items.first.version, greaterThan(av.items.last.version));
    },
  );

  test(
    'D-028 ref candidates: MCP server/tool candidates for the graph editor picker',
    () async {
      final servers = await repo.listMcpServers();
      expect(servers, isNotEmpty, reason: 'mcp server 候选');
      final tools = await repo.listMcpTools('context7');
      expect(tools, isNotEmpty, reason: 'mcp 工具候选');
      // control/approval ref candidates derive from the seeded logics/forms. 控制/审批候选自实体派生。
      expect(await repo.listControls(), isNotEmpty);
      expect(await repo.listApprovals(), isNotEmpty);
    },
  );

  // WRK-072 — the Overview relationship graph seed: a satisfying full graph (2 star hubs + skill/mcp/
  // document edges + in-degree-0 workflow sources + conversation provenance for the toggle). 总览关系图种子。
  group('WRK-072 relationship graph seed', () {
    test(
      'the snapshot spans all node kinds incl. skill/mcp/document/conversation',
      () async {
        final g = await repo.getRelGraph();
        final kinds = {for (final n in g.nodes) n.kind};
        expect(
          kinds,
          containsAll([
            'function',
            'handler',
            'agent',
            'workflow',
            'trigger',
            'control',
            'approval',
          ]),
        );
        expect(
          kinds,
          containsAll(['skill', 'mcp', 'document', 'conversation']),
          reason:
              'accessory kinds appear on the graph (never in the 7-value rail)',
        );
        expect(
          g.nodes.length,
          greaterThanOrEqualTo(20),
          reason: '20+ node satisfying graph',
        );
      },
    );

    test(
      'fn_normalize + hd_slack are the star hubs (highest structural in-degree)',
      () async {
        final g = await repo.getRelGraph();
        final sub = structuralSubgraph(g);
        final deg = inDegrees([
          for (final e in sub.edges) (from: e.fromId, to: e.toId),
        ]);
        expect(
          deg['fn_normalize'],
          greaterThanOrEqualTo(3),
          reason: 'referenced by wf_invoice + 2 agents',
        );
        expect(
          deg['hd_slack'],
          greaterThanOrEqualTo(2),
          reason: 'equipped by wf_digest + wf_release',
        );
        // Workflow sources are depended-on by nothing → in-degree 0 (render smallest). 顶层 workflow 入度 0。
        expect(deg['wf_digest'] ?? 0, 0);
      },
    );

    // v2「涟漪焦点星图」 data battery: the seed must exercise COMPONENT PACKING — the structural subgraph
    // spans ≥2 disconnected components (wf_onboard/hd_twilio hangs off nothing else). NOTE: there is no
    // zero-degree ISOLATE in the seed by design — the backend never emits an entity with no relations
    // (relation.go dedupes edge endpoints), so an isolate would misrepresent real data; the force engine's
    // isolate band is locked by the gallery specimen + force_layout_test instead. 分量打包电池:结构子图≥2 分量;
    // 刻意无零度孤点(后端不发无关系实体,加孤点=造假),孤点带由 gallery+force_layout_test 锁。
    test(
      'the structural subgraph spans ≥2 connected components (packing exercised)',
      () async {
        final g = await repo.getRelGraph();
        final sub = structuralSubgraph(g);
        final comps = connectedComponents(
          {for (final n in sub.nodes) n.id},
          [for (final e in sub.edges) ForceEdge(e.fromId, e.toId)],
        );
        expect(
          comps.length,
          greaterThanOrEqualTo(2),
          reason:
              'wf_onboard/hd_twilio is a separate component → the packer runs',
        );
        expect(
          comps.every((c) => c.length >= 2),
          isTrue,
          reason: 'no degree-0 isolate in real data',
        );
      },
    );

    test(
      'provenance edges exist but are excluded from the observing (structural) subgraph',
      () async {
        final g = await repo.getRelGraph();
        expect(
          g.edges.any((e) => e.kind == 'create' || e.kind == 'edit'),
          isTrue,
          reason: '溯源边在数据里',
        );
        final sub = structuralSubgraph(g);
        expect(
          sub.edges.every((e) => e.kind == 'equip' || e.kind == 'link'),
          isTrue,
          reason: 'observing state drops create/edit',
        );
        // The conversation nodes only hang off provenance edges → absent from the structural subgraph.
        // 对话节点只挂溯源边→结构子图里没有。
        expect(sub.nodes.any((n) => n.kind == 'conversation'), isFalse);
      },
    );

    test('every edge name is hydrated (not a raw id)', () async {
      final g = await repo.getRelGraph();
      for (final e in g.edges) {
        expect(e.fromName, isNotEmpty);
        expect(e.toName, isNotEmpty);
      }
    });
  });
}
