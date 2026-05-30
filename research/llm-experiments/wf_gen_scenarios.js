export const meta = {
  name: 'gen-diverse-scenarios',
  description: 'Stage-1 of true n=200 COVERAGE: Claude authors ~200 DISTINCT scenarios per surface across a domain×complexity grid (not reps of one prompt). Each scenario = {id,user,intent,rubric}.',
  phases: [{ title: 'Generate', detail: 'domain×complexity grid authors → dedup → write /tmp/r3scen' }],
}

// Surfaces to cover; each gets ~200 distinct situations authored across the grid.
const SURFACES = [
  { key: 'create_workflow', n: 200,
    spec: 'A workflow automation request: the user describes an end-to-end automation. Author a realistic ONE-paragraph user request (Chinese), the intent (what graph it should produce: nodes/edges/case-branches/retry/approval), and a rubric (4-6 concrete checks: right node types & order, case via per-branch when guards, no dangling, retry bounded+emit if present, terminal omits to, data flows / first node after cron fetches).' },
  { key: 'create_agent', n: 200,
    spec: 'An agent (configured LLM worker) request. Author a realistic user request to build an agent (classifier/extractor/summarizer/router/scorer/responder/translator/...), the intent (prompt + outputSchema kind enum|json_schema|free_text + which fn/hd/mcp tools if any + knowledge/skill), and a rubric (4-6 checks: agent not function, tools only fn/hd/mcp never platform/agent, prompt references {{payload}}, sensible outputSchema, no impossible-capability prompt).' },
  { key: 'cel_when', n: 200,
    spec: 'A case-node routing request expressed as per-branch when-guards. Author a realistic routing need (Chinese), the intent (the boolean CEL each branch should encode + a final when:"true" default), and a rubric (4-6 checks: each branch a boolean when-guard, correct logic, final default, no key-match, list-membership/threshold/null handling as needed). Vary: thresholds, multi-field AND/OR, time-windows, list-membership, nested fields, N-way ordered.' },
  { key: 'create_function', n: 200,
    spec: 'A pure-logic function request (deterministic, no LLM). Author a realistic request (parsing/calc/transform/validation/formatting/dedup/date-math/...), the intent (signature + behavior), a rubric (4-6 checks: correct logic, edge cases, bare-named params, valid Python), and a code_test object {inputs:[...], expected_behavior:"..."} the harness can exercise.' },
  { key: 'create_handler', n: 200,
    spec: 'A STATEFUL handler request (a Python class holding state across calls). Author a realistic request (rate limiter/cache/pool/session/counter/buffer/dedup-window/circuit-breaker/...), the intent (class + methods + state), a rubric (4-6 checks incl. correct stateful logic, bare-named params, caps/limits honored), and a code_test object {scenario:"...", expected_behavior:"..."} describing how to exercise the state.' },
]

// Diversity grid: each generator agent owns a distinct (domain-set, complexity, slice) cell.
const DOMAINS = [
  ['电商/订单', '客服/工单'], ['运维/告警', 'IoT/设备'], ['金融/对账', '风控/合规'],
  ['内容/媒体审核', '营销/增长'], ['HR/入职', '物流/配送'], ['医疗/预约', '教育/课程'],
  ['SaaS/计费', '数据/ETL'], ['社交/通知', '游戏/活动'],
]
const SCHEMA = {
  type: 'object', required: ['scenarios'], additionalProperties: false,
  properties: { scenarios: { type: 'array', items: {
    type: 'object', required: ['id', 'user', 'intent', 'rubric'], additionalProperties: false,
    properties: { id: { type: 'string' }, user: { type: 'string' }, intent: { type: 'string' },
      rubric: { type: 'array', items: { type: 'string' } },
      code_test: { type: 'object', additionalProperties: true } } } } },
}

const genPrompt = (surf, cell, per, salt) => `You are authoring DISTINCT test scenarios for an LLM-facing forge tool: ${surf.key}.
${surf.spec}
Author EXACTLY ${per} scenarios, ALL DIFFERENT from each other, set in these domains: ${cell.join(', ')}.
Spread across complexity levels (simple → multi-step/edge-case). Make each user request concrete and realistic (a real person would type it). Vary the specifics (entities, fields, thresholds, formats) — diversity slice #${salt}, do not repeat stock examples.
id = "${surf.key.slice(0, 2)}_${salt}_<n>". Return per schema: scenarios[] {id, user (Chinese, one paragraph), intent (English, what correct output is), rubric (3-6 concrete English checks)${surf.key.startsWith('create_f') || surf.key.startsWith('create_h') ? ', code_test {inputs/scenario, expected_behavior}' : ''}}.`

phase('Generate')
const PER = 25 // scenarios per agent
const results = await parallel(SURFACES.flatMap((surf) => {
  const nAgents = Math.ceil(surf.n / PER)
  return Array.from({ length: nAgents }, (_, k) => () => {
    const cell = DOMAINS[k % DOMAINS.length]
    return agent(genPrompt(surf, cell, PER, k), { label: `gen:${surf.key}#${k}`, phase: 'Generate', schema: SCHEMA })
      .then((r) => ({ key: surf.key, scenarios: (r && r.scenarios) || [] }))
      .catch(() => ({ key: surf.key, scenarios: [] }))
  })
}))

// group by surface, dedup by user-text, write files via a python helper invoked through the FS is not available here;
// instead return the grouped payload — a follow-up python step writes the files.
const bySurface = {}
for (const r of results.filter(Boolean)) {
  if (!bySurface[r.key]) bySurface[r.key] = []
  for (const s of r.scenarios) bySurface[r.key].push(s)
}
const summary = {}
for (const [k, arr] of Object.entries(bySurface)) {
  // dedup by normalized user text
  const seen = new Set(); const uniq = []
  for (const s of arr) { const key = (s.user || '').replace(/\s+/g, '').slice(0, 40); if (key && !seen.has(key)) { seen.add(key); uniq.push(s) } }
  summary[k] = uniq.length
  bySurface[k] = uniq
}
log('Generated distinct scenarios per surface: ' + JSON.stringify(summary))
return { bySurface, summary }
