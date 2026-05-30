export const meta = {
  name: 'judge-e2e',
  description: 'Judge the multi-turn END-TO-END build episodes: did deepseek drive the full agentic loop (recon→forge→accept→wire→check→activate) correctly per each episode rubric? 3 judges/episode.',
  phases: [{ title: 'Judge', detail: '3 adversarial judges per episode trajectory' }],
}
const RESULTS = '/tmp/r3e2e/results.json'
const SCHEMA = { type: 'object', required: ['id', 'success', 'checks_total', 'checks_passed', 'failed'], additionalProperties: false,
  properties: { id: { type: 'string' }, success: { type: 'boolean' }, checks_total: { type: 'integer' }, checks_passed: { type: 'integer' }, failed: { type: 'array', items: { type: 'string' } }, note: { type: 'string' } } }

// read the episode ids first via a tiny agent (workflow can't readdir/json) — then judge each.
phase('Judge')
const idsAgent = await agent(`Read ${RESULTS} (a JSON array of episodes each {id, user, intent, rubric, trajectory}). Return ONLY a JSON array of the episode "id" strings, nothing else.`,
  { label: 'list-ids', phase: 'Judge', schema: { type: 'object', required: ['ids'], additionalProperties: false, properties: { ids: { type: 'array', items: { type: 'string' } } } } })
const IDS = (idsAgent && idsAgent.ids) || []
log(`e2e episodes to judge: ${IDS.length}`)

const judgePrompt = (id) => `Adversarial judge for ONE end-to-end build episode. Read ${RESULTS}, find the object with id="${id}": {user, intent (the correct end-state), rubric[], trajectory[] (the model's full sequence of tool calls + final message)}.
Judge whether the model genuinely drove the FULL agentic loop correctly per the rubric & intent:
- searched first (recon → nothing exists), forged the RIGHT kind of piece (agent for classify/judge/extract; function for deterministic; handler for stateful), accepted pending before wiring, built a create_workflow with per-branch when-guards (no key-match, final default) + no dangling + first node after cron/poll fetches data, NO hallucinated ids (only ids the backend returned), capability_check_workflow BEFORE activate, then activate.
- success=true ONLY if the trajectory genuinely accomplishes the episode end-to-end per EVERY rubric check. Minor stylistic deviations ok; structural/loop errors (skipped accept, hallucinated id, dangling, wrong entity type, no capability_check, no activate) → success=false with the failed[] checks.
Default skeptical. Return per schema {id, success (ALL checks pass), checks_total (# rubric checks), checks_passed (# that genuinely pass), failed[], note}.`

const results = await parallel(IDS.map((id) => () =>
  parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id), { label: `j${j}:${id}`, phase: 'Judge', schema: SCHEMA }).catch(() => null)))
    .then((js) => ({ id, judges: js.filter(Boolean) }))))

function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
let pass = 0, n = 0, chkP = 0, chkT = 0; const fails = {}
for (const r of results.filter(Boolean)) {
  let yes = 0, tot = 0
  for (const j of r.judges) {
    tot++; if (j.success) yes++; else for (const f of (j.failed || [])) fails[f] = (fails[f] || 0) + 1
    if (j.checks_total) { chkP += (j.checks_passed || 0); chkT += j.checks_total }
  }
  if (!tot) continue
  n++; if (yes >= Math.ceil(tot / 2)) pass++
}
const rate = n ? pass / n : 0
const perCheck = chkT ? chkP / chkT : 0
log(`E2E ALL-checks-pass(苛刻全AND): ${pass}/${n} = ${(rate * 100).toFixed(0)}%`)
log(`E2E PER-check pass(公平,各步): ${chkP}/${chkT} = ${(perCheck * 100).toFixed(0)}% ±${Math.round(ci(perCheck, chkT) * 100)}`)
const top = Object.entries(fails).sort((a, b) => b[1] - a[1]).slice(0, 6)
log(`top failure modes: ${top.map(([f, c]) => f.slice(0, 40) + '×' + c).join(' | ')}`)
return { allPass: pass, n, allRate: +rate.toFixed(2), perCheck: +perCheck.toFixed(2), perCheckCI: ci(perCheck, chkT), topFails: top }
