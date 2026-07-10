import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/chat/ui/stages/scene_from_truth.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 7, 10);

// sceneFromTruth pure core (WRK-064): a settled entity's truth → a live:false StageScene the bespoke body
// renders as «current truth». No Ref, no async — feeds a fixture DTO, asserts the synthesized scene.
// 纯核心:真身→live:false 场景,喂 fixture DTO 断言合成。

FunctionEntity _fn({String code = 'print(1)', bool noVersion = false}) {
  final now = DateTime.utc(2026, 7, 10);
  return FunctionEntity(
    id: 'fn_1',
    name: 'sync_inventory',
    createdAt: now,
    updatedAt: now,
    activeVersion: noVersion
        ? null
        : FunctionVersion(id: 'v1', functionId: 'fn_1', version: 4, code: code, createdAt: now, updatedAt: now),
  );
}

void main() {
  test('function → a live:false scene whose session yields the code (create semantics, no edit target)', () {
    final scene =
        sceneFromTruth(kind: 'function', truth: _fn(code: 'def main():\n  return 1'), id: 'fn_1', conversationId: 'cv', rowId: 'r');
    expect(scene, isNotNull);
    expect(scene!.live, isFalse); // node.status=completed ⇒ not live
    expect(scene.failed, isFalse); // phase=following ⇒ not failed-hold
    expect(scene.editTargetId, isNull); // create_ semantics: no GET / no diff / no old stratum
    expect(scene.session.liveStringNamed('code'), 'def main():\n  return 1');
    expect(scene.subject.kind, 'function');
    expect(scene.subject.itemId, 'fn_1');
  });

  test('function with no active version → null (caller degrades to the summary)', () {
    expect(sceneFromTruth(kind: 'function', truth: _fn(noVersion: true), id: 'fn_1', conversationId: 'cv', rowId: 'r'),
        isNull);
  });

  test('hasTruthStage gates the truth-stage kinds; a summary-only kind stays out', () {
    expect(hasTruthStage('function'), isTrue);
    expect(hasTruthStage('workflow'), isTrue);
    expect(hasTruthStage('mcp'), isFalse);
    expect(hasTruthStage('attachment'), isFalse);
    expect(hasTruthStage('subagent'), isFalse);
  });

  test('workflow → the final graph replayed as add_node / add_edge ops (the settled canvas)', () {
    final wf = WorkflowEntity(
      id: 'wf_1',
      name: 'invoice_reconcile',
      createdAt: _now,
      updatedAt: _now,
      activeVersion: WorkflowVersion(
        id: 'v1',
        workflowId: 'wf_1',
        version: 1,
        createdAt: _now,
        updatedAt: _now,
        graphParsed: Graph(
          nodes: [
            const Node(id: 'n1', kind: NodeKind.action, ref: 'pull_invoices'),
            const Node(id: 'n2', kind: NodeKind.control, ref: 'amount_gate'),
          ],
          edges: [const Edge(id: 'e1', from: 'n1', to: 'n2', fromPort: 'ok')],
        ),
      ),
    );
    final scene = sceneFromTruth(kind: 'workflow', truth: wf, id: 'wf_1', conversationId: 'cv', rowId: 'r');
    expect(scene, isNotNull);
    expect(scene!.live, isFalse);
    final ops = scene.session.arrayItemsAt(['ops']);
    expect(ops.length, 3); // 2 add_node + 1 add_edge
    final addNodes = ops.whereType<Map>().where((o) => o['op'] == 'add_node').toList();
    expect(addNodes.length, 2);
    expect((addNodes.first['node'] as Map)['kind'], 'action'); // NodeKind → its .name string
  });

  test('workflow with no active version / no graph → null', () {
    final wf = WorkflowEntity(id: 'wf_1', name: 'x', createdAt: _now, updatedAt: _now);
    expect(sceneFromTruth(kind: 'workflow', truth: wf, id: 'wf_1', conversationId: 'cv', rowId: 'r'), isNull);
  });

  test('agent → prompt + belt tools + knowledge in the session (modelOverride null projects to null)', () {
    final ag = AgentEntity(
      id: 'ag_1',
      name: 'researcher',
      createdAt: _now,
      updatedAt: _now,
      activeVersion: AgentVersion(
        id: 'v1',
        agentId: 'ag_1',
        version: 2,
        prompt: 'You are a research assistant.\nBe precise.',
        knowledge: const ['doc_1'],
        tools: const [ToolRef(ref: 'read', name: 'read'), ToolRef(ref: 'grep', name: 'grep')],
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    final scene = sceneFromTruth(kind: 'agent', truth: ag, id: 'ag_1', conversationId: 'cv', rowId: 'r');
    expect(scene, isNotNull);
    expect(scene!.session.liveStringNamed('prompt'), 'You are a research assistant.\nBe precise.');
    expect(scene.session.arrayItemsAt(['tools']).length, 2);
    expect(scene.session.arrayItemsAt(['knowledge']).length, 1);
  });

  test('document → an edit_document scene (editTargetId resolves) whose session yields the content', () {
    final doc = DocumentNode(id: 'doc_1', name: '月度对账模板', content: '# 模板\n第一行', createdAt: _now, updatedAt: _now);
    final scene = sceneFromTruth(kind: 'document', truth: doc, id: 'doc_1', conversationId: 'cv', rowId: 'r');
    expect(scene, isNotNull);
    expect(scene!.editTargetId, 'doc_1'); // edit_document → 'id' key → the byte badge / path light up
    expect(scene.session.closedStringAt(['content']), '# 模板\n第一行');
  });

  test('trigger → an edit_trigger scene carrying kind + config', () {
    final trig = TriggerEntity(
      id: 'trg_1',
      name: 'github-push',
      kind: TriggerSource.webhook,
      config: const {'path': '/hooks/gh'},
      createdAt: _now,
      updatedAt: _now,
    );
    final scene = sceneFromTruth(kind: 'trigger', truth: trig, id: 'trg_1', conversationId: 'cv', rowId: 'r');
    expect(scene, isNotNull);
    expect(scene!.editTargetId, 'trg_1'); // edit_trigger → 'triggerId'
    expect(scene.session.closedStringAt(['kind']), 'webhook'); // TriggerSource → .name
  });
}
