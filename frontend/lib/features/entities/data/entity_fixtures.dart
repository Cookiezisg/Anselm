import '../../../core/ui/ui.dart';
import '../model/entity.dart';

/// Dev fixtures — a representative entity per kind across all four rail groups, with
/// schema-matching detail data. Lets the Entities UI be built/iterated with zero backend
/// (the repository provider is overridden to [FixtureEntitiesRepository]); real data wires
/// in later behind the same interface.
/// 开发 fixture——四组各 kind 一个代表实体 + 匹配 schema 的详情。零后端即可搭/迭代 Entities UI。
const List<EntityDetail> fixtureEntities = [
  // ── 逻辑节点 ──
  EntityDetail(
    summary: EntitySummary(id: 'fn_01', kind: EntityKind.function, name: 'greet_user', meta: 'v3 · ready', status: AnStatus.done),
    data: {
      'description': 'Build a friendly greeting for a user.',
      'meta': {'Active version': 'v3', 'Environment': 'ready', 'Updated': '2 minutes ago'},
      'code': 'def greet(name: str) -> dict:\n'
          '    # build a friendly greeting\n'
          '    msg = f"Hello, {name}!"\n'
          '    return {"message": msg, "len": len(msg)}',
      'inputs': {'name': 'str (required)'},
      'outputs': {'message': 'str', 'len': 'int'},
      'dependencies': [RowItem('python 3.12'), RowItem('(no third-party deps)')],
      'env': {'state': 'ready', 'built': '2 minutes ago'},
      'runs': [
        RowItem('run_8f2 · ok', meta: '0.4s', status: AnStatus.done),
        RowItem('run_7a1 · ok', meta: '0.3s', status: AnStatus.done),
      ],
    },
  ),
  EntityDetail(
    summary: EntitySummary(id: 'hd_01', kind: EntityKind.handler, name: 'Webhook handler', meta: 'failed', status: AnStatus.err),
    data: {
      'description': 'Resident class that ingests inbound webhooks.',
      'meta': {'Active version': 'v2', 'Process': 'crashed', 'Updated': '1 hour ago'},
      'runtime': {'state': 'crashed', 'pid': '—', 'restarts': '3'},
      'configState': {'init config': 'incomplete'},
      'methods': [RowItem('ingest(payload)'), RowItem('verify(sig)')],
      'code': 'class WebhookHandler:\n    def ingest(self, payload): ...',
      'calls': [RowItem('call_3d · error', meta: 'signature', status: AnStatus.err)],
    },
  ),
  EntityDetail(
    summary: EntitySummary(id: 'ag_01', kind: EntityKind.agent, name: 'Research agent', meta: 'running', status: AnStatus.run),
    data: {
      'description': 'An LLM worker that researches a topic and drafts a brief.',
      'meta': {'Active version': 'v5', 'Model': 'claude-opus-4-8', 'Updated': '5 minutes ago'},
      'prompt': '# Role\nYou are a meticulous research assistant.\n\n## Task\nResearch the topic and produce a cited brief.',
      'tools': [RowItem('web_search', meta: 'function'), RowItem('greet_user', meta: 'function')],
      'knowledge': [RowItem('Style guide', meta: 'document')],
      'mountHealth': [RowItem('web_search', meta: 'ok', status: AnStatus.done), RowItem('greet_user', meta: 'ok', status: AnStatus.done)],
      'executions': [RowItem('inv_19 · ok', meta: '12s', status: AnStatus.done)],
    },
  ),
  EntityDetail(
    summary: EntitySummary(id: 'trg_01', kind: EntityKind.trigger, name: 'Nightly cron', meta: 'listening', status: AnStatus.run),
    data: {
      'description': 'Fires the nightly digest workflow at 02:00.',
      'meta': {'Source': 'cron', 'Schedule': '0 2 * * *', 'Updated': 'yesterday'},
      'sourceMeta': {'kind': 'cron', 'timezone': 'Asia/Shanghai'},
      'config': {'cron': '0 2 * * *', 'overlap': 'skip'},
      'activations': [RowItem('act_44 · fired', meta: '02:00', status: AnStatus.done)],
      'firings': [RowItem('fire_44 · consumed', meta: 'run_91', status: AnStatus.done)],
    },
  ),
  // ── 控制节点 ──
  EntityDetail(
    summary: EntitySummary(id: 'ctl_01', kind: EntityKind.control, name: 'Route by priority', meta: 'control', status: AnStatus.idle),
    data: {
      'description': 'First-true-wins routing over the incoming payload.',
      'meta': {'Branches': '3', 'Updated': '3 days ago'},
      'inputs': {'priority': 'string', 'score': 'number'},
      'branches': [RowItem('high', meta: 'priority == "high"'), RowItem('mid', meta: 'score > 0.5'), RowItem('else', meta: 'when=true')],
      'when': 'priority == "high"',
      'emit': {'lane': 'fast', 'notify': true},
    },
  ),
  EntityDetail(
    summary: EntitySummary(id: 'apf_01', kind: EntityKind.approval, name: 'Manager sign-off', meta: 'waiting', status: AnStatus.wait),
    data: {
      'description': 'Human gate before publishing the digest.',
      'meta': {'Timeout': '24h', 'On timeout': 'reject', 'Updated': '3 days ago'},
      'template': '## Approve nightly digest?\nReview the draft below and approve or reject.',
      'inputs': {'draft': 'string'},
      'decision': {'timeout': '24h', 'default': 'reject'},
      'ports': [RowItem('approve'), RowItem('reject')],
    },
  ),
  // ── 工作流 ──
  EntityDetail(
    summary: EntitySummary(id: 'wf_01', kind: EntityKind.workflow, name: 'Nightly digest', meta: 'active', status: AnStatus.done),
    data: {
      'description': 'Fetch → summarize → approve → publish, nightly.',
      'meta': {'Active version': 'v8', 'State': 'active', 'Updated': '1 day ago'},
      'lifecycle': {'state': 'active', 'last run': 'ok · 02:01'},
      'concurrency': {'overlap': 'skip', 'max': '1'},
      'flowruns': [
        RowItem('run_91 · completed', meta: '4m', status: AnStatus.done),
        RowItem('run_90 · completed', meta: '4m', status: AnStatus.done),
      ],
    },
  ),
  // ── 外部组件 ──
  EntityDetail(
    summary: EntitySummary(id: 'mcp_github', kind: EntityKind.mcp, name: 'github', meta: 'connected', status: AnStatus.done),
    data: {
      'description': 'GitHub MCP server — issues, PRs, repos.',
      'meta': {'Tools': '14', 'Updated': '6 hours ago'},
      'connection': {'status': 'connected', 'last error': '—'},
      'transport': {'kind': 'stdio', 'command': 'npx @modelcontextprotocol/server-github'},
      'tools': [RowItem('create_issue'), RowItem('list_prs'), RowItem('get_repo')],
      'calls': [RowItem('list_prs · ok', meta: '0.8s', status: AnStatus.done)],
    },
  ),
  EntityDetail(
    summary: EntitySummary(id: 'skill_review', kind: EntityKind.skill, name: 'code-review', meta: 'skill', status: AnStatus.idle),
    data: {
      'description': 'Instructions for a thorough code review pass.',
      'meta': {'allowed-tools': '2', 'Updated': '1 week ago'},
      'frontmatter': {'name': 'code-review', 'allowed-tools': ['read_file', 'search_blocks']},
      'body': '# Code review\nReview the diff for correctness, then for simplicity.',
      'allowedTools': [RowItem('read_file'), RowItem('search_blocks')],
    },
  ),
];
