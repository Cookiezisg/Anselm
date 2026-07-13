import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:flutter_test/flutter_test.dart';

// D-024/025/026/027/028 — the `make demo` entity fixture must SEED the control/approval logics, the
// handler/agent version trails, a parked (human-gated) flowrun, and the graph-editor ref candidates,
// so every entities-sea section shows a populated state instead of an empty placeholder.
// 每个实体海洋区段都有数据态而非空占位。
void main() {
  final repo = demoEntityRepository();

  test('D-025 control: ctl_quality logic with pass/retry branches (rail control section)', () async {
    final rows = await repo.listEntities(EntityKind.control);
    expect(rows.items, isNotEmpty, reason: 'rail control 段非空');
    final ctl = await repo.getControl('ctl_quality');
    final branches = ctl.activeVersion!.branches;
    expect(branches.map((b) => b.port), containsAll(['pass', 'retry']));
    expect(branches.last.when, 'true', reason: '末支 catch-all');
    // The wf_digest graph routes on this exact control ref. 图按此 ref 路由。
    expect((await repo.listControls()).any((c) => c.id == 'ctl_quality'), isTrue);
  });

  test('D-024 approval: ap_publish form with template + decision rules (rail approval section)', () async {
    final rows = await repo.listEntities(EntityKind.approval);
    expect(rows.items, isNotEmpty, reason: 'rail approval 段非空');
    final ap = await repo.getApproval('ap_publish');
    final v = ap.activeVersion!;
    expect(v.template, contains('{{ input.version }}'), reason: 'CEL 插值模板');
    expect(v.allowReason, isTrue);
    expect(v.timeout, isNotEmpty, reason: 'timeout+behavior 决策规则');
    expect(v.timeoutBehavior, isNotEmpty);
  });

  test('D-026 parked flowrun: a run halted at its human approval gate', () async {
    final inbox = await repo.listFlowrunInbox();
    expect(inbox.any((n) => n.status == 'parked' && n.kind == 'approval'), isTrue, reason: '收件箱有停车');
    final comp = await repo.getFlowrun('flr_park');
    final parked = comp.nodes.firstWhere((n) => n.nodeId == 'approve_deploy');
    expect(parked.status, 'parked');
    expect(parked.result['rendered'], isNotNull, reason: '渲染出的信笺');
  });

  test('D-027 version history: handler + agent version trails (history tab)', () async {
    final hv = await repo.listHandlerVersions('hd_slack');
    expect(hv.items.length, greaterThanOrEqualTo(2), reason: 'handler 多版本轨迹');
    final av = await repo.listAgentVersions('ag_researcher');
    expect(av.items.length, greaterThanOrEqualTo(3), reason: 'agent 多版本轨迹');
    // Newest first. 最新在前。
    expect(av.items.first.version, greaterThan(av.items.last.version));
  });

  test('D-028 ref candidates: MCP server/tool candidates for the graph editor picker', () async {
    final servers = await repo.listMcpServers();
    expect(servers, isNotEmpty, reason: 'mcp server 候选');
    final tools = await repo.listMcpTools('context7');
    expect(tools, isNotEmpty, reason: 'mcp 工具候选');
    // control/approval ref candidates derive from the seeded logics/forms. 控制/审批候选自实体派生。
    expect(await repo.listControls(), isNotEmpty);
    expect(await repo.listApprovals(), isNotEmpty);
  });
}
