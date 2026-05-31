export const meta = {
  name: 'gen-r3-coverage',
  description: 'Stage-1 of per-tool coverage: for EACH of 91 tools, author ≥50 DISTINCT scenarios that should cause that tool to be called. Agents write /tmp/r3scen/<tool>.json + return counts.',
  phases: [{ title: 'Generate', detail: '91 tools × ≥50 distinct scenarios' }],
}

// 91 tools grouped by family, each with a per-family authoring hint.
const FAMILIES = {
  function: { hint: 'pure-logic function forge/usage', tools: ['create_function', 'edit_function', 'get_function', 'get_function_versions', 'revert_function', 'accept_pending_function', 'run_function', 'search_functions', 'search_function_executions', 'get_function_execution', 'delete_function'] },
  handler: { hint: 'stateful handler forge/usage', tools: ['create_handler', 'edit_handler', 'get_handler', 'get_handler_versions', 'revert_handler', 'accept_pending_handler', 'call_handler', 'update_handler_config', 'search_handlers', 'search_handler_calls', 'get_handler_call', 'delete_handler'] },
  agent: { hint: 'agent (LLM worker) forge/usage', tools: ['create_agent', 'edit_agent', 'get_agent', 'get_agent_versions', 'revert_agent', 'accept_pending_agent', 'run_agent', 'search_agents', 'search_agent_executions', 'get_agent_execution', 'delete_agent'] },
  workflow: { hint: 'workflow graph forge/usage', tools: ['create_workflow', 'edit_workflow', 'get_workflow', 'get_workflow_versions', 'revert_workflow', 'accept_pending_workflow', 'search_workflows', 'delete_workflow', 'capability_check_workflow'] },
  lifecycle: { hint: 'workflow lifecycle', tools: ['activate_workflow', 'deactivate_workflow', 'trigger_workflow'] },
  runtime: { hint: 'flowrun inspection', tools: ['get_flowrun', 'get_flowrun_nodes', 'get_flowrun_trace', 'search_flowruns', 'cancel_flowrun'] },
  diagnosis: { hint: 'dead-letter / event diagnosis', tools: ['list_dead_letters', 'get_dead_letter', 'clear_dead_letters', 'replay_message', 'query_events'] },
  mcp: { hint: 'MCP server/tool', tools: ['list_mcp_servers', 'search_mcp_tools', 'call_mcp_tool', 'health_check_mcp', 'install_mcp_from_registry'] },
  skill: { hint: 'skill', tools: ['search_skills', 'get_skill', 'activate_skill'] },
  document: { hint: 'document/knowledge', tools: ['create_document', 'edit_document', 'read_document', 'list_documents', 'search_documents', 'move_document', 'delete_document'] },
  memory: { hint: 'memory', tools: ['write_memory', 'read_memory', 'forget_memory'] },
  base: { hint: 'base/utility (filesystem/shell/web/todo/subagent/meta)', tools: ['Read', 'Write', 'Edit', 'Glob', 'Grep', 'Bash', 'BashOutput', 'KillShell', 'WebFetch', 'WebSearch', 'Subagent', 'AskUserQuestion', 'TodoCreate', 'TodoGet', 'TodoList', 'TodoUpdate', 'activate_tools'] },
}
const DIR = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'

const RESULT = { type: 'object', required: ['tool', 'count'], additionalProperties: false,
  properties: { tool: { type: 'string' }, count: { type: 'integer' }, path: { type: 'string' }, note: { type: 'string' } } }

const prompt = (tool, fam, hint) => `Author a COVERAGE test-set for the LLM-facing tool \`${tool}\` (${fam} family: ${hint}).
1. Get its exact schema: \`cd ${DIR} && python3 -c "import spec_catalog as sc, json; print(json.dumps(sc.BY_NAME['${tool}']))"\`. Read description + parameters.
2. Author **≥50 DISTINCT scenarios** — each a realistic situation where a user's request should cause THIS tool (\`${tool}\`) to be the correct call. MAXIMIZE diversity: vary domain (电商/客服/运维/金融/内容/IoT/HR/物流/医疗/教育/SaaS/数据/社交/游戏…), entities, phrasing, complexity, and surrounding context. NO two scenarios should be near-duplicates. For forge tools include enough detail to actually build; for usage/read tools (get/search/list/read/version/lifecycle/diagnosis) embed a plausible existing-entity id or query and the surrounding intent.
3. Each scenario = {"id":"${tool}_<n>", "user":"<one-paragraph Chinese request>", "intent":"<English: the exactly-correct ${tool} call + args>", "rubric":["3-6 concrete English checks: calls ${tool}, correct/non-hallucinated id-or-args, right behavior; for forge: the artifact correctness checks"]}.
4. Write the JSON array to \`/tmp/r3scen/${tool}.json\` (mkdir -p /tmp/r3scen first) via the Write tool — a top-level JSON array of the scenario objects. Verify it parses (\`python3 -c "import json;print(len(json.load(open('/tmp/r3scen/${tool}.json'))))"\`).
Return {tool, count (how many you wrote, ≥50), path}. Quality + diversity matter — this is real coverage, do NOT pad with near-duplicates.`

phase('Generate')
const jobs = []
for (const [fam, { hint, tools }] of Object.entries(FAMILIES))
  for (const tool of tools) jobs.push({ tool, fam, hint })
const results = await parallel(jobs.map((j) => () =>
  agent(prompt(j.tool, j.fam, j.hint), { label: `gen:${j.tool}`, phase: 'Generate', schema: RESULT, agentType: 'general-purpose' })
    .then((r) => r || { tool: j.tool, count: 0 }).catch((e) => ({ tool: j.tool, count: 0, note: String(e).slice(0, 80) }))))
const ok = results.filter(Boolean)
const total = ok.reduce((s, r) => s + (r.count || 0), 0)
const under = ok.filter((r) => (r.count || 0) < 50).map((r) => `${r.tool}:${r.count}`)
log(`Generated ${total} scenarios across ${ok.length} tools. Under-50: ${under.length ? under.join(', ') : 'NONE — all ≥50 ✓'}`)
return { total, tools: ok.length, under, perTool: ok.map((r) => [r.tool, r.count]) }
