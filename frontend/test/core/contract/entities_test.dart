import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/common.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 0 gate (Phase 4.1 entities) — the entity contract layer mirrors the backend Quadrinity DTO wire
// EXACTLY. Identity round-trips prove the freezed/json_serializable wiring (incl. explicit_to_json on
// nested objects); the wire-key tests pin the three non-obvious mappings (NodeKind unknown fallback,
// `default` reserved-word rename, nested object — not stringified — serialization).

final _t0 = DateTime.utc(2026, 6, 26, 0, 0, 0);
final _t1 = DateTime.utc(2026, 6, 26, 1, 0, 0);

void main() {
  group('Function domain round-trip', () {
    test('FunctionEntity + embedded version + I/O fields', () {
      final fn = FunctionEntity(
        id: 'fn_0123456789abcdef',
        name: 'sum',
        description: 'add two numbers',
        tags: const ['math'],
        activeVersionId: 'fnv_1',
        createdAt: _t0,
        updatedAt: _t1,
        activeVersion: FunctionVersion(
          id: 'fnv_1',
          functionId: 'fn_0123456789abcdef',
          version: 3,
          code: 'def main(a, b): return a + b',
          inputs: const [
            Field(name: 'a', type: 'number'),
            Field(name: 'b', type: 'number'),
          ],
          outputs: const [
            Field(name: 'result', type: 'number', description: 'the sum'),
          ],
          dependencies: const ['numpy'],
          envStatus: 'ready',
          createdAt: _t0,
          updatedAt: _t1,
        ),
      );
      expect(FunctionEntity.fromJson(fn.toJson()), fn);
      // explicit_to_json: nested version + fields serialize as objects, not toString.
      final j = fn.toJson();
      expect(j['activeVersion'], isA<Map<String, dynamic>>());
      expect((j['activeVersion'] as Map)['inputs'], isA<List>());
    });

    test('FunctionRunResult is the bare (un-enveloped) shape', () {
      const r = FunctionRunResult(
        ok: true,
        output: 5,
        elapsedMs: 12,
        logs: 'ran',
      );
      expect(FunctionRunResult.fromJson(r.toJson()), r);
      // default when fields absent
      final empty = FunctionRunResult.fromJson(const {});
      expect(empty.ok, isFalse);
      expect(empty.elapsedMs, 0);
    });

    test('FunctionExecution log row round-trips with flowrun provenance', () {
      final ex = FunctionExecution(
        id: 'fnx_1',
        functionId: 'fn_0123456789abcdef',
        versionId: 'fnv_1',
        status: 'ok',
        triggeredBy: 'user',
        input: const {'a': 1, 'b': 2},
        output: 3,
        elapsedMs: 9,
        flowrunId: 'flr_1',
        flowrunNodeId: 'n2',
        flowrunIteration: 0,
        createdAt: _t0,
      );
      expect(FunctionExecution.fromJson(ex.toJson()), ex);
    });
  });

  group('Handler domain round-trip', () {
    test(
      'HandlerEntity + computed state + version with methods/initArgs/env mirror',
      () {
        final hd = HandlerEntity(
          id: 'hd_0123456789abcdef',
          name: 'slack',
          activeVersionId: 'hdv_1',
          createdAt: _t0,
          updatedAt: _t1,
          configState: 'ready',
          missingConfig: const [],
          runtimeState: 'running',
          activeVersion: HandlerVersion(
            id: 'hdv_1',
            handlerId: 'hd_0123456789abcdef',
            version: 2,
            imports: 'import slack_sdk',
            initBody: 'self.client = ...',
            methods: const [
              MethodSpec(
                name: 'post',
                inputs: [Field(name: 'channel', type: 'string')],
                body: 'self.client.post(channel)',
                streaming: false,
              ),
            ],
            initArgsSchema: const [
              InitArgSpec(
                name: 'token',
                type: 'string',
                required: true,
                sensitive: true,
                defaultValue: '',
              ),
            ],
            envStatus: 'ready',
            createdAt: _t0,
            updatedAt: _t1,
          ),
        );
        expect(HandlerEntity.fromJson(hd.toJson()), hd);
      },
    );

    test(
      'InitArgSpec maps `defaultValue` ↔ wire `default` (reserved word)',
      () {
        const arg = InitArgSpec(
          name: 'region',
          type: 'string',
          defaultValue: 'us-east',
        );
        final j = arg.toJson();
        expect(j.containsKey('default'), isTrue);
        expect(j.containsKey('defaultValue'), isFalse);
        expect(j['default'], 'us-east');
        expect(
          InitArgSpec.fromJson({
            'name': 'region',
            'type': 'string',
            'default': 'us-east',
          }),
          arg,
        );
      },
    );

    test(
      'HandlerCall adds method + instanceId + logs over the execution shape',
      () {
        final call = HandlerCall(
          id: 'hdc_1',
          handlerId: 'hd_0123456789abcdef',
          versionId: 'hdv_1',
          method: 'post',
          instanceId: 'inst_1',
          status: 'ok',
          input: const {'channel': '#general'},
          logs: 'sent',
          elapsedMs: 40,
          createdAt: _t0,
        );
        expect(HandlerCall.fromJson(call.toJson()), call);
      },
    );
  });

  group('Agent domain round-trip', () {
    test(
      'AgentEntity + version with tools/knowledge/modelOverride (reused ModelRef)',
      () {
        final ag = AgentEntity(
          id: 'ag_0123456789abcdef',
          name: 'researcher',
          activeVersionId: 'agv_1',
          createdAt: _t0,
          updatedAt: _t1,
          activeVersion: AgentVersion(
            id: 'agv_1',
            agentId: 'ag_0123456789abcdef',
            version: 1,
            prompt: 'You are a researcher.',
            skill: 'deep-research',
            knowledge: const ['doc_1', 'doc_2'],
            tools: const [ToolRef(ref: 'fn_0123456789abcdef', name: 'sum')],
            inputs: const [Field(name: 'topic', type: 'string')],
            modelOverride: const ModelRef(
              apiKeyId: 'key_1',
              modelId: 'claude-opus-4-8',
            ),
            createdAt: _t0,
            updatedAt: _t1,
          ),
        );
        expect(AgentEntity.fromJson(ag.toJson()), ag);
        // explicit_to_json: modelOverride + tools nest as objects.
        final v = ag.toJson()['activeVersion'] as Map;
        expect(v['modelOverride'], isA<Map<String, dynamic>>());
        expect((v['tools'] as List).first, isA<Map<String, dynamic>>());
      },
    );

    test('InvokeResult is the bare shape with token/step counters', () {
      const r = InvokeResult(
        executionId: 'agx_1',
        ok: true,
        output: 'done',
        status: 'completed',
        stopReason: 'end_turn',
        steps: 4,
        tokensIn: 1200,
        tokensOut: 340,
        elapsedMs: 5000,
      );
      expect(InvokeResult.fromJson(r.toJson()), r);
    });

    test('AgentExecution carries model + transcript, no logs field', () {
      final ex = AgentExecution(
        id: 'agx_1',
        agentId: 'ag_0123456789abcdef',
        status: 'ok',
        input: const {'topic': 'llm'},
        output: 'summary',
        modelId: 'claude-opus-4-8',
        apiKeyId: 'key_1',
        provider: 'anthropic',
        transcript: const [
          {'role': 'user', 'content': 'hi'},
        ],
        createdAt: _t0,
      );
      expect(AgentExecution.fromJson(ex.toJson()), ex);
    });

    test('MountHealthReport round-trips', () {
      const rep = MountHealthReport(
        mounts: [
          MountHealth(ref: 'fn_0123456789abcdef', name: 'sum', healthy: true),
        ],
        allHealthy: true,
      );
      expect(MountHealthReport.fromJson(rep.toJson()), rep);
    });
  });

  group('Workflow domain round-trip', () {
    test('WorkflowEntity + version with parsed graph (nodes/edges)', () {
      final wf = WorkflowEntity(
        id: 'wf_0123456789abcdef',
        name: 'pipeline',
        active: true,
        lifecycleState: 'active',
        concurrency: 'serial',
        lastActionBy: 'user',
        activeVersionId: 'wfv_1',
        createdAt: _t0,
        updatedAt: _t1,
        activeVersion: WorkflowVersion(
          id: 'wfv_1',
          workflowId: 'wf_0123456789abcdef',
          version: 1,
          graph: '{"nodes":[],"edges":[]}',
          createdAt: _t0,
          updatedAt: _t1,
          graphParsed: const Graph(
            nodes: [
              Node(id: 'n1', kind: NodeKind.trigger, ref: 'tr_1'),
              Node(
                id: 'n2',
                kind: NodeKind.action,
                ref: 'fn_0123456789abcdef',
                input: {'a': 'n1.output'},
                retry: RetryConfig(
                  maxAttempts: 3,
                  backoff: 'exponential',
                  delayMs: 1000,
                ),
                pos: NodePosition(x: 100, y: 200),
              ),
            ],
            edges: [Edge(id: 'e1', from: 'n1', to: 'n2')],
          ),
        ),
      );
      expect(WorkflowEntity.fromJson(wf.toJson()), wf);
    });

    test('Node.kind falls back to unknown for an unrecognized kind', () {
      final n = Node.fromJson({'id': 'n9', 'kind': 'loop'});
      expect(n.kind, NodeKind.unknown);
      final known = Node.fromJson({'id': 'n1', 'kind': 'agent'});
      expect(known.kind, NodeKind.agent);
    });

    test('Edge.fromPort present only on branch outputs', () {
      const branch = Edge(id: 'e2', from: 'n3', fromPort: 'yes', to: 'n4');
      expect(Edge.fromJson(branch.toJson()), branch);
      expect(branch.toJson()['fromPort'], 'yes');
    });

    test(
      'FlowrunComposite = flowrun + nodes + nextCursor (bespoke decode)',
      () {
        final comp = FlowrunComposite(
          flowrun: Flowrun(
            id: 'flr_1',
            workflowId: 'wf_0123456789abcdef',
            versionId: 'wfv_1',
            pinnedRefs: const {'fn_x': 'fnv_2'},
            status: 'running',
            replayCount: 0,
            startedAt: _t0,
            updatedAt: _t1,
          ),
          nodes: [
            FlowrunNode(
              id: 'frn_1',
              flowrunId: 'flr_1',
              nodeId: 'n1',
              iteration: 0,
              kind: 'trigger',
              ref: 'tr_1',
              status: 'completed',
              result: const {'fired': true},
              createdAt: _t0,
              completedAt: _t1,
              updatedAt: _t1,
            ),
          ],
          nextCursor: 'cur_2',
        );
        expect(FlowrunComposite.fromJson(comp.toJson()), comp);
      },
    );
  });

  group('Cross-entity common round-trip', () {
    test('ExecutionAggregates ok/failed tallies', () {
      const agg = ExecutionAggregates(okCount: 10, failedCount: 2);
      expect(ExecutionAggregates.fromJson(agg.toJson()), agg);
      expect(ExecutionAggregates.fromJson(const {}).okCount, 0);
    });

    test('CapabilityReport problems block / warnings inform', () {
      const rep = CapabilityReport(
        structurallyValid: true,
        resolved: false,
        problems: ['unresolved ref fn_missing'],
        warnings: ['no description'],
      );
      expect(CapabilityReport.fromJson(rep.toJson()), rep);
    });
  });
}
