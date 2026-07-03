import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/workspace.dart';
import 'entity_fixtures.dart';

/// A realistic zero-backend seed for `make demo` (the real AppShell driven by fixtures) + the detail-sea
/// screenshots/tests: each kind has entities with an embedded activeVersion (so overviews render), plus
/// version history, execution/call logs, and one workflow flowrun. NOT used by the live app (which wires
/// LiveEntityRepository); the demo entry swaps the repository seam to this via one ProviderScope override.
///
/// `make demo`(真 AppShell + fixture)+ 详情截图/测试的零后端种子:每 kind 实体带 activeVersion(概览有内容)+
/// 版本历史 + 执行/调用日志 + 一个 workflow flowrun。非 live app 用;demo 入口经一次 override 切到此。
FixtureEntityRepository demoEntityRepository() {
  final t0 = DateTime.utc(2026, 6, 20, 9, 0);
  final t1 = DateTime.utc(2026, 6, 25, 14, 30);

  FunctionVersion fnVer(String fnId, int v, String code, String reason) => FunctionVersion(
        id: '${fnId}_v$v',
        functionId: fnId,
        version: v,
        code: code,
        inputs: const [Field(name: 'text', type: 'string', description: 'raw input')],
        outputs: const [Field(name: 'result', type: 'string')],
        dependencies: const ['pydantic'],
        envStatus: 'ready',
        envId: 'env_$fnId',
        envSyncedAt: t1,
        changeReason: reason,
        createdAt: v == 1 ? t0 : t1,
        updatedAt: v == 1 ? t0 : t1,
      );

  FunctionEntity fn(String id, String name, String desc, String code) => FunctionEntity(
        id: id,
        name: name,
        description: desc,
        tags: const ['util'],
        activeVersionId: '${id}_v2',
        createdAt: t0,
        updatedAt: t1,
        activeVersion: fnVer(id, 2, code, 'tighten validation'),
      );

  HandlerEntity hd(String id, String name, String desc, String runtime, String config,
          List<String> missing) =>
      HandlerEntity(
        id: id,
        name: name,
        description: desc,
        activeVersionId: '${id}_v1',
        createdAt: t0,
        updatedAt: t1,
        runtimeState: runtime,
        configState: config,
        missingConfig: missing,
        activeVersion: HandlerVersion(
          id: '${id}_v1',
          handlerId: id,
          version: 1,
          imports: 'import os\nimport httpx',
          initBody: 'self.token = args["token"]\nself.client = httpx.Client()',
          shutdownBody: 'self.client.close()',
          methods: const [
            MethodSpec(name: 'post', inputs: [Field(name: 'channel', type: 'string')], outputs: [Field(name: 'ts', type: 'string')], body: 'return self.client.post(...)'),
            MethodSpec(name: 'stream', body: 'yield from ...', streaming: true, timeout: 30000),
          ],
          initArgsSchema: const [
            InitArgSpec(name: 'token', type: 'string', required: true, sensitive: true, defaultValue: 'xoxb-***'),
            InitArgSpec(name: 'region', type: 'string', defaultValue: 'us'),
          ],
          envStatus: 'ready',
          createdAt: t0,
          updatedAt: t1,
        ),
      );

  AgentEntity ag(String id, String name, String desc, {bool override = false}) => AgentEntity(
        id: id,
        name: name,
        description: desc,
        activeVersionId: '${id}_v3',
        createdAt: t0,
        updatedAt: t1,
        activeVersion: AgentVersion(
          id: '${id}_v3',
          agentId: id,
          version: 3,
          prompt: 'You are $name. Be precise and cite sources.',
          skill: 'deep-research',
          knowledge: const ['doc_handbook', 'doc_style'],
          tools: const [
            ToolRef(ref: 'fn_normalize', name: 'normalize'),
            ToolRef(ref: 'hd_slack.post', name: 'post-slack'),
            ToolRef(ref: 'mcp:search/web', name: 'web-search'),
          ],
          inputs: const [Field(name: 'topic', type: 'string')],
          outputs: const [Field(name: 'summary', type: 'string')],
          modelOverride: override ? const ModelRef(apiKeyId: 'key_anthropic', modelId: 'claude-opus-4-8') : null,
          changeReason: 'add web-search tool',
          createdAt: t1,
          updatedAt: t1,
        ),
      );

  // v2 grows a quality gate: control node routes pass→post / retry→back to the researcher (a real
  // back edge, so the demo shows the full edge language). v2 长出质检门:pass→发布、retry 回边回研究。
  const graph =
      '{"nodes":[{"id":"on_schedule","kind":"trigger","ref":"tr_cron"},{"id":"research","kind":"agent","ref":"ag_researcher"},{"id":"summarize","kind":"action","ref":"fn_summarize"},{"id":"quality_gate","kind":"control","ref":"ctl_quality"},{"id":"post_slack","kind":"action","ref":"hd_slack.post"}],"edges":[{"id":"e1","from":"on_schedule","to":"research"},{"id":"e2","from":"research","to":"summarize"},{"id":"e3","from":"summarize","to":"quality_gate"},{"id":"e4","from":"quality_gate","fromPort":"pass","to":"post_slack"},{"id":"e5","from":"quality_gate","fromPort":"retry","to":"research"}]}';
  const graphV1 =
      '{"nodes":[{"id":"on_schedule","kind":"trigger","ref":"tr_cron"},{"id":"research","kind":"agent","ref":"ag_researcher"},{"id":"summarize","kind":"action","ref":"fn_summarize"},{"id":"post_slack","kind":"action","ref":"hd_slack.post"}],"edges":[{"id":"e1","from":"on_schedule","to":"research"},{"id":"e2","from":"research","to":"summarize"},{"id":"e3","from":"summarize","to":"post_slack"}]}';

  WorkflowEntity wf(String id, String name, String desc, String lifecycle,
          {bool active = false, bool attention = false, String? reason}) =>
      WorkflowEntity(
        id: id,
        name: name,
        description: desc,
        active: active,
        lifecycleState: lifecycle,
        concurrency: 'skip',
        needsAttention: attention,
        attentionReason: reason,
        lastActionBy: 'user',
        activeVersionId: '${id}_v1',
        createdAt: t0,
        updatedAt: t1,
        activeVersion: WorkflowVersion(
          id: '${id}_v1',
          workflowId: id,
          version: 1,
          graph: graph,
          changeReason: 'initial pipeline',
          createdAt: t0,
          updatedAt: t1,
        ),
      );

  WorkflowVersion wfVer(String id, int version, String g, String reason) => WorkflowVersion(
        id: '${id}_v$version',
        workflowId: id,
        version: version,
        graph: g,
        changeReason: reason,
        createdAt: version == 1 ? t0 : t1,
        updatedAt: t1,
      );

  FunctionExecution fnExec(String fnId, String suffix, String status, int ms) => FunctionExecution(
        id: 'fnx_$suffix',
        functionId: fnId,
        versionId: '${fnId}_v2',
        status: status,
        triggeredBy: 'user',
        input: const {'text': '  Hello  '},
        output: status == 'ok' ? 'hello' : null,
        errorMessage: status == 'ok' ? null : 'ValueError: empty',
        elapsedMs: ms,
        startedAt: t1,
        endedAt: t1,
        createdAt: t1,
      );

  return FixtureEntityRepository(
    functions: [
      fn('fn_normalize', 'normalize-input', 'Coerce + trim raw fields', 'def main(text):\n    return text.strip().lower()'),
      fn('fn_validate', 'validate-schema', 'JSON-schema validate a payload', 'def main(payload):\n    validate(payload)\n    return True'),
      fn('fn_weather', 'fetch-weather', 'Call the weather API', 'def main(city):\n    return api.get(city)'),
      fn('fn_summarize', 'summarize-text', 'LLM summarize a document', 'def main(doc):\n    return llm.summarize(doc)'),
    ],
    handlers: [
      hd('hd_slack', 'slack', 'Slack workspace client', 'running', 'ready', const []),
      hd('hd_postgres', 'postgres', 'Primary database', 'running', 'ready', const []),
      hd('hd_stripe', 'stripe', 'Payments', 'crashed', 'ready', const []),
      hd('hd_twilio', 'twilio', 'SMS — not configured yet', 'stopped', 'partially_configured', const ['authToken']),
    ],
    agents: [
      ag('ag_researcher', 'researcher', 'Deep-research agent', override: true),
      ag('ag_triager', 'triager', 'Routes inbound issues'),
    ],
    workflows: [
      wf('wf_digest', 'daily-digest', 'Summarize + post each morning', 'active', active: true)
          .copyWith(
              activeVersionId: 'wf_digest_v2',
              activeVersion: wfVer('wf_digest', 2, graph, 'add quality gate + retry loop'),
              tags: const ['daily', 'digest']),
      wf('wf_invoice', 'invoice-sync', 'Sync invoices to the ledger', 'active', active: true, attention: true, reason: 'last run failed'),
      wf('wf_onboard', 'onboarding', 'New-user onboarding steps', 'inactive'),
    ],
    functionVersions: {
      'fn_normalize': [
        fnVer('fn_normalize', 2, 'def main(text):\n    return text.strip().lower()', 'tighten validation'),
        fnVer('fn_normalize', 1, 'def main(text):\n    return text.strip()', 'initial'),
      ],
    },
    workflowVersions: {
      'wf_digest': [
        wfVer('wf_digest', 2, graph, 'add quality gate + retry loop'),
        wfVer('wf_digest', 1, graphV1, 'initial pipeline'),
      ],
    },
    functionExecutions: {
      'fn_normalize': [
        fnExec('fn_normalize', '1', 'ok', 12),
        fnExec('fn_normalize', '2', 'ok', 9),
        fnExec('fn_normalize', '3', 'failed', 4),
      ],
    },
    handlerCalls: {
      'hd_slack': [
        HandlerCall(id: 'hdc_1', handlerId: 'hd_slack', versionId: 'hd_slack_v1', method: 'post', status: 'ok', triggeredBy: 'workflow', input: const {'channel': '#general'}, output: 'ts_123', elapsedMs: 240, instanceId: 'inst_a', createdAt: t1),
        HandlerCall(id: 'hdc_2', handlerId: 'hd_slack', versionId: 'hd_slack_v1', method: 'post', status: 'failed', triggeredBy: 'user', input: const {'channel': '#bad'}, errorMessage: 'channel_not_found', elapsedMs: 130, createdAt: t1),
      ],
    },
    agentExecutions: {
      'ag_researcher': [
        AgentExecution(id: 'agx_1', agentId: 'ag_researcher', versionId: 'ag_researcher_v3', status: 'ok', triggeredBy: 'chat', input: const {'topic': 'llm agents'}, output: 'a summary…', provider: 'anthropic', modelId: 'claude-opus-4-8', elapsedMs: 5200, createdAt: t1),
      ],
    },
    flowruns: {
      'wf_digest': [
        Flowrun(id: 'flr_1', workflowId: 'wf_digest', versionId: 'wf_digest_v1', status: 'completed', replayCount: 0, startedAt: t1, completedAt: t1, updatedAt: t1),
        Flowrun(id: 'flr_2', workflowId: 'wf_digest', versionId: 'wf_digest_v1', status: 'running', replayCount: 0, startedAt: t1, updatedAt: t1),
      ],
    },
    flowrunDetail: {
      'flr_1': FlowrunComposite(
        flowrun: Flowrun(id: 'flr_1', workflowId: 'wf_digest', versionId: 'wf_digest_v1', status: 'completed', replayCount: 0, startedAt: t1, completedAt: t1, updatedAt: t1),
        nodes: [
          FlowrunNode(id: 'frn_1', flowrunId: 'flr_1', nodeId: 'n1', kind: 'trigger', ref: 'tr_cron', status: 'completed', createdAt: t1, completedAt: t1, updatedAt: t1),
          FlowrunNode(id: 'frn_2', flowrunId: 'flr_1', nodeId: 'n2', kind: 'agent', ref: 'ag_researcher', status: 'completed', createdAt: t1, completedAt: t1, updatedAt: t1),
          FlowrunNode(id: 'frn_3', flowrunId: 'flr_1', nodeId: 'n3', kind: 'action', ref: 'fn_summarize', status: 'completed', createdAt: t1, completedAt: t1, updatedAt: t1),
        ],
      ),
    },
    mountHealth: {
      'ag_researcher': const MountHealthReport(
        mounts: [
          MountHealth(ref: 'fn_normalize', name: 'normalize', healthy: true),
          MountHealth(ref: 'hd_slack.post', name: 'post-slack', healthy: true),
          MountHealth(ref: 'mcp:search/web', name: 'web-search', healthy: false, error: 'server offline'),
        ],
        allHealthy: false,
      ),
    },
  );
}
