export const meta = {
  name: 'gen-complex-scenarios',
  description: 'Author a large batch of HARD/COMPLEX scenarios (unlimited per user) for the crown forge surfaces — the intricate end most likely to break. Agents write /tmp/r3complex/<surface>.json.',
  phases: [{ title: 'GenComplex', detail: 'intricate multi-step / edge-case scenarios per crown surface' }],
}
const DIR = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'
const SURFACES = [
  { key: 'create_workflow', tool: 'create_workflow', n: 60,
    hard: 'LARGE intricate graphs: 10-20 nodes, MULTIPLE case nodes, bounded retry loops with emit, approval with timeout, multi-agent stages, parallel branches that rejoin, ETL-style validate→transform→load with deadletter, fan-out/fan-in. Each must have a clear correct graph.' },
  { key: 'cel_when', tool: 'create_workflow', n: 60,
    hard: 'HARD case-node routing as per-branch when-guards: nested optional fields, time-windows (dow/hour), multi-field AND/OR with list-membership, N-way (5+) ordered thresholds, retry-count canonical (has(x)?x:0)<N, null-safety on deep paths. Express as a small create_workflow with a case node.' },
  { key: 'create_handler', tool: 'create_handler', n: 60,
    hard: 'COMPLEX stateful handlers: sliding-window rate limiter, token-bucket with refill, LRU cache with TTL, connection pool with max+wait, circuit breaker with half-open, leaky bucket, dedup window with eviction, exponential-backoff scheduler. Include a code_test {scenario, expected_behavior} that exercises the tricky state transition.' },
  { key: 'create_function', tool: 'create_function', n: 60,
    hard: 'COMPLEX pure-logic functions: recursive tree/JSON walk, multi-source merge+dedup, date/timezone math, CSV/edge-case parsing, pagination cursor logic, retry/backoff calc, schema validation, string templating, interval merging. Include code_test {inputs, expected_behavior} with edge cases.' },
  { key: 'create_agent', tool: 'create_agent', n: 60,
    hard: 'COMPLEX agents: multi-tool (several fn/hd/mcp), knowledge+skill mounted, intricate json_schema outputSchema (nested/arrays/enums), routing/extraction with strict output, agents that must reference {{payload}} fields. Each must avoid the impossible-capability trap.' },
]
const RESULT = { type: 'object', required: ['surface', 'count'], additionalProperties: false,
  properties: { surface: { type: 'string' }, count: { type: 'integer' }, note: { type: 'string' } } }

const prompt = (s) => `Author ${s.n} HARD/COMPLEX, ALL-DISTINCT test scenarios for forge surface \`${s.key}\` (built via tool ${s.tool}).
Focus on the INTRICATE end most likely to break: ${s.hard}
Get the tool schema if useful: \`cd ${DIR} && python3 -c "import spec_catalog as sc,json;print(json.dumps(sc.BY_NAME['${s.tool}']))"\`.
Each scenario = {"id":"${s.key}_cx_<n>", "user":"<one-paragraph Chinese request, genuinely complex/realistic>", "intent":"<English: the exactly-correct artifact>", "rubric":["4-7 STRICT checks for this hard case"]${s.key === 'create_handler' || s.key === 'create_function' ? ', "code_test":{...}' : ''}}.
Maximize diversity across domains (电商/客服/运维/金融/内容/IoT/HR/物流/医疗/教育/SaaS/数据…). Write a top-level JSON array to /tmp/r3complex/${s.key}.json (mkdir -p /tmp/r3complex) via Write; verify it parses. Return {surface, count}.`

phase('GenComplex')
const results = await parallel(SURFACES.map((s) => () =>
  agent(prompt(s), { label: `cx:${s.key}`, phase: 'GenComplex', schema: RESULT, agentType: 'general-purpose' })
    .then((r) => r || { surface: s.key, count: 0 }).catch((e) => ({ surface: s.key, count: 0, note: String(e).slice(0, 80) }))))
const ok = results.filter(Boolean)
log('Complex scenarios written: ' + ok.map((r) => `${r.surface}:${r.count}`).join(', '))
return { perSurface: ok.map((r) => [r.surface, r.count]), total: ok.reduce((s, r) => s + (r.count || 0), 0) }
