import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/workflow.dart';
import 'entity_fixtures.dart';

/// A realistic zero-backend seed for the interactive preview (`make entities`) and the wider demo —
/// a handful of each kind with varied badges so the rail's status dots, counts, and sections all show.
/// STEP 4/5 extend this with versions / logs / flowruns. NOT used by the live app (which wires
/// LiveEntityRepository); a single seam swap drives the whole feature off this instead.
///
/// 交互预览(`make entities`)与 demo 的真实零后端种子——每 kind 数个 + 多样徽标,使 rail 状态点/计数/分组
/// 全现。STEP 4/5 续加版本/日志/flowrun。非 live app 用(后者接 Live);单点缝切换即用此驱动整 feature。
FixtureEntityRepository demoEntityRepository() {
  final t = DateTime.utc(2026, 6, 25, 14, 30);
  return FixtureEntityRepository(
    functions: [
      FunctionEntity(id: 'fn_normalize', name: 'normalize-input', description: 'Coerce + trim raw fields', tags: const ['util'], createdAt: t, updatedAt: t),
      FunctionEntity(id: 'fn_validate', name: 'validate-schema', description: 'JSON-schema validate a payload', createdAt: t, updatedAt: t),
      FunctionEntity(id: 'fn_weather', name: 'fetch-weather', description: 'Call the weather API', tags: const ['io'], createdAt: t, updatedAt: t),
      FunctionEntity(id: 'fn_summarize', name: 'summarize-text', description: 'LLM summarize a document', createdAt: t, updatedAt: t),
    ],
    handlers: [
      HandlerEntity(id: 'hd_slack', name: 'slack', description: 'Slack workspace client', createdAt: t, updatedAt: t, runtimeState: 'running', configState: 'ready'),
      HandlerEntity(id: 'hd_postgres', name: 'postgres', description: 'Primary database', createdAt: t, updatedAt: t, runtimeState: 'running', configState: 'ready'),
      HandlerEntity(id: 'hd_stripe', name: 'stripe', description: 'Payments', createdAt: t, updatedAt: t, runtimeState: 'crashed', configState: 'ready'),
      HandlerEntity(id: 'hd_twilio', name: 'twilio', description: 'SMS — not configured yet', createdAt: t, updatedAt: t, runtimeState: 'stopped', configState: 'partially_configured', missingConfig: const ['authToken']),
    ],
    agents: [
      AgentEntity(id: 'ag_researcher', name: 'researcher', description: 'Deep-research agent', tags: const ['llm'], createdAt: t, updatedAt: t),
      AgentEntity(id: 'ag_triager', name: 'triager', description: 'Routes inbound issues', createdAt: t, updatedAt: t),
    ],
    workflows: [
      WorkflowEntity(id: 'wf_digest', name: 'daily-digest', description: 'Summarize + post each morning', createdAt: t, updatedAt: t, active: true, lifecycleState: 'active', concurrency: 'skip'),
      WorkflowEntity(id: 'wf_invoice', name: 'invoice-sync', description: 'Sync invoices to the ledger', createdAt: t, updatedAt: t, lifecycleState: 'active', active: true, needsAttention: true, attentionReason: 'last run failed'),
      WorkflowEntity(id: 'wf_onboard', name: 'onboarding', description: 'New-user onboarding steps', createdAt: t, updatedAt: t, lifecycleState: 'inactive'),
    ],
  );
}
