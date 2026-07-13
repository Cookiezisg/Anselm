import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/trigger.dart';
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
  // Node timestamps for the cockpit run (a retry loop with visible durations). 驾驶舱 run 的节点时刻(带可见时长的重试循环)。
  DateTime rt(int sec) => DateTime.utc(2026, 6, 27, 12, 9, sec);

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
  // wf_release: a deploy pipeline gated by a HUMAN approval node (ap_publish) — its live run PARKS at
  // the gate, so the entities inbox + a parked flowrunDetail have something to show (D-026). 人闸发布线:停车。
  const graphRelease =
      '{"nodes":[{"id":"on_push","kind":"trigger","ref":"trg_wh1"},{"id":"build","kind":"action","ref":"fn_validate"},{"id":"approve_deploy","kind":"approval","ref":"ap_publish"},{"id":"deploy","kind":"action","ref":"hd_slack.post"}],"edges":[{"id":"e1","from":"on_push","to":"build"},{"id":"e2","from":"build","to":"approve_deploy"},{"id":"e3","from":"approve_deploy","to":"deploy"}]}';

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
      wf('wf_release', 'deploy-release', 'Build → human approval → deploy', 'active', active: true)
          .copyWith(activeVersion: wfVer('wf_release', 1, graphRelease, 'initial deploy pipeline')),
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
    // D-027 — handler/agent version-history tabs need a real trail (the active version alone leaves the
    // tab empty). Two handler revs + three agent revs, newest first. 版本历史 tab:多版本轨迹。
    handlerVersions: {
      'hd_slack': [
        HandlerVersion(id: 'hd_slack_v1', handlerId: 'hd_slack', version: 1, imports: 'import httpx', initBody: 'self.client = httpx.Client()', methods: const [MethodSpec(name: 'post', inputs: [Field(name: 'channel', type: 'string')], outputs: [Field(name: 'ts', type: 'string')], body: 'return self.client.post(...)')], envStatus: 'ready', changeReason: 'retry loop + region arg', createdAt: t1, updatedAt: t1),
        HandlerVersion(id: 'hd_slack_v0', handlerId: 'hd_slack', version: 0, imports: 'import requests', initBody: 'self.session = requests.Session()', envStatus: 'ready', changeReason: 'initial', createdAt: t0, updatedAt: t0),
      ],
    },
    agentVersions: {
      'ag_researcher': [
        AgentVersion(id: 'ag_researcher_v3', agentId: 'ag_researcher', version: 3, prompt: 'You are researcher. Be precise and cite sources.', skill: 'deep-research', tools: const [ToolRef(ref: 'mcp:search/web', name: 'web-search')], changeReason: 'add web-search tool', createdAt: t1, updatedAt: t1),
        AgentVersion(id: 'ag_researcher_v2', agentId: 'ag_researcher', version: 2, prompt: 'You are researcher. Cite sources.', skill: 'deep-research', changeReason: 'tighten prompt', createdAt: t1, updatedAt: t1),
        AgentVersion(id: 'ag_researcher_v1', agentId: 'ag_researcher', version: 1, prompt: 'Summarize the topic.', changeReason: 'initial', createdAt: t0, updatedAt: t0),
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
    // wf_digest run history — node ids match the v2 graph (on_schedule/research/summarize/
    // quality_gate/post_slack). flr_done shows a retry loop (research ×2); flr_fail a failed
    // summarize (→ :replay); flr_run an in-flight run (running synthesis lights summarize).
    // 运行历史,节点 id 对齐 v2 图。flr_done 重试循环;flr_fail 失败(可重跑);flr_run 在途。
    flowruns: {
      'wf_digest': [
        Flowrun(id: 'flr_run', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'running', replayCount: 0, triggerId: 'trg_3a1f', startedAt: rt(0), updatedAt: rt(2)),
        Flowrun(id: 'flr_done', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'completed', replayCount: 0, triggerId: 'trg_3a1f', startedAt: t1, completedAt: t1.add(const Duration(seconds: 9)), updatedAt: t1),
        Flowrun(id: 'flr_fail', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'failed', replayCount: 0, triggerId: 'trg_3a1f', error: 'run_tests exit code 1', startedAt: t0, completedAt: t0.add(const Duration(seconds: 4)), updatedAt: t0),
      ],
      // D-026 — a run PARKED at its human-approval gate (feeds the entities flowrun inbox + the parked
      // detail below). 停在人闸的运行。
      'wf_release': [
        Flowrun(id: 'flr_park', workflowId: 'wf_release', versionId: 'wf_release_v1', status: 'running', replayCount: 0, triggerId: 'trg_wh1', startedAt: t1, updatedAt: t1),
      ],
    },
    flowrunDetail: {
      'flr_run': FlowrunComposite(
        flowrun: Flowrun(id: 'flr_run', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'running', replayCount: 0, triggerId: 'trg_3a1f', startedAt: rt(0), updatedAt: rt(2)),
        nodes: [
          FlowrunNode(id: 'r1', flowrunId: 'flr_run', nodeId: 'on_schedule', kind: 'trigger', ref: 'tr_cron', status: 'completed', createdAt: rt(0), completedAt: rt(0), updatedAt: rt(0)),
          FlowrunNode(id: 'r2', flowrunId: 'flr_run', nodeId: 'research', kind: 'agent', ref: 'ag_researcher', status: 'completed', createdAt: rt(0), completedAt: rt(2), updatedAt: rt(2)),
        ],
      ),
      'flr_done': FlowrunComposite(
        flowrun: Flowrun(id: 'flr_done', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'completed', replayCount: 0, triggerId: 'trg_3a1f', startedAt: t1, completedAt: t1.add(const Duration(seconds: 9)), updatedAt: t1),
        nodes: [
          FlowrunNode(id: 'd0', flowrunId: 'flr_done', nodeId: 'on_schedule', kind: 'trigger', ref: 'tr_cron', status: 'completed', createdAt: t1, completedAt: t1, updatedAt: t1),
          FlowrunNode(id: 'd1', flowrunId: 'flr_done', nodeId: 'research', kind: 'agent', ref: 'ag_researcher', iteration: 0, status: 'completed', result: const {'summary': 'draft 1'}, createdAt: t1, completedAt: t1.add(const Duration(seconds: 2)), updatedAt: t1),
          FlowrunNode(id: 'd2', flowrunId: 'flr_done', nodeId: 'summarize', kind: 'action', ref: 'fn_summarize', iteration: 0, status: 'completed', createdAt: t1.add(const Duration(seconds: 2)), completedAt: t1.add(const Duration(seconds: 3)), updatedAt: t1),
          FlowrunNode(id: 'd3', flowrunId: 'flr_done', nodeId: 'quality_gate', kind: 'control', ref: 'ctl_quality', iteration: 0, status: 'completed', result: const {'__port': 'retry', 'score': 0.4}, createdAt: t1.add(const Duration(seconds: 3)), completedAt: t1.add(const Duration(seconds: 3)), updatedAt: t1),
          FlowrunNode(id: 'd4', flowrunId: 'flr_done', nodeId: 'research', kind: 'agent', ref: 'ag_researcher', iteration: 1, status: 'completed', result: const {'summary': 'draft 2'}, createdAt: t1.add(const Duration(seconds: 3)), completedAt: t1.add(const Duration(seconds: 6)), updatedAt: t1),
          FlowrunNode(id: 'd5', flowrunId: 'flr_done', nodeId: 'summarize', kind: 'action', ref: 'fn_summarize', iteration: 1, status: 'completed', createdAt: t1.add(const Duration(seconds: 6)), completedAt: t1.add(const Duration(seconds: 7)), updatedAt: t1),
          FlowrunNode(id: 'd6', flowrunId: 'flr_done', nodeId: 'quality_gate', kind: 'control', ref: 'ctl_quality', iteration: 1, status: 'completed', result: const {'__port': 'pass', 'score': 0.9}, createdAt: t1.add(const Duration(seconds: 7)), completedAt: t1.add(const Duration(seconds: 7)), updatedAt: t1),
          FlowrunNode(id: 'd7', flowrunId: 'flr_done', nodeId: 'post_slack', kind: 'action', ref: 'hd_slack.post', iteration: 1, status: 'completed', result: const {'ts': '1719487747.12'}, createdAt: t1.add(const Duration(seconds: 7)), completedAt: t1.add(const Duration(seconds: 9)), updatedAt: t1),
        ],
      ),
      'flr_fail': FlowrunComposite(
        flowrun: Flowrun(id: 'flr_fail', workflowId: 'wf_digest', versionId: 'wf_digest_v2', status: 'failed', replayCount: 0, triggerId: 'trg_3a1f', error: 'run_tests exit code 1', startedAt: t0, completedAt: t0.add(const Duration(seconds: 4)), updatedAt: t0),
        nodes: [
          FlowrunNode(id: 'f0', flowrunId: 'flr_fail', nodeId: 'on_schedule', kind: 'trigger', ref: 'tr_cron', status: 'completed', createdAt: t0, completedAt: t0, updatedAt: t0),
          FlowrunNode(id: 'f1', flowrunId: 'flr_fail', nodeId: 'research', kind: 'agent', ref: 'ag_researcher', status: 'completed', createdAt: t0, completedAt: t0.add(const Duration(seconds: 2)), updatedAt: t0),
          FlowrunNode(id: 'f2', flowrunId: 'flr_fail', nodeId: 'summarize', kind: 'action', ref: 'fn_summarize', status: 'failed', error: 'ValueError: empty document', createdAt: t0.add(const Duration(seconds: 2)), completedAt: t0.add(const Duration(seconds: 4)), updatedAt: t0),
        ],
      ),
      // D-026 — parked at approve_deploy: build done, gate awaiting a human :decide. 停在 approve_deploy 人闸。
      'flr_park': FlowrunComposite(
        flowrun: Flowrun(id: 'flr_park', workflowId: 'wf_release', versionId: 'wf_release_v1', status: 'running', replayCount: 0, triggerId: 'trg_wh1', startedAt: t1, updatedAt: t1),
        nodes: [
          FlowrunNode(id: 'p0', flowrunId: 'flr_park', nodeId: 'on_push', kind: 'trigger', ref: 'trg_wh1', status: 'completed', createdAt: t1, completedAt: t1, updatedAt: t1),
          FlowrunNode(id: 'p1', flowrunId: 'flr_park', nodeId: 'build', kind: 'action', ref: 'fn_validate', status: 'completed', result: const {'ok': true}, createdAt: t1, completedAt: t1.add(const Duration(seconds: 3)), updatedAt: t1),
          FlowrunNode(id: 'p2', flowrunId: 'flr_park', nodeId: 'approve_deploy', kind: 'approval', ref: 'ap_publish', status: 'parked', result: const {'rendered': 'Deploy **v2.4.0** to production? 42 files changed.'}, createdAt: t1.add(const Duration(seconds: 3)), updatedAt: t1.add(const Duration(seconds: 3))),
        ],
      ),
    },
    // D-025 — the ctl_quality control the wf_digest graph routes on (pass≥0.7 / retry catch-all). rail control 段。
    controlLogics: [
      ControlLogic(
        id: 'ctl_quality', name: 'quality-gate', description: 'Route on the summary quality score.',
        activeVersionId: 'ctl_quality_v1', createdAt: t0, updatedAt: t1,
        activeVersion: ControlVersion(
          id: 'ctl_quality_v1', controlId: 'ctl_quality', version: 1,
          inputs: const [Field(name: 'score', type: 'number', description: 'Reviewer score 0–1.')],
          branches: const [
            Branch(port: 'pass', when: 'input.score >= 0.7'),
            Branch(port: 'retry', when: 'true'),
          ],
          changeReason: 'initial gate', createdAt: t0, updatedAt: t1,
        ),
      ),
    ],
    // D-024 — the ap_publish approval the wf_release graph parks on (markdown template + decision rules). rail approval 段。
    approvalForms: [
      ApprovalForm(
        id: 'ap_publish', name: 'publish-approval', description: 'Human sign-off before a production deploy.',
        activeVersionId: 'ap_publish_v1', createdAt: t0, updatedAt: t1,
        activeVersion: ApprovalVersion(
          id: 'ap_publish_v1', approvalId: 'ap_publish', version: 1,
          inputs: const [Field(name: 'version', type: 'string'), Field(name: 'fileCount', type: 'number')],
          template: 'Deploy **{{ input.version }}** to production?\n\n{{ input.fileCount }} files changed.',
          allowReason: true, timeout: '24h', timeoutBehavior: 'reject',
          changeReason: 'initial form', createdAt: t0, updatedAt: t1,
        ),
      ),
    ],
    // D-028 — the graph editor's ref picker needs MCP server/tool candidates (control/approval candidates
    // derive from the logics/forms above). 图编辑器 ref picker 的 mcp 候选。
    mcpServers: const [
      (id: 'context7', name: 'context7', meta: 'ready'),
      (id: 'filesystem', name: 'filesystem', meta: 'ready'),
    ],
    mcpTools: const {
      'context7': [
        (id: 'resolve-library-id', name: 'resolve-library-id', meta: 'context7'),
        (id: 'get-library-docs', name: 'get-library-docs', meta: 'context7'),
      ],
      'filesystem': [
        (id: 'read_file', name: 'read_file', meta: 'filesystem'),
        (id: 'write_file', name: 'write_file', meta: 'filesystem'),
      ],
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
    // The 4 sealed source kinds, each an unversioned config entity (cron drives wf_digest). trg 现 4 源。
    triggerEntities: [
      TriggerEntity(
        id: 'trg_3a1f', name: 'nightly-digest', description: 'Kick the daily digest at 09:00.',
        kind: TriggerSource.cron, config: const {'expression': '0 9 * * *'},
        outputs: const [Field(name: 'firedAt', type: 'string', description: 'When the trigger fired (RFC3339).')],
        refCount: 1, listening: true, lastFiredAt: t1, nextFireAt: t1.add(const Duration(hours: 18, minutes: 30)),
        createdAt: t0, updatedAt: t1),
      TriggerEntity(
        id: 'trg_wh1', name: 'github-push', description: 'Fire when GitHub pushes to main.',
        kind: TriggerSource.webhook,
        config: const {'path': 'gh/push', 'signatureAlgo': 'hmac-sha256-hex', 'signatureHeader': 'X-Hub-Signature-256'},
        outputs: const [Field(name: 'body', type: 'object', description: 'Posted body parsed as JSON.')],
        refCount: 2, listening: true, lastFiredAt: t1, createdAt: t0, updatedAt: t1),
      TriggerEntity(
        id: 'trg_fs1', name: 'watch-inbox', description: 'React to files dropped in the inbox.',
        kind: TriggerSource.fsnotify,
        config: const {'path': '/data/inbox', 'events': ['create', 'modify'], 'pattern': '*.csv'},
        refCount: 0, listening: false, createdAt: t0, updatedAt: t0),
      TriggerEntity(
        id: 'trg_sn1', name: 'queue-depth', description: 'Fire when the job queue backs up.',
        kind: TriggerSource.sensor,
        config: const {'targetKind': 'handler', 'targetId': 'hd_queue', 'method': 'depth', 'intervalSec': 30, 'condition': 'output.depth > 100'},
        outputs: const [Field(name: 'depth', type: 'number')],
        refCount: 1, listening: true, lastFiredAt: t0, createdAt: t0, updatedAt: t1),
    ],
    activations: {
      'trg_3a1f': [
        Activation(id: 'tra_9', triggerId: 'trg_3a1f', kind: TriggerSource.cron, fired: true, firingCount: 1, payload: const {'firedAt': '2026-06-25T09:00:00Z'}, createdAt: t1),
        Activation(id: 'tra_8', triggerId: 'trg_3a1f', kind: TriggerSource.cron, fired: true, firingCount: 1, createdAt: t0.add(const Duration(days: 1))),
      ],
      'trg_sn1': [
        Activation(id: 'tra_7', triggerId: 'trg_sn1', kind: TriggerSource.sensor, fired: true, firingCount: 1, returnValue: const {'depth': 142}, detail: 'condition held', createdAt: t1),
        Activation(id: 'tra_6', triggerId: 'trg_sn1', kind: TriggerSource.sensor, fired: false, returnValue: const {'depth': 12}, detail: 'condition evaluated false', createdAt: t0),
      ],
    },
    firings: {
      'trg_3a1f': [
        Firing(id: 'trf_3', triggerId: 'trg_3a1f', workflowId: 'wf_digest', activationId: 'tra_9', status: FiringStatus.started, flowrunId: 'flr_done', dedupKey: 'k9', createdAt: t1, updatedAt: t1),
        Firing(id: 'trf_2', triggerId: 'trg_3a1f', workflowId: 'wf_digest', activationId: 'tra_8', status: FiringStatus.skipped, dedupKey: 'k8', createdAt: t0.add(const Duration(days: 1)), updatedAt: t0.add(const Duration(days: 1))),
      ],
    },
  );
}
